package runner

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/ansi"
	"github.com/charmbracelet/x/term"
)

// Every line is laid out to lineWidth so the right-hand column lands in the
// same place regardless of indent, marker or label length.
const (
	lineWidth        = 66
	stepCounterWidth = 5
	durationWidth    = 8
	statusWidth      = 5
)

// How many lines of a running command's output to show, and the width assumed
// when the terminal will not report one.
const (
	defaultLogLines = 5
	fallbackWidth   = 100
	fallbackHeight  = 24
)

// Outcome is how a step or spec finished.
type Outcome int

const (
	OutcomeOK Outcome = iota
	OutcomeFail
	OutcomeOther
)

// Only three variations are used — normal, dim, and a coloured bold — so the
// things that matter still stand out.
var (
	styleDim   = lipgloss.NewStyle().Faint(true)
	styleBold  = lipgloss.NewStyle().Bold(true)
	styleOK    = lipgloss.NewStyle().Foreground(lipgloss.Green)
	styleFail  = lipgloss.NewStyle().Foreground(lipgloss.Red)
	styleOther = styleDim
)

// UI renders the runner's output, adapting to the terminal it writes to.
type UI struct {
	Out    io.Writer
	ErrOut io.Writer

	Verbose bool
	Quiet   bool

	// LogLines is how many lines of a running command's output to show beneath
	// its phase line. Zero disables the pane.
	LogLines int

	stepNum   int
	stepTotal int

	tty     bool // stdout is an interactive terminal
	unicode bool

	// Set only when NewUI built the writers; a UI assembled directly in a test
	// writes wherever it was pointed, unfiltered.
	out    *colorprofile.Writer
	errOut *colorprofile.Writer
}

func NewUI() *UI {
	return newUI(os.Stdout, os.Stderr, colorprofile.Detect(os.Stdout, os.Environ()))
}

// newUI wraps both writers in the detected profile. Styles always render
// full-fidelity ANSI, so downsampling has to happen here, at the output layer:
// anything the terminal cannot show is stripped on the way out.
func newUI(out, errOut io.Writer, profile colorprofile.Profile) *UI {
	stdout := &colorprofile.Writer{Forward: out, Profile: profile}
	stderr := &colorprofile.Writer{Forward: errOut, Profile: profile}

	u := &UI{Out: stdout, ErrOut: stderr, LogLines: defaultLogLines, out: stdout, errOut: stderr}
	// Neither of these two profiles can render an escape sequence.
	u.tty = profile != colorprofile.NoTTY && profile != colorprofile.Ascii
	u.unicode = u.tty
	return u
}

// NoColor drops colour but keeps the glyphs and the live phase line. Ascii
// still forwards bold and cursor movement, which the live region needs.
func (u *UI) NoColor() {
	u.setProfile(colorprofile.Ascii)
}

// Plain strips colour, glyphs and animation, matching what a pipe or a CI log
// would get. NoTTY removes every escape sequence, not just the colours.
func (u *UI) Plain() {
	u.setProfile(colorprofile.NoTTY)
	u.tty = false
	u.unicode = false
}

func (u *UI) setProfile(p colorprofile.Profile) {
	if u.out != nil {
		u.out.Profile = p
	}
	if u.errOut != nil {
		u.errOut.Profile = p
	}
}

// Info prints a result: always shown, even when quiet.
func (u *UI) Info(format string, args ...any) {
	fmt.Fprintf(u.Out, format+"\n", args...)
}

// Log prints progress chatter, which --quiet suppresses.
func (u *UI) Log(format string, args ...any) {
	if u.Quiet {
		return
	}
	fmt.Fprintf(u.Out, format+"\n", args...)
}

// Detail prints information only useful when debugging the run itself.
func (u *UI) Detail(format string, args ...any) {
	if !u.Verbose || u.Quiet {
		return
	}
	// Styled line by line: a style applied to a multi-line block pads every
	// line out to the width of the longest one.
	for _, line := range strings.Split(fmt.Sprintf(format, args...), "\n") {
		fmt.Fprintln(u.Out, styleDim.Render("  "+line))
	}
}

func (u *UI) Warn(format string, args ...any) {
	fmt.Fprintf(u.ErrOut, "WARN: "+format+"\n", args...)
}

func (u *UI) Err(format string, args ...any) {
	fmt.Fprintf(u.ErrOut, format+"\n", args...)
}

// Heading names the combo about to run, and its position when a run covers
// more than one.
func (u *UI) Heading(title string, index, total int) {
	u.Log("")
	if total > 1 {
		u.Log("%s %s", styleBold.Render("e2e  "+title),
			styleDim.Render(fmt.Sprintf("(combo %d/%d)", index, total)))
	} else {
		u.Log("%s", styleBold.Render("e2e  "+title))
	}
	u.Log("")
}

// BeginSteps declares how many steps this combo will run, so each one can say
// where it sits in the sequence.
func (u *UI) BeginSteps(total int) {
	u.stepNum = 0
	u.stepTotal = total
}

// SkipStep advances past a step that will not run, so the steps that follow
// keep their place in the declared sequence.
func (u *UI) SkipStep() {
	u.stepNum++
}

// stepCounter renders the [n/N] prefix for the step currently running.
func (u *UI) stepCounter() string {
	if u.stepTotal == 0 {
		return padRight("", stepCounterWidth)
	}
	return padRight(styleDim.Render(fmt.Sprintf("[%d/%d]", u.stepNum, u.stepTotal)), stepCounterWidth)
}

// Step reports one phase of a combo: a live line while fn runs, then its
// outcome and elapsed time. fn receives a writer whose most recent lines are
// shown beneath the phase while it runs.
func (u *UI) Step(label string, fn func(io.Writer) error) error {
	start := time.Now()
	u.stepNum++
	if u.Quiet {
		return fn(io.Discard)
	}

	var pane *logPane
	sink := io.Writer(io.Discard)
	if u.tty && u.LogLines > 0 {
		pane = newLogPane(u.LogLines)
		sink = pane
	}

	stop := u.startPending(label, start, pane)
	err := fn(sink)
	stop()

	outcome := OutcomeOK
	if err != nil {
		outcome = OutcomeFail
	}
	u.row("  ", outcome, u.stepCounter()+"  "+label, FormatDuration(time.Since(start)))

	return err
}

// Total closes a multi-combo run, keeping the grand total in the duration
// column so it reads against the individual results above it.
func (u *UI) Total(text string, d time.Duration) {
	u.Info("%s", rowString(padRight("", statusWidth), styleBold.Render(text), FormatDuration(d)))
}

// SpecGroup names the container hierarchy shared by the specs that follow.
func (u *UI) SpecGroup(name string) {
	if name == "" {
		return
	}
	u.Log("")
	u.Log("       %s", styleDim.Render(name))
}

// SpecLine reports a single spec beneath its group. A spec that neither passed
// nor failed shows its state where its duration would go: the number is
// meaningless for a spec that never ran, and appending it to the name pushed
// the column out of alignment.
func (u *UI) SpecLine(text string, outcome Outcome, note string, d time.Duration) {
	right := FormatDuration(d)
	if note != "" {
		right = note
	}
	u.row("       ", outcome, text, right)
}

// row renders one marker/label/value line, sized so the value always lands in
// the same column.
func (u *UI) row(indent string, outcome Outcome, label, value string) {
	u.Log("%s", rowString(indent+u.marker(outcome), label, value))
}

// rowString lays out a prefix, a label and a right-aligned value across
// lineWidth, truncating the label rather than letting it push the value out.
func rowString(prefix, label, value string) string {
	avail := lineWidth - lipgloss.Width(prefix) - 2 - 1 - durationWidth
	if avail < 1 {
		avail = 1
	}
	return fmt.Sprintf("%s  %s %s",
		prefix,
		padRight(ansi.Truncate(label, avail, "…"), avail),
		styleDim.Render(padLeft(value, durationWidth)))
}

// Verdict is the final line for a combo: the one thing to read if nothing else.
// The duration lands in the same column as every step and spec above it.
func (u *UI) Verdict(status Status, text string, d time.Duration) {
	style := styleOK
	if status == StatusFail {
		style = styleFail
	}
	u.Info("%s", rowString(
		padRight(style.Bold(true).Render(string(status)), statusWidth),
		text,
		FormatDuration(d)))
}

// marker renders an outcome in a fixed-width field so labels stay aligned. The
// field is one column wide for glyphs and four for the word fallback.
func (u *UI) marker(o Outcome) string {
	glyph, style := "-", styleOther
	switch o {
	case OutcomeOK:
		glyph, style = "ok", styleOK
		if u.unicode {
			glyph = "✓"
		}
	case OutcomeFail:
		glyph, style = "FAIL", styleFail
		if u.unicode {
			glyph = "✗"
		}
	case OutcomeOther:
		if u.unicode {
			glyph = "·"
		}
	}
	width := 4
	if u.unicode {
		width = 1
	}
	return padRight(style.Render(glyph), width)
}

func (u *UI) pendingLine(label string, elapsed time.Duration) string {
	return rowString("  "+u.marker(OutcomeOther), u.stepCounter()+"  "+label, FormatDuration(elapsed))
}

// startPending keeps the phase visible while it runs: on a terminal, the phase
// line plus a pane of the command's most recent output, redrawn in place and
// erased when the phase resolves. Elsewhere, a periodic note so CI logs do not
// go silent.
func (u *UI) startPending(label string, start time.Time, pane *logPane) func() {
	done := make(chan struct{})
	var wg sync.WaitGroup

	if !u.tty {
		wg.Add(1)
		go func() {
			defer wg.Done()
			ticker := time.NewTicker(2 * time.Minute)
			defer ticker.Stop()
			for {
				select {
				case <-done:
					return
				case <-ticker.C:
					u.Log("       %s still running (%s)", label, FormatDuration(time.Since(start)))
				}
			}
		}()
		return func() { close(done); wg.Wait() }
	}

	drawn := u.startLive(label, start, pane)

	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				drawn.close()
				return
			case <-ticker.C:
				drawn.redraw()
			}
		}
	}()

	return func() {
		close(done)
		wg.Wait()
	}
}

// live is the block of rows a running step owns.
//
// Its height is fixed when the step starts. A region that grows as output
// arrives can push itself past the bottom of the window, and the scroll moves
// the content out from under the cursor arithmetic that redraws it — leaving
// the phase line stranded above its own replacement.
type live struct {
	ui     *UI
	height int
	label  string
	start  time.Time
	pane   *logPane
}

// startLive reserves the region's rows up front, so any scrolling happens once,
// before the first redraw, and leaves the cursor at the region's first row.
func (u *UI) startLive(label string, start time.Time, pane *logPane) *live {
	l := &live{ui: u, label: label, start: start, pane: pane, height: 1}

	_, rows := u.size()
	if pane != nil && rows >= u.LogLines+3 {
		l.height = 1 + u.LogLines
	} else {
		// No room for the pane; the phase line alone still fits.
		l.pane = nil
	}

	fmt.Fprint(u.Out, strings.Repeat("\n", l.height)+ansi.CursorUp(l.height))
	l.render()
	return l
}

func (l *live) redraw() { l.render() }

// render rewrites every row of the region and returns the cursor to its top.
func (l *live) render() {
	lines := l.lines()

	var b strings.Builder
	for _, line := range lines {
		b.WriteString("\r" + ansi.EraseEntireLine + line + "\n")
	}
	b.WriteString(ansi.CursorUp(l.height))

	fmt.Fprint(l.ui.Out, b.String())
}

// close wipes the region so the resolved phase line takes its place. Clearing
// to the end of the screen rather than counting rows means a miscount cannot
// leave residue behind.
func (l *live) close() {
	fmt.Fprint(l.ui.Out, "\r"+ansi.EraseScreenBelow)
}

// lines renders the region's content, padded out to its fixed height.
func (l *live) lines() []string {
	// Never write the final column: a full-width line wraps, and the newline
	// after it then costs a second row.
	width := l.ui.width() - 1

	out := make([]string, 0, l.height)
	out = append(out, ansi.Truncate(l.ui.pendingLine(l.label, time.Since(l.start)), width, ""))

	if l.pane != nil {
		gutter := styleDim.Render("│")
		for _, line := range l.pane.snapshot() {
			// Truncated before styling so the closing escape is never cut off.
			out = append(out, "     "+gutter+" "+styleDim.Render(ansi.Truncate(line, width-7, "…")))
		}
	}

	for len(out) < l.height {
		out = append(out, "")
	}
	return out[:l.height]
}

// size reports the terminal's width and height, falling back to sane defaults
// when stdout cannot report them.
func (u *UI) size() (width, height int) {
	width, height = fallbackWidth, fallbackHeight

	if f, ok := u.Out.(*os.File); ok {
		if w, h, err := term.GetSize(f.Fd()); err == nil {
			if w > 0 {
				width = w
			}
			if h > 0 {
				height = h
			}
		}
	}

	if c := os.Getenv("COLUMNS"); c != "" {
		if n, err := strconv.Atoi(c); err == nil && n > 0 {
			width = n
		}
	}
	return width, height
}

func (u *UI) width() int {
	w, _ := u.size()
	return w
}

// Join combines fragments with the separator the terminal can render.
func (u *UI) Join(parts ...string) string {
	sep := " | "
	if u.unicode {
		sep = " · "
	}
	return strings.Join(parts, sep)
}

// padRight and padLeft align to a column width, measuring display cells rather
// than bytes or runes so escape sequences and wide glyphs do not skew it.
// Unlike Style.Width, over-long strings are left alone instead of wrapped.
func padRight(s string, width int) string {
	return lipgloss.PlaceHorizontal(width, lipgloss.Left, s)
}

func padLeft(s string, width int) string {
	return lipgloss.PlaceHorizontal(width, lipgloss.Right, s)
}

// FormatDuration renders a duration as 45s / 7m40s. Anything under a second
// reads as "<1s" rather than "0s", which looks like a missing measurement.
func FormatDuration(d time.Duration) string {
	switch {
	case d <= 0:
		return "0s"
	case d < time.Second:
		return "<1s"
	case d < time.Minute:
		return fmt.Sprintf("%ds", int(d.Seconds()))
	default:
		secs := int(d.Seconds())
		return fmt.Sprintf("%dm%02ds", secs/60, secs%60)
	}
}

// run executes a command, sending its combined output to w.
func run(dir string, w io.Writer, name string, args ...string) error {
	return runWithEnv(dir, w, nil, name, args...)
}

// runWithEnv executes a command with extra environment entries appended.
func runWithEnv(dir string, w io.Writer, env []string, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdout = w
	cmd.Stderr = w
	if len(env) > 0 {
		cmd.Env = append(os.Environ(), env...)
	}
	return cmd.Run()
}

// capture executes a command and returns its stdout, with stderr folded into
// the error.
func capture(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		var stderr string
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			stderr = string(exitErr.Stderr)
		}
		return "", fmt.Errorf("%s %v: %w: %s", name, args, err, stderr)
	}
	return string(out), nil
}
