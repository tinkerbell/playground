package runner

import (
	"bytes"
	"io"

	"strings"
	"testing"
	"time"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/colorprofile"
)

func TestLogPaneKeepsLastLines(t *testing.T) {
	p := newLogPane(3)
	for _, s := range []string{"one\n", "two\n", "three\n", "four\n", "five\n"} {
		if _, err := p.Write([]byte(s)); err != nil {
			t.Fatal(err)
		}
	}
	got := strings.Join(p.snapshot(), ",")
	if got != "three,four,five" {
		t.Errorf("snapshot = %q", got)
	}
}

// Progress output that redraws with \r must replace the current line rather
// than filling the buffer.
func TestLogPaneTreatsCarriageReturnAsLineEnd(t *testing.T) {
	p := newLogPane(5)
	p.Write([]byte("10%\r20%\r30%\r"))
	if got := p.snapshot(); len(got) != 3 || got[2] != "30%" {
		t.Errorf("snapshot = %v", got)
	}
}

func TestLogPaneStripsANSIAndBlankLines(t *testing.T) {
	p := newLogPane(5)
	p.Write([]byte("\033[32mgreen\033[0m\n\n   \n"))
	got := p.snapshot()
	if len(got) != 1 || got[0] != "green" {
		t.Errorf("snapshot = %q", got)
	}
}

// A partial write must not surface until its line terminator arrives.
func TestLogPaneBuffersPartialLines(t *testing.T) {
	p := newLogPane(5)
	p.Write([]byte("half "))
	if len(p.snapshot()) != 0 {
		t.Fatal("partial line surfaced early")
	}
	p.Write([]byte("a line\n"))
	if got := p.snapshot(); len(got) != 1 || got[0] != "half a line" {
		t.Errorf("snapshot = %q", got)
	}
}

// The live region must be fully erased so the resolved phase line replaces it,
// leaving no stray pane lines in scrollback.
func TestStepErasesPaneOnCompletion(t *testing.T) {
	var buf bytes.Buffer
	u := &UI{Out: &buf, ErrOut: io.Discard, LogLines: 3, tty: true, unicode: true}

	err := u.Step("create playground", func(w io.Writer) error {
		w.Write([]byte("first\nsecond\n"))
		time.Sleep(1100 * time.Millisecond) // one tick, so the pane is drawn
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}

	out := buf.String()
	if !strings.Contains(out, "first") || !strings.Contains(out, "second") {
		t.Error("pane never rendered the command output")
	}

	// Everything after the final erase is the resolved line, which must not
	// carry any pane content forward.
	lastErase := strings.LastIndex(out, "\033[2K")
	if tail := out[lastErase:]; strings.Contains(tail, "first") || strings.Contains(tail, "second") {
		t.Errorf("pane content survived the erase: %q", tail)
	}
	if !strings.Contains(out, "create playground") {
		t.Error("resolved phase line missing")
	}
}

func TestStepWithoutTTYSkipsPane(t *testing.T) {
	var buf bytes.Buffer
	u := newUI(&buf, io.Discard, colorprofile.NoTTY)
	u.LogLines = 3

	u.Step("create playground", func(w io.Writer) error {
		w.Write([]byte("noise\n"))
		return nil
	})

	out := buf.String()
	if strings.Contains(out, "noise") {
		t.Error("command output leaked into non-TTY output")
	}
	if strings.Contains(out, "\033[") {
		t.Errorf("escape sequences written to a non-TTY: %q", out)
	}
}

// A line that reaches the final column wraps, and the newline after it costs a
// second row — which silently desynchronises the region's row accounting.
func TestLiveLinesStayInsideTheTerminal(t *testing.T) {
	t.Setenv("COLUMNS", "60")

	u := &UI{Out: io.Discard, ErrOut: io.Discard, LogLines: 2, tty: true, unicode: true}
	pane := newLogPane(2)
	pane.Write([]byte(strings.Repeat("x", 200) + "\n"))

	l := &live{ui: u, height: 3, label: "create playground", start: time.Now(), pane: pane}

	var sawEllipsis bool
	for _, line := range l.lines() {
		if w := lipgloss.Width(line); w >= 60 {
			t.Errorf("line of width %d reaches the 60-column edge: %q", w, line)
		}
		if strings.Contains(line, "…") {
			sawEllipsis = true
		}
	}
	if !sawEllipsis {
		t.Error("truncated line is missing its ellipsis")
	}
}

// The region's height is fixed when the step starts; if the rendered line count
// tracked the pane instead, a growing pane would scroll the terminal and strand
// the phase line above its own replacement.
func TestLiveRegionHeightIsFixed(t *testing.T) {
	u := &UI{Out: io.Discard, ErrOut: io.Discard, LogLines: 3, tty: true, unicode: true}
	pane := newLogPane(3)
	l := &live{ui: u, height: 4, label: "build playground", start: time.Now(), pane: pane}

	for _, writes := range []int{0, 1, 3, 10} {
		for i := 0; i < writes; i++ {
			pane.Write([]byte("task: doing a thing\n"))
		}
		if got := len(l.lines()); got != l.height {
			t.Errorf("after %d writes: %d lines, want %d", writes, got, l.height)
		}
	}
}

// Clearing to the end of the screen rather than counting rows means a miscount
// cannot leave a stale phase line behind.
func TestLiveRegionClearsToEndOfScreen(t *testing.T) {
	var buf bytes.Buffer
	u := &UI{Out: &buf, ErrOut: io.Discard, tty: true, unicode: true}
	l := &live{ui: u, height: 3, label: "build playground", start: time.Now()}

	l.close()

	if got := buf.String(); got != "\r\033[J" {
		t.Errorf("close wrote %q, want a clear-to-end-of-screen", got)
	}
}

// A terminal too short for the pane must still show the phase line.
func TestLiveRegionDropsPaneWhenTerminalIsShort(t *testing.T) {
	var buf bytes.Buffer
	// Out is not a *os.File, so the fallback 24-row height applies.
	u := &UI{Out: &buf, ErrOut: io.Discard, LogLines: 100, tty: true, unicode: true}

	l := u.startLive("build playground", time.Now(), newLogPane(100))

	if l.height != 1 {
		t.Errorf("height = %d, want 1 when the pane cannot fit", l.height)
	}
	if l.pane != nil {
		t.Error("pane should be dropped when it cannot fit")
	}
}
