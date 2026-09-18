package runner

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/peterbourgon/ff/v4"
)

// customCombo names a run driven by a supplied config rather than the matrix.
const customCombo = "custom"

// envPrefix makes every flag settable from the environment: --mirror-host is
// also E2E_MIRROR_HOST, --log-lines is also E2E_LOG_LINES, and so on.
const envPrefix = "E2E"

// Commands. cmdNone is the bare invocation, which shows the root help. A bare
// combo name is shorthand for cmdRun, and validateCommandNames keeps the matrix
// from ever shadowing one of these.
const (
	cmdNone    = ""
	cmdRun     = "run"
	cmdList    = "list"
	cmdConfig  = "config"
	cmdClean   = "clean"
	cmdVersion = "version"
	cmdHelp    = "help"
)

// ErrNoCombos means nothing was selected to run, which calls for a usage hint
// rather than the full help.
var ErrNoCombos = errors.New("no combos selected")

// ErrHelpRequested means the user asked for help, and it has been printed.
var ErrHelpRequested = errors.New("help requested")

// command is one entry in the CLI's command table.
type command struct {
	name    string
	summary string // one line, as shown in the root command list
	help    string // full help text, %[1]s is the program name

	// flags are what this command accepts on top of the global ones.
	flags func(o *Options, fs *ff.FlagSet)

	// combos reports whether positional arguments name combos.
	combos bool

	exec func(r *Runner) int
}

// commands is the command table, in the order the root help lists them. It is
// filled in at init because `help` has to reach back into the table.
var commands []*command

func init() {
	commands = []*command{
		{
			name:    cmdRun,
			summary: "run the matrix for one or more combos",
			help:    runHelp,
			flags:   runFlags,
			combos:  true,
			exec:    (*Runner).execRun,
		},
		{
			name:    cmdList,
			summary: "show the combos and what each exercises",
			help:    listHelp,
			flags:   listFlags,
			exec:    (*Runner).execList,
		},
		{
			name:    cmdConfig,
			summary: "print the config.yaml a combo would use",
			help:    configHelp,
			flags:   configFlags,
			combos:  true,
			exec:    (*Runner).execConfig,
		},
		{
			name:    cmdClean,
			summary: "delete a playground a run left behind",
			help:    cleanHelp,
			flags:   cleanFlags,
			combos:  true,
			exec:    (*Runner).execClean,
		},
		{
			name:    cmdVersion,
			summary: "print the runner version",
			help:    versionHelp,
			exec:    (*Runner).execVersion,
		},
		{
			name:    cmdHelp,
			summary: "help for any command",
			help:    helpHelp,
			exec:    (*Runner).execHelp,
		},
	}
}

func lookupCommand(name string) *command {
	for _, c := range commands {
		if c.name == name {
			return c
		}
	}
	return nil
}

func commandNames() []string {
	names := make([]string, 0, len(commands))
	for _, c := range commands {
		names = append(names, c.name)
	}
	return names
}

func isCommand(arg string) bool {
	return lookupCommand(arg) != nil
}

// Options is the parsed command line.
type Options struct {
	Prog    string
	Command string

	// HelpTopic is the command named as an argument to `help`.
	HelpTopic string

	Combos []string
	All    bool

	Labels       string
	ArtifactsDir string
	Spares       int
	MirrorHost   string
	ConfigFile   string
	ChartVersion string

	// TinkerbellRepo and TinkerbellRef build Tinkerbell from source rather than
	// using released artifacts. Either alone is enough: the repo defaults to
	// upstream, the ref to the repo's default branch.
	TinkerbellRepo string
	TinkerbellRef  string

	DryRun     bool
	NoTeardown bool

	Verbose  bool
	Quiet    bool
	NoColor  bool
	Plain    bool
	JSON     bool
	LogLines int

	showVersion bool
}

// globalFlags are accepted by every command, and ahead of the command name.
func globalFlags(o *Options, fs *ff.FlagSet) {
	fs.BoolVar(&o.Verbose, 'v', "verbose", "label filters, full paths, longer log excerpts")
	fs.BoolVar(&o.Quiet, 'q', "quiet", "only the final verdict")
	fs.BoolVar(&o.Plain, 0, "plain", "no colour, glyphs or progress")
	fs.BoolVar(&o.NoColor, 0, "no-color", "no colour, keep glyphs and progress")
}

// rootFlags are the global flags plus what a bare invocation accepts.
func rootFlags(o *Options, fs *ff.FlagSet) {
	globalFlags(o, fs)
	fs.BoolVar(&o.showVersion, 0, "version", "print the runner version")
}

// configFlags shape the config.yaml a combo renders to, so `config` and `run`
// share them: a preview is only useful if it matches what the run would use.
func configFlags(o *Options, fs *ff.FlagSet) {
	fs.StringVar(&o.MirrorHost, 0, "mirror-host", "", "registry mirror hostname")
	fs.StringVar(&o.ConfigFile, 0, "config", "", "use this file instead of rendering the combo's config")
	fs.StringVar(&o.ChartVersion, 0, "chart-version", "", "Tinkerbell Helm chart version (default: what latest resolves to)")
	fs.StringVar(&o.TinkerbellRepo, 0, "tinkerbell-repo", "", "build Tinkerbell from this git repo or local checkout")
	fs.StringVar(&o.TinkerbellRef, 0, "tinkerbell-ref", "", "build Tinkerbell from this branch, tag or commit")
	fs.IntVar(&o.Spares, 0, "spares", 0, "spare VMs to create")
	fs.StringVar(&o.ArtifactsDir, 0, "artifacts", "", "where to write logs and reports")
}

func runFlags(o *Options, fs *ff.FlagSet) {
	configFlags(o, fs)
	fs.BoolVar(&o.All, 'a', "all", "run every combo")
	fs.BoolVar(&o.DryRun, 'n', "dry-run", "print what would run, touch nothing")
	fs.BoolVar(&o.NoTeardown, 0, "no-teardown", "leave the playground running when tests finish")
	fs.StringVar(&o.Labels, 0, "labels", "", "Ginkgo label filter")
	fs.IntVar(&o.LogLines, 0, "log-lines", defaultLogLines, "live output lines under the running step")
}

func listFlags(o *Options, fs *ff.FlagSet) {
	fs.BoolVar(&o.JSON, 0, "json", "machine-readable output")
}

func cleanFlags(o *Options, fs *ff.FlagSet) {
	fs.BoolVar(&o.All, 'a', "all", "clean every combo with artifacts")
	fs.BoolVar(&o.DryRun, 'n', "dry-run", "print what would be deleted, touch nothing")
	fs.StringVar(&o.ArtifactsDir, 0, "artifacts", "", "where the combo artifacts live")
}

// flagSet builds the flag set for one command: the global flags plus its own.
// A nil command is the bare invocation.
func (r *Runner) flagSet(cmd *command) *ff.FlagSet {
	if cmd == nil {
		fs := ff.NewFlagSet("e2e")
		rootFlags(&r.Opts, fs)
		return fs
	}

	fs := ff.NewFlagSet("e2e " + cmd.name)
	globalFlags(&r.Opts, fs)
	if cmd.flags != nil {
		cmd.flags(&r.Opts, fs)
	}
	return fs
}

// ParseArgs selects the command, parses its flags, then applies the settings
// that change how output is rendered. A parse failure is returned with that
// command's help already written, since a flag error is exactly when its own
// options list is wanted — and only its own.
func (r *Runner) ParseArgs(args []string) error {
	name, rest := splitCommand(args)
	r.Opts.Command = name

	// Only `run` registers --log-lines, so the default has to be set here too,
	// for the commands whose flag set never carries it.
	r.Opts.LogLines = defaultLogLines

	cmd := lookupCommand(name)
	fs := r.flagSet(cmd)

	positional, err := parsePermuted(fs, rest)
	if err != nil {
		if errors.Is(err, ff.ErrHelp) {
			r.PrintHelp(r.UI.Out, cmd)
			return ErrHelpRequested
		}
		r.PrintHelp(r.UI.ErrOut, cmd)
		return fmt.Errorf("%w%s", err, flagSuggestion(err, fs))
	}

	r.applyOutputOptions()

	if r.Opts.showVersion {
		r.Opts.Command = cmdVersion
		return nil
	}

	switch {
	case name == cmdHelp:
		if len(positional) > 0 {
			r.Opts.HelpTopic = positional[0]
		}
	case cmd != nil && cmd.combos:
		r.Opts.Combos = positional
	case len(positional) > 0:
		r.PrintHelp(r.UI.ErrOut, cmd)
		return fmt.Errorf("%s takes no arguments, got %q", name, positional[0])
	}

	return nil
}

// splitCommand pulls the command name out of args, leaving any global flags
// that preceded it in place. A command name is the first positional token;
// anything else is the bare-combo shorthand for `run`.
func splitCommand(args []string) (string, []string) {
	// The probe knows only the global flags, so it stops at the first token
	// that is either a positional or a command-scoped flag.
	probe := ff.NewFlagSet("e2e")
	rootFlags(&Options{}, probe)

	if err := ff.Parse(probe, args, ff.WithEnvVarPrefix(envPrefix)); err != nil {
		if errors.Is(err, ff.ErrHelp) {
			return cmdNone, args
		}
		// A command-scoped flag with no command ahead of it: only `run` takes
		// flags that way, through the shorthand.
		return cmdRun, args
	}

	rest := probe.GetArgs()
	switch {
	case len(rest) == 0:
		return cmdNone, args
	case isCommand(rest[0]):
		leading := args[:len(args)-len(rest)]
		return rest[0], append(append([]string{}, leading...), rest[1:]...)
	default:
		return cmdRun, args
	}
}

// parsePermuted parses flags that appear before, after, or between positional
// arguments. ff stops at the first non-flag argument, so the leading
// positionals are set aside and parsing resumes on what follows.
func parsePermuted(fs *ff.FlagSet, args []string) ([]string, error) {
	var positional []string
	remaining := args

	for {
		if err := fs.Reset(); err != nil {
			return nil, err
		}
		if err := ff.Parse(fs, remaining, ff.WithEnvVarPrefix(envPrefix)); err != nil {
			return nil, err
		}

		leftover := fs.GetArgs()
		consumed := remaining[:len(remaining)-len(leftover)]

		split := 0
		for split < len(leftover) && !strings.HasPrefix(leftover[split], "-") {
			split++
		}
		positional = append(positional, leftover[:split]...)

		if split == len(leftover) {
			return positional, nil
		}
		// Re-parse the flags already seen plus everything from the next flag on.
		remaining = append(append([]string{}, consumed...), leftover[split:]...)
	}
}

func (r *Runner) applyOutputOptions() {
	r.UI.Verbose = r.Opts.Verbose
	r.UI.Quiet = r.Opts.Quiet
	r.UI.LogLines = r.Opts.LogLines
	if r.Opts.NoColor {
		r.UI.NoColor()
	}
	if r.Opts.Plain {
		r.UI.Plain()
	}
}

// resolveArtifactsDir settles where combo artifacts live, which every command
// that touches them needs before it can do anything else.
func (r *Runner) resolveArtifactsDir() error {
	if r.Opts.ArtifactsDir == "" {
		r.Opts.ArtifactsDir = r.Paths.Artifacts
	}
	abs, err := filepath.Abs(r.Opts.ArtifactsDir)
	if err != nil {
		return err
	}
	r.Opts.ArtifactsDir = abs
	return nil
}

// SourceRequested reports whether Tinkerbell is to be built rather than pulled.
// Either flag alone is enough: the playground defaults whichever is missing.
func (r *Runner) SourceRequested() bool {
	return r.Opts.TinkerbellRepo != "" || r.Opts.TinkerbellRef != ""
}

// sourceDescription names the build in one line. What each flag defaults to is
// the playground's decision, so an omitted one is reported as such rather than
// guessed at here.
func (r *Runner) sourceDescription() string {
	repo := r.Opts.TinkerbellRepo
	if repo == "" {
		repo = "(default repo)"
	}
	ref := r.Opts.TinkerbellRef
	if ref == "" {
		ref = "(default branch)"
	}
	return repo + " @ " + ref
}

// tinkerbellDescription names the Tinkerbell a combo will install, so the run
// says what was under test without anyone opening its config.yaml.
func (r *Runner) tinkerbellDescription() (string, error) {
	if r.SourceRequested() {
		return "built from " + r.sourceDescription(), nil
	}

	chart, err := r.chartVersion()
	if err != nil {
		return "", err
	}
	if r.Opts.ChartVersion != "" {
		return "chart " + chart + " (--chart-version)", nil
	}
	return "chart " + chart + " (latest)", nil
}

// Validate checks the parsed options, resolving the defaults they depend on.
func (r *Runner) Validate() error {
	if err := r.resolveArtifactsDir(); err != nil {
		return err
	}

	// The build supplies the chart, so a version to pull is not just redundant,
	// it names an artifact that will not be used.
	if r.SourceRequested() && r.Opts.ChartVersion != "" {
		return fmt.Errorf("--chart-version cannot be combined with --tinkerbell-repo/--tinkerbell-ref\nBuilding from source produces the chart, so there is no released version to select.")
	}

	if r.Opts.ConfigFile != "" {
		if _, err := os.Stat(r.Opts.ConfigFile); err != nil {
			return fmt.Errorf("config file not found: %s", r.Opts.ConfigFile)
		}
		abs, err := filepath.Abs(r.Opts.ConfigFile)
		if err != nil {
			return err
		}
		r.Opts.ConfigFile = abs
		// With a supplied config the combo no longer renders config.yaml, but it
		// still selects the test set; without one there is nothing to select by.
		if len(r.Opts.Combos) == 0 && !r.Opts.All {
			r.Opts.Combos = []string{customCombo}
		}
	}

	if len(r.Opts.Combos) == 0 && !r.Opts.All {
		return ErrNoCombos
	}

	known, err := r.ComboNames()
	if err != nil {
		return err
	}
	if err := validateCommandNames(known); err != nil {
		return err
	}
	if r.Opts.All {
		r.Opts.Combos = append(r.Opts.Combos, known...)
	}

	mirrorOnly, err := r.MirrorComboNames()
	if err != nil {
		return err
	}

	var unknown, needsMirror []string
	for _, combo := range r.Opts.Combos {
		if r.Opts.ConfigFile != "" && combo == customCombo {
			continue
		}
		switch {
		case !slices.Contains(known, combo):
			unknown = append(unknown, combo)
		case r.Opts.ConfigFile == "" && r.Opts.MirrorHost == "" && slices.Contains(mirrorOnly, combo):
			needsMirror = append(needsMirror, combo)
		}
	}

	if len(unknown) > 0 {
		// Command names are candidates too: a mistyped command arrives here as
		// a combo, because anything that is not a command is one.
		candidates := append(append([]string{}, known...), commandNames()...)
		return fmt.Errorf("unknown combo: %s%s\nRun '%s list' to see the available combos.",
			strings.Join(unknown, " "), suggestion(unknown[0], candidates), r.Opts.Prog)
	}
	if len(needsMirror) > 0 {
		return fmt.Errorf("--mirror-host is required by: %s\nPass --mirror-host HOST or set %s_MIRROR_HOST.",
			strings.Join(needsMirror, " "), envPrefix)
	}

	return nil
}

// validateCommandNames guards the bare-combo shorthand: a combo named after a
// command would be unreachable.
func validateCommandNames(combos []string) error {
	for _, name := range combos {
		if isCommand(name) {
			return fmt.Errorf("combo %q collides with the command of the same name; rename it in e2e/cue/matrix.cue", name)
		}
	}
	return nil
}

// suggestion offers the closest known name when one is misspelled. A candidate
// that extends the input wins outright: --mirror for --mirror-host is a common
// slip that edit distance alone scores poorly.
func suggestion(input string, known []string) string {
	for _, name := range known {
		if name != input && strings.HasPrefix(name, input) {
			return fmt.Sprintf("\n\nDid you mean '%s'?", name)
		}
	}

	best, bestDist := "", 3
	for _, name := range known {
		if d := editDistance(input, name); d < bestDist {
			best, bestDist = name, d
		}
	}
	if best == "" {
		return ""
	}
	return fmt.Sprintf("\n\nDid you mean '%s'?", best)
}

func editDistance(a, b string) int {
	prev := make([]int, len(b)+1)
	curr := make([]int, len(b)+1)
	for j := range prev {
		prev[j] = j
	}
	for i := 1; i <= len(a); i++ {
		curr[0] = i
		for j := 1; j <= len(b); j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			curr[j] = min(prev[j]+1, min(curr[j-1]+1, prev[j-1]+cost))
		}
		prev, curr = curr, prev
	}
	return prev[len(b)]
}

// flagSuggestion offers the closest defined flag when an unknown one is given.
func flagSuggestion(err error, fs *ff.FlagSet) string {
	var unknown *ff.UnknownFlagError
	if !errors.As(err, &unknown) {
		return ""
	}

	// Suggest with the hyphens attached so the answer can be pasted as-is.
	var names []string
	_ = fs.WalkFlags(func(f ff.Flag) error {
		if long, ok := f.GetLongName(); ok {
			names = append(names, "--"+long)
		}
		return nil
	})

	// GetName is documented as trimming leading hyphens but only removes one.
	return suggestion("--"+strings.TrimLeft(unknown.GetName(), "-"), names)
}
