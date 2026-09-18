package runner

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"

	"testing"
	"time"

	"charm.land/lipgloss/v2"

	"github.com/onsi/ginkgo/v2/types"
)

func TestFormatDuration(t *testing.T) {
	for _, tc := range []struct {
		in   time.Duration
		want string
	}{
		{0, "0s"},
		{900 * time.Millisecond, "<1s"},
		{45 * time.Second, "45s"},
		{60 * time.Second, "1m00s"},
		{460 * time.Second, "7m40s"},
		{3600 * time.Second, "60m00s"},
	} {
		if got := FormatDuration(tc.in); got != tc.want {
			t.Errorf("FormatDuration(%s) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// Style.Width wraps content wider than the field, which would break long spec
// names; the padding helpers must leave them alone.
func TestPaddingDoesNotWrap(t *testing.T) {
	long := strings.Repeat("x", 80)
	if got := padRight(long, 47); got != long {
		t.Errorf("padRight altered an over-long label: %q", got)
	}
	if got := padRight("ok", 6); got != "ok    " {
		t.Errorf("padRight(ok, 6) = %q", got)
	}
	if got := padLeft("7m40s", 8); got != "   7m40s" {
		t.Errorf("padLeft(7m40s, 8) = %q", got)
	}
}

// Every rendered row must be exactly lineWidth wide, whatever the prefix or
// label, or the duration column goes ragged.
func TestRowsShareOneDurationColumn(t *testing.T) {
	prefixes := []string{"  ✓", "       ✗", "PASS ", "     "}
	labels := []string{
		"",
		"run tests",
		"has every required workload component running",
		strings.Repeat("very long label ", 10),
	}

	for _, prefix := range prefixes {
		for _, label := range labels {
			got := lipgloss.Width(rowString(prefix, label, "25m47s"))
			if got != lineWidth {
				t.Errorf("row(%q, %.20q) width = %d, want %d", prefix, label, got, lineWidth)
			}
		}
	}
}

func TestJoinFallsBackToASCII(t *testing.T) {
	ui := &UI{unicode: true}
	if got := ui.Join("a", "b"); got != "a · b" {
		t.Errorf("unicode join = %q", got)
	}
	ui.unicode = false
	if got := ui.Join("a", "b"); got != "a | b" {
		t.Errorf("ascii join = %q", got)
	}
}

func TestReadSpecResults(t *testing.T) {
	specs, err := readSpecResults("testdata/report.json")
	if err != nil {
		t.Fatal(err)
	}
	if len(specs) != 7 {
		t.Fatalf("got %d specs, want 7", len(specs))
	}

	first := specs[0]
	if first.Text != "completes all workflows successfully" {
		t.Errorf("first spec text = %q", first.Text)
	}
	if got := FormatDuration(first.Duration); got != "7m40s" {
		t.Errorf("first spec duration = %q", got)
	}

	// The health specs sit one container deeper, which is what drives grouping.
	ui := &UI{unicode: false}
	last := specs[len(specs)-1]
	if got := last.Group(ui); got != "Workload cluster provisioning | cluster health" {
		t.Errorf("last spec group = %q", got)
	}
}

func TestSpecOutcome(t *testing.T) {
	for _, tc := range []struct {
		state types.SpecState
		want  Outcome
	}{
		{types.SpecStatePassed, OutcomeOK},
		{types.SpecStateFailed, OutcomeFail},
		{types.SpecStatePanicked, OutcomeFail},
		{types.SpecStateTimedout, OutcomeFail},
		{types.SpecStateSkipped, OutcomeOther},
		{types.SpecStatePending, OutcomeOther},
	} {
		got, _ := SpecResult{State: tc.state}.outcome()
		if got != tc.want {
			t.Errorf("outcome(%s) = %v, want %v", tc.state, got, tc.want)
		}
	}
}

// Flags may follow positional arguments, which stdlib flag would not accept.
func TestParseArgsInterleavesFlagsAndCombos(t *testing.T) {
	r := newTestRunner()
	if err := r.ParseArgs([]string{
		"colocated-ipv6-netboot-mirror", "--mirror-host", "reg.example.com",
		"--spares", "2", "--dry-run", "colocated-ipv4-netboot-direct", "-v",
	}); err != nil {
		t.Fatal(err)
	}

	opts := r.Opts
	if len(opts.Combos) != 2 || opts.Combos[0] != "colocated-ipv6-netboot-mirror" || opts.Combos[1] != "colocated-ipv4-netboot-direct" {
		t.Errorf("combos = %v", opts.Combos)
	}
	if opts.MirrorHost != "reg.example.com" || opts.Spares != 2 || !opts.DryRun || !opts.Verbose {
		t.Errorf("opts = %+v", opts)
	}
}

func TestParseArgsRejectsUnknownFlag(t *testing.T) {
	r := newTestRunner()
	err := r.ParseArgs([]string{"--nope"})
	if err == nil || !strings.Contains(err.Error(), "unknown flag") {
		t.Fatalf("err = %v", err)
	}
}

func TestParseArgsRequiresFlagValue(t *testing.T) {
	r := newTestRunner()
	err := r.ParseArgs([]string{"--mirror-host"})
	if err == nil || !strings.Contains(err.Error(), "missing value") {
		t.Fatalf("err = %v", err)
	}
}

func TestParseArgsCommands(t *testing.T) {
	for _, tc := range []struct {
		args    []string
		command string
		combos  int
	}{
		{nil, cmdNone, 0},
		{[]string{"list"}, cmdList, 0},
		{[]string{"clean"}, cmdClean, 0},
		{[]string{"version"}, cmdVersion, 0},
		{[]string{"--version"}, cmdVersion, 0},
		{[]string{"config", "colocated-ipv4-netboot-direct"}, cmdConfig, 1},
		{[]string{"help"}, cmdHelp, 0},
		{[]string{"run", "colocated-ipv4-netboot-direct"}, cmdRun, 1},
		// A bare combo is shorthand for run, with or without leading globals.
		{[]string{"colocated-ipv4-netboot-direct"}, cmdRun, 1},
		{[]string{"-v", "colocated-ipv4-netboot-direct"}, cmdRun, 1},
		// A command-scoped flag ahead of any command also means run.
		{[]string{"--all"}, cmdRun, 0},
		// Only the first positional names a command, so the shorthand cannot
		// swallow one.
		{[]string{"colocated-ipv4-netboot-direct", "list"}, cmdRun, 2},
	} {
		r := newTestRunner()
		if err := r.ParseArgs(tc.args); err != nil {
			t.Fatalf("%v: %v", tc.args, err)
		}
		if r.Opts.Command != tc.command {
			t.Errorf("%v: command = %q, want %q", tc.args, r.Opts.Command, tc.command)
		}
		if len(r.Opts.Combos) != tc.combos {
			t.Errorf("%v: combos = %v", tc.args, r.Opts.Combos)
		}
	}
}

// Global flags are accepted on either side of the command name.
func TestGlobalFlagsBeforeAndAfterCommand(t *testing.T) {
	for _, args := range [][]string{
		{"-v", "list"},
		{"list", "-v"},
	} {
		r := newTestRunner()
		if err := r.ParseArgs(args); err != nil {
			t.Fatalf("%v: %v", args, err)
		}
		if r.Opts.Command != cmdList || !r.Opts.Verbose {
			t.Errorf("%v: command = %q, verbose = %v", args, r.Opts.Command, r.Opts.Verbose)
		}
	}
}

// Flags belong to the command that declares them, so one command must not
// accept another's.
func TestFlagsAreScopedToTheirCommand(t *testing.T) {
	r := newTestRunner()
	if err := r.ParseArgs([]string{"list", "--no-teardown"}); err == nil {
		t.Fatal("list should not accept --no-teardown")
	}

	r = newTestRunner()
	if err := r.ParseArgs([]string{"run", "--json", "colocated-ipv4-netboot-direct"}); err == nil {
		t.Fatal("run should not accept --json")
	}
}

// Commands that take no combos should say so rather than silently ignoring the
// argument.
func TestCommandsWithoutArgumentsRejectThem(t *testing.T) {
	r := newTestRunner()
	err := r.ParseArgs([]string{"list", "colocated-ipv4-netboot-direct"})
	if err == nil || !strings.Contains(err.Error(), "takes no arguments") {
		t.Fatalf("err = %v", err)
	}
}

// A flag error should leave the user looking at the options list for the
// command that failed, and nothing else.
func TestFlagErrorsPrintCommandHelp(t *testing.T) {
	var out bytes.Buffer
	r := New(Options{Prog: "e2e"}, NewPaths("/tmp"), &UI{Out: io.Discard, ErrOut: &out})

	err := r.ParseArgs([]string{"run", "--mirror", "reg.example.com"})
	if err == nil {
		t.Fatal("expected an error for an unknown flag")
	}
	if !strings.Contains(err.Error(), "Did you mean '--mirror-host'") {
		t.Errorf("error did not suggest the real flag: %v", err)
	}
	for _, want := range []string{"Usage:", "Configuration:", "--mirror-host"} {
		if !strings.Contains(out.String(), want) {
			t.Errorf("run help missing %q", want)
		}
	}
	if strings.Contains(out.String(), "--json") {
		t.Error("run help leaked a flag belonging to another command")
	}
}

// -h prints help and reports it, so the caller can exit zero. Which help
// depends on where it appears.
func TestHelpFlagPrintsHelpAndReportsIt(t *testing.T) {
	for _, tc := range []struct {
		args []string
		want string
	}{
		{[]string{"-h"}, "Commands:"},
		{[]string{"--help"}, "Commands:"},
		{[]string{"run", "--help"}, "Configuration:"},
		{[]string{"list", "-h"}, "--json"},
	} {
		var out bytes.Buffer
		r := New(Options{Prog: "e2e"}, NewPaths("/tmp"), &UI{Out: &out, ErrOut: io.Discard})

		if err := r.ParseArgs(tc.args); !errors.Is(err, ErrHelpRequested) {
			t.Fatalf("%v: err = %v, want ErrHelpRequested", tc.args, err)
		}
		if !strings.Contains(out.String(), tc.want) {
			t.Errorf("%v: help missing %q", tc.args, tc.want)
		}
	}
}

// The root help's command list is generated, so every command must appear in it.
func TestRootHelpListsEveryCommand(t *testing.T) {
	var out bytes.Buffer
	r := New(Options{Prog: "e2e"}, NewPaths("/tmp"), &UI{Out: &out, ErrOut: io.Discard})
	r.PrintHelp(&out, nil)

	for _, name := range commandNames() {
		if !strings.Contains(out.String(), name) {
			t.Errorf("root help does not mention %q", name)
		}
	}
}

// Every command's help must render without a leftover formatting verb.
func TestEveryCommandHasHelp(t *testing.T) {
	for _, c := range commands {
		var out bytes.Buffer
		r := New(Options{Prog: "e2e"}, NewPaths("/tmp"), &UI{Out: &out, ErrOut: io.Discard})
		r.PrintHelp(&out, c)

		if !strings.Contains(out.String(), "Usage:") {
			t.Errorf("%s: help has no usage section", c.name)
		}
		if strings.Contains(out.String(), "%!") {
			t.Errorf("%s: help has a bad format verb:\n%s", c.name, out.String())
		}
	}
}

// Every flag is also an environment variable, prefixed and upper-cased.
func TestFlagsReadFromEnvironment(t *testing.T) {
	t.Setenv("E2E_MIRROR_HOST", "reg.from.env")
	t.Setenv("E2E_SPARES", "3")
	t.Setenv("E2E_NO_TEARDOWN", "true")

	r := newTestRunner()
	if err := r.ParseArgs([]string{"run"}); err != nil {
		t.Fatal(err)
	}

	if r.Opts.MirrorHost != "reg.from.env" || r.Opts.Spares != 3 || !r.Opts.NoTeardown {
		t.Errorf("opts from env = %+v", r.Opts)
	}
}

// An explicit flag beats the environment.
func TestFlagsBeatEnvironment(t *testing.T) {
	t.Setenv("E2E_MIRROR_HOST", "reg.from.env")

	r := newTestRunner()
	if err := r.ParseArgs([]string{"run", "--mirror-host", "reg.from.flag"}); err != nil {
		t.Fatal(err)
	}
	if r.Opts.MirrorHost != "reg.from.flag" {
		t.Errorf("MirrorHost = %q", r.Opts.MirrorHost)
	}
}

// The bare-combo shorthand only stays unambiguous while no combo is named
// after a command.
func TestCommandNamesDoNotCollideWithCombos(t *testing.T) {
	if err := validateCommandNames([]string{"colocated-ipv4-netboot-direct", "external-ipv4-isoboot-mirror"}); err != nil {
		t.Errorf("unexpected collision: %v", err)
	}
	if err := validateCommandNames([]string{"list"}); err == nil {
		t.Error("a combo named 'list' should be rejected")
	}
}

func TestSuggestsNearestCombo(t *testing.T) {
	known := []string{"colocated-ipv4-netboot-direct", "colocated-ipv4-netboot-mirror", "external-ipv4-isoboot-mirror"}

	if got := suggestion("colocated-ipv4-netboot-mirrr", known); !strings.Contains(got, "colocated-ipv4-netboot-mirror") {
		t.Errorf("suggestion = %q", got)
	}
	if got := suggestion("totally-different-thing", known); got != "" {
		t.Errorf("expected no suggestion, got %q", got)
	}
}

// A combo's playground is described by the files in its own artifact
// directory, never by the ones at the capt root.
func TestCleanTargetsUseComboArtifacts(t *testing.T) {
	artifacts := t.TempDir()
	writeComboArtifacts(t, artifacts, "colocated-ipv4-netboot-direct", "external-ipv4-isoboot-mirror")

	r := newTestRunner()
	r.Opts.ArtifactsDir = artifacts
	r.Opts.Combos = []string{"colocated-ipv4-netboot-direct"}

	targets, err := r.cleanTargets()
	if err != nil {
		t.Fatal(err)
	}
	if len(targets) != 1 {
		t.Fatalf("got %d targets, want 1", len(targets))
	}

	want := filepath.Join(artifacts, "colocated-ipv4-netboot-direct")
	if targets[0].pg.Config != filepath.Join(want, "config.yaml") {
		t.Errorf("config = %q", targets[0].pg.Config)
	}
	if targets[0].pg.State != filepath.Join(want, "state.yaml") {
		t.Errorf("state = %q", targets[0].pg.State)
	}
}

// --all reaches every combo left on disk, including ones no longer in the
// matrix, since those are exactly the ones nothing else will clean up.
func TestCleanTargetsAllFindsEveryCombo(t *testing.T) {
	artifacts := t.TempDir()
	writeComboArtifacts(t, artifacts, "colocated-ipv4-netboot-direct", "retired-combo")
	// A directory with no config describes no playground.
	if err := os.MkdirAll(filepath.Join(artifacts, "not-a-combo"), 0o755); err != nil {
		t.Fatal(err)
	}

	r := newTestRunner()
	r.Opts.ArtifactsDir = artifacts
	r.Opts.All = true

	targets, err := r.cleanTargets()
	if err != nil {
		t.Fatal(err)
	}

	var names []string
	for _, target := range targets {
		names = append(names, target.name)
	}
	if strings.Join(names, ",") != "colocated-ipv4-netboot-direct,retired-combo" {
		t.Errorf("targets = %v", names)
	}
}

// With no combo named, clean acts on the playground an interactive `task` run
// builds, which is the one the capt root's own files describe.
func TestCleanTargetsDefaultToRootPlayground(t *testing.T) {
	r := newTestRunner()
	r.Opts.ArtifactsDir = t.TempDir()

	targets, err := r.cleanTargets()
	if err != nil {
		t.Fatal(err)
	}
	if len(targets) != 1 || targets[0].pg.Config != r.Paths.Config || targets[0].pg.State != r.Paths.State {
		t.Errorf("targets = %+v", targets)
	}
}

func TestCleanTargetsRejectUnknownCombo(t *testing.T) {
	r := newTestRunner()
	r.Opts.ArtifactsDir = t.TempDir()
	r.Opts.Combos = []string{"never-ran"}

	_, err := r.cleanTargets()
	if err == nil || !strings.Contains(err.Error(), "no artifacts for combo") {
		t.Fatalf("err = %v", err)
	}
}

// A combo whose create died before it recorded anything has nothing to tear
// down, and should say so rather than reaching the Taskfile's precondition.
func TestCleanTargetsRejectComboWithoutState(t *testing.T) {
	artifacts := t.TempDir()
	dir := filepath.Join(artifacts, "colocated-ipv4-netboot-direct")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.yaml"), []byte("clusterName: e2e-test\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	r := newTestRunner()
	r.Opts.ArtifactsDir = artifacts
	r.Opts.Combos = []string{"colocated-ipv4-netboot-direct"}

	_, err := r.cleanTargets()
	if err == nil || !strings.Contains(err.Error(), "no state file") {
		t.Fatalf("err = %v", err)
	}

	// --all skips it rather than failing: one un-startable combo must not
	// stop the others being cleaned.
	r.Opts.Combos, r.Opts.All = nil, true
	targets, err := r.cleanTargets()
	if err != nil {
		t.Fatal(err)
	}
	if len(targets) != 0 {
		t.Errorf("targets = %+v", targets)
	}
}

// Files a failed run wrote must not survive into the next one, or a stale
// create-error.log ends up sitting beside a successful create.log.
func TestResetArtifactsClearsTheDirectory(t *testing.T) {
	artifacts := filepath.Join(t.TempDir(), "colocated-ipv4-netboot-direct")
	if err := os.MkdirAll(artifacts, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(artifacts, "create-error.log")
	if err := os.WriteFile(stale, []byte("from a previous run\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	r := newTestRunner()
	if err := r.resetArtifacts(artifacts); err != nil {
		t.Fatal(err)
	}

	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Error("stale create-error.log survived the reset")
	}
	if _, err := os.Stat(artifacts); err != nil {
		t.Errorf("artifact directory was not recreated: %v", err)
	}
}

// A playground that is still up must not have its state file wiped: that is
// the record naming the resources it left behind. Liveness is asked of docker,
// not of the files in the artifact directory.
func TestResetArtifactsRefusesToStrandAPlayground(t *testing.T) {
	artifacts := filepath.Join(t.TempDir(), "colocated-ipv4-netboot-direct")
	if err := os.MkdirAll(artifacts, 0o755); err != nil {
		t.Fatal(err)
	}
	state := filepath.Join(artifacts, "state.yaml")
	if err := os.WriteFile(state, []byte("clusterName: e2e-test\ninstance: a1b2c3d4\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	restore := stubNetworksForInstance(t, "capt-playground-a1b2c3d4")
	defer restore()

	r := newTestRunner()
	err := r.resetArtifacts(artifacts)
	if err == nil || !strings.Contains(err.Error(), "still running") {
		t.Fatalf("err = %v", err)
	}
	if _, statErr := os.Stat(state); statErr != nil {
		t.Error("the state file was removed despite the refusal")
	}
}

// A playground whose network is gone was torn down, so its leftovers are just
// stale files.
func TestResetArtifactsClearsATornDownPlayground(t *testing.T) {
	artifacts := filepath.Join(t.TempDir(), "colocated-ipv4-netboot-direct")
	if err := os.MkdirAll(artifacts, 0o755); err != nil {
		t.Fatal(err)
	}
	state := filepath.Join(artifacts, "state.yaml")
	if err := os.WriteFile(state, []byte("clusterName: e2e-test\ninstance: a1b2c3d4\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	restore := stubNetworksForInstance(t, "")
	defer restore()

	r := newTestRunner()
	if err := r.resetArtifacts(artifacts); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(state); !os.IsNotExist(err) {
		t.Error("stale state survived the reset")
	}
}

func stubNetworksForInstance(t *testing.T, networks string) func() {
	t.Helper()
	previous := networksForInstance
	networksForInstance = func(string, string) (string, error) { return networks, nil }
	return func() { networksForInstance = previous }
}

// A dry run previews; it must not destroy a previous run's artifacts.
func TestResetArtifactsKeepsFilesOnDryRun(t *testing.T) {
	artifacts := filepath.Join(t.TempDir(), "colocated-ipv4-netboot-direct")
	if err := os.MkdirAll(artifacts, 0o755); err != nil {
		t.Fatal(err)
	}
	kept := filepath.Join(artifacts, "create.log")
	if err := os.WriteFile(kept, []byte("previous run\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	r := newTestRunner()
	r.Opts.DryRun = true
	if err := r.resetArtifacts(artifacts); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(kept); err != nil {
		t.Error("a dry run deleted the previous run's artifacts")
	}
}

// The suite is handed every path it needs. Deriving one from another — the CNI
// script was once inferred from the state file's directory — breaks silently
// the moment either moves, and only seven minutes into a run.
func TestGinkgoArgsPassEveryPathExplicitly(t *testing.T) {
	captDir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(captDir, "scripts"), 0o755); err != nil {
		t.Fatal(err)
	}
	script := filepath.Join(captDir, "scripts", "deploy_cni.sh")
	if err := os.WriteFile(script, []byte("#!/bin/bash\n"), 0o755); err != nil {
		t.Fatal(err)
	}

	r := New(Options{Prog: "e2e"}, NewPaths(captDir), &UI{Out: io.Discard, ErrOut: io.Discard})
	artifacts := filepath.Join(captDir, "e2e", "artifacts", "colocated-ipv4-netboot-direct")
	state := State{Namespace: "tinkerbell", path: filepath.Join(artifacts, "state.yaml")}

	args := r.ginkgoArgs("provisioning", artifacts, state)

	got := map[string]string{}
	for _, arg := range args {
		if name, value, ok := strings.Cut(arg, "="); ok && strings.HasPrefix(name, "-e2e.") {
			got[name] = value
		}
	}

	if got["-e2e.cni-script"] != script {
		t.Errorf("-e2e.cni-script = %q, want %q", got["-e2e.cni-script"], script)
	}
	// The script lives with the playground, not with the combo's artifacts.
	if strings.HasPrefix(got["-e2e.cni-script"], artifacts) {
		t.Error("-e2e.cni-script points inside the artifact directory")
	}
	if _, err := os.Stat(got["-e2e.cni-script"]); err != nil {
		t.Errorf("-e2e.cni-script does not exist: %v", err)
	}
	if got["-e2e.state-file"] != state.Path() {
		t.Errorf("-e2e.state-file = %q", got["-e2e.state-file"])
	}
}

func writeComboArtifacts(t *testing.T, artifacts string, combos ...string) {
	t.Helper()
	for _, combo := range combos {
		dir := filepath.Join(artifacts, combo)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		for name, body := range map[string]string{
			"config.yaml": "clusterName: e2e-test\n",
			"state.yaml":  "clusterName: e2e-test\noutputDir: " + filepath.Join(dir, "output") + "\n",
		} {
			if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o600); err != nil {
				t.Fatal(err)
			}
		}
	}
}

func newTestRunner() *Runner {
	ui := &UI{Out: io.Discard, ErrOut: io.Discard}
	return New(Options{Prog: "e2e"}, NewPaths("/tmp"), ui)
}
