package runner

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"time"
)

// Runner carries the configuration and derived state for a matrix run.
type Runner struct {
	Opts   Options
	Paths  Paths
	UI     *UI
	ginkgo string

	chartOnce sync.Once
	chartVer  string
	chartErr  error
}

func New(opts Options, paths Paths, ui *UI) *Runner {
	return &Runner{Opts: opts, Paths: paths, UI: ui}
}

// Execute dispatches the parsed command and returns the process exit code.
func (r *Runner) Execute() int {
	cmd := lookupCommand(r.Opts.Command)
	if cmd == nil {
		r.PrintHelp(r.UI.Out, nil)
		return 0
	}
	return cmd.exec(r)
}

func (r *Runner) execHelp() int {
	if r.Opts.HelpTopic == "" {
		r.PrintHelp(r.UI.Out, nil)
		return 0
	}

	cmd := lookupCommand(r.Opts.HelpTopic)
	if cmd == nil {
		r.UI.Err("Error: unknown command: %s%s", r.Opts.HelpTopic, suggestion(r.Opts.HelpTopic, commandNames()))
		return 1
	}
	r.PrintHelp(r.UI.Out, cmd)
	return 0
}

func (r *Runner) execVersion() int {
	r.UI.Info("%s", version())
	return 0
}

func (r *Runner) execList() int {
	if err := r.PrintCombos(); err != nil {
		r.UI.Err("Error: %v", err)
		return 1
	}
	return 0
}

func (r *Runner) execClean() int {
	targets, err := r.cleanTargets()
	if err != nil {
		r.UI.Err("Error: %v", err)
		return 1
	}
	if len(targets) == 0 {
		r.UI.Info("nothing to clean in %s", r.Paths.Rel(r.Opts.ArtifactsDir))
		return 0
	}

	// One failure must not strand the remaining playgrounds, so every target
	// is attempted and the failures are reported together at the end.
	var failed []string
	for _, t := range targets {
		if err := r.Cleanup(t); err != nil {
			r.UI.Warn("%v", err)
			failed = append(failed, t.name)
		}
	}

	if len(failed) > 0 {
		r.UI.Err("Error: could not clean: %s", strings.Join(failed, " "))
		return 1
	}
	return 0
}

// cleanTargets resolves what to tear down: the named combos, every combo with
// artifacts, or — with nothing named — the playground the capt directory's own
// config and state describe, which is what an interactive `task` run leaves.
func (r *Runner) cleanTargets() ([]cleanTarget, error) {
	if err := r.resolveArtifactsDir(); err != nil {
		return nil, err
	}

	switch {
	case r.Opts.All:
		return r.comboArtifacts()
	case len(r.Opts.Combos) == 0:
		return []cleanTarget{{
			name: "playground",
			pg:   playground{Config: r.Paths.Config, State: r.Paths.State},
		}}, nil
	}

	targets := make([]cleanTarget, 0, len(r.Opts.Combos))
	for _, combo := range r.Opts.Combos {
		pg := playgroundAt(filepath.Join(r.Opts.ArtifactsDir, combo))
		if _, err := os.Stat(pg.Config); err != nil {
			return nil, fmt.Errorf("no artifacts for combo %q under %s\nRun '%s clean' with no combo to tear down the playground capt/.state records.",
				combo, r.Paths.Rel(r.Opts.ArtifactsDir), r.Opts.Prog)
		}
		// Teardown is driven by the state file, so say which combo is missing
		// one rather than letting the Taskfile's precondition report a path.
		if _, err := os.Stat(pg.State); err != nil {
			return nil, fmt.Errorf("combo %q has no state file at %s\nIts create failed before the playground recorded what it built, so there is nothing to tear down.",
				combo, r.Paths.Rel(pg.State))
		}
		targets = append(targets, cleanTarget{name: combo, pg: pg})
	}
	return targets, nil
}

// comboArtifacts finds every combo with a state file on disk. State is the
// record of what a run actually built, so its presence is what marks a combo
// as having something left to tear down — including combos that are no longer
// in the matrix, which nothing else would clean up.
func (r *Runner) comboArtifacts() ([]cleanTarget, error) {
	entries, err := os.ReadDir(r.Opts.ArtifactsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}

	var targets []cleanTarget
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		pg := playgroundAt(filepath.Join(r.Opts.ArtifactsDir, entry.Name()))
		if _, err := os.Stat(pg.State); err != nil {
			continue
		}
		targets = append(targets, cleanTarget{name: entry.Name(), pg: pg})
	}
	return targets, nil
}

func (r *Runner) execConfig() int {
	if code := r.validateOrUsage(cmdConfig); code != 0 {
		return code
	}
	if err := r.PrintComboConfig(); err != nil {
		r.UI.Err("Error: %v", err)
		return 1
	}
	return 0
}

func (r *Runner) execRun() int {
	if code := r.validateOrUsage(cmdRun); code != 0 {
		return code
	}
	return r.Run()
}

// validateOrUsage reports the exit code to return, or zero to carry on. An
// empty selection is a usage slip rather than a failure, so it gets the one
// line that fixes it instead of the command's whole help.
func (r *Runner) validateOrUsage(name string) int {
	err := r.Validate()
	switch {
	case err == nil:
		return 0
	case errors.Is(err, ErrNoCombos):
		r.UI.Err("Error: %s needs at least one combo", name)
		r.UI.Err("")
		r.UI.Err("Usage: %s %s <combo>...", r.Opts.Prog, name)
		r.UI.Err("Run '%s list' to see the available combos.", r.Opts.Prog)
		return 1
	default:
		r.UI.Err("Error: %v", err)
		return 1
	}
}

// version reports the build revision Go stamps into the binary.
func version() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "e2e (unknown)"
	}
	var revision, modified string
	for _, setting := range info.Settings {
		switch setting.Key {
		case "vcs.revision":
			revision = setting.Value
		case "vcs.modified":
			if setting.Value == "true" {
				modified = "-dirty"
			}
		}
	}
	if revision == "" {
		return "e2e (devel)"
	}
	if len(revision) > 12 {
		revision = revision[:12]
	}
	return "e2e " + revision + modified
}

// Run executes the selected combos and returns the process exit code.
func (r *Runner) Run() int {
	if err := os.MkdirAll(r.Opts.ArtifactsDir, 0o755); err != nil {
		r.UI.Err("Error: %v", err)
		return 1
	}

	ginkgo, err := r.ensureGinkgo()
	if err != nil {
		r.UI.Err("Error: %v", err)
		return 1
	}
	r.ginkgo = ginkgo

	results := make([]Result, 0, len(r.Opts.Combos))
	for i, combo := range r.Opts.Combos {
		results = append(results, r.runCombo(combo, i+1, len(r.Opts.Combos)))
	}

	anyFailed := r.printSummary(results)

	r.UI.Info("")
	if anyFailed {
		return 1
	}
	return 0
}

func (r *Runner) runCombo(combo string, index, total int) Result {
	artifacts := filepath.Join(r.Opts.ArtifactsDir, combo)
	start := time.Now()

	r.UI.Heading(combo, index, total)
	// build + test, plus teardown unless the playground is being left running.
	steps := 2
	if !r.Opts.NoTeardown {
		steps = 3
	}
	r.UI.BeginSteps(steps)

	if err := r.resetArtifacts(artifacts); err != nil {
		return Result{Name: combo, Status: StatusFail, Duration: time.Since(start), Detail: err.Error()}
	}

	labels, err := r.resolveLabels(combo)
	if err != nil {
		return Result{Name: combo, Status: StatusFail, Duration: time.Since(start), Detail: "resolving labels: " + err.Error()}
	}
	r.UI.Detail("label filter: %s", labels)
	r.UI.Detail("artifacts:    %s", artifacts)

	// Ahead of prepareConfig so a version that cannot be resolved is reported
	// as that, rather than as the CUE render it would go on to break.
	tinkerbell, err := r.tinkerbellDescription()
	if err != nil {
		return Result{Name: combo, Status: StatusFail, Duration: time.Since(start), Detail: err.Error()}
	}
	r.UI.Log("  tinkerbell: %s", tinkerbell)

	if err := r.prepareConfig(combo, artifacts); err != nil {
		return Result{Name: combo, Status: StatusFail, Duration: time.Since(start), Detail: err.Error()}
	}

	if r.Opts.DryRun {
		r.UI.Log("  would create the playground and run: ginkgo --label-filter=%s", labels)
		if data, err := os.ReadFile(playgroundAt(artifacts).Config); err == nil {
			r.UI.Detail("%s", strings.TrimRight(string(data), "\n"))
		}
		return Result{Name: combo, Status: StatusDry}
	}

	result := r.runTests(combo, artifacts, labels)
	result.Name = combo
	result.Detail = r.teardown(combo, artifacts, result.Detail)
	result.Duration = time.Since(start)

	return result
}

// resetArtifacts empties the combo's artifact directory, so what is in it
// describes this run and no other. Files only written on failure — chiefly
// create-error.log — would otherwise survive into a later successful run and
// misrepresent it.
func (r *Runner) resetArtifacts(artifacts string) error {
	if r.Opts.DryRun {
		return os.MkdirAll(artifacts, 0o755)
	}

	// Wiping the state file of a playground that is still up would leave it
	// with nothing left to name it. Whether it is up is asked of docker, not
	// of the files here: the playground's network carries its instance id and
	// lives exactly as long as the playground does.
	if live, err := r.playgroundIsLive(playgroundAt(artifacts)); err != nil {
		return err
	} else if live {
		return fmt.Errorf("%s is still running; clean it up first with: %s clean %s",
			r.Paths.Rel(artifacts), r.Opts.Prog, filepath.Base(artifacts))
	}

	if err := os.RemoveAll(artifacts); err != nil {
		return err
	}
	return os.MkdirAll(artifacts, 0o755)
}

// playgroundIsLive reports whether the playground a state file describes still
// has its docker network, which it holds from creation until teardown.
func (r *Runner) playgroundIsLive(pg playground) (bool, error) {
	state, err := r.ReadState(pg)
	if err != nil {
		// No state file: nothing was ever recorded, so nothing is running.
		return false, nil
	}
	if state.Instance == "" {
		return false, nil
	}

	networks, err := networksForInstance(r.Paths.Capt, state.Instance)
	if err != nil {
		return false, nil
	}
	return strings.TrimSpace(networks) != "", nil
}

// networksForInstance is a variable so tests can answer it without docker.
var networksForInstance = func(dir, instance string) (string, error) {
	return capture(dir, "docker", "network", "ls",
		"--filter", "label=capt.playground.id="+instance, "--format", "{{.Name}}")
}

// resolveLabels picks the Ginkgo filter for a combo. --labels overrides
// everything; a supplied config with no combo has no axes to derive one from.
func (r *Runner) resolveLabels(combo string) (string, error) {
	switch {
	case r.Opts.Labels != "":
		return r.Opts.Labels, nil
	case combo == customCombo:
		return "provisioning", nil
	default:
		return r.ComboLabels(combo)
	}
}

// prepareConfig writes the config.yaml for this combo into its artifact dir.
// Nothing is installed at the capt root: every task invocation is pointed at
// this file instead, so combos cannot overwrite each other's configuration.
func (r *Runner) prepareConfig(combo, artifacts string) error {
	dest := playgroundAt(artifacts).Config

	if r.Opts.ConfigFile != "" {
		r.UI.Log("  config:     %s (supplied)", r.Paths.Rel(r.Opts.ConfigFile))
		return r.CopySuppliedConfig(r.Opts.ConfigFile, dest)
	}

	r.UI.Log("  config:     rendered from combo")
	if err := r.RenderComboConfig(combo, dest); err != nil {
		r.UI.Err("")
		r.UI.Err("CUE render failed:")
		if data, readErr := os.ReadFile(dest); readErr == nil {
			r.UI.Err("%s", strings.TrimRight(string(data), "\n"))
		}
		return errors.New("CUE render failed")
	}
	return nil
}

// runTests builds the playground and runs the suite against it.
func (r *Runner) runTests(combo, artifacts, labels string) Result {
	createLog := filepath.Join(artifacts, "create.log")
	pg := playgroundAt(artifacts)

	var state State
	createFailed := false

	if err := r.UI.Step("build playground", func(sink io.Writer) error {
		if err := r.createPlayground(pg, createLog, sink); err != nil {
			createFailed = true
			return err
		}

		var err error
		if state, err = r.ReadState(pg); err != nil {
			return err
		}
		r.UI.Detail("workload kubeconfig: %s", state.WorkloadKubeconfig())

		// CAPI has normally written the kubeconfig by the time the playground
		// finishes building; this only covers the case where it has not.
		if !waitForWorkloadKubeconfig(state.WorkloadKubeconfig()) {
			return fmt.Errorf("workload kubeconfig not written after %s", workloadKubeconfigTimeout)
		}
		return nil
	}); err != nil {
		// The test step will not run; keep teardown's number tied to the plan.
		r.UI.SkipStep()
		if createFailed {
			errLog := filepath.Join(artifacts, "create-error.log")
			if copyErr := copyFile(createLog, errLog); copyErr == nil {
				r.showLogTail(errLog)
			}
			return Result{Status: StatusFail, Detail: "could not build the playground"}
		}
		return Result{Status: StatusFail, Detail: err.Error()}
	}

	testErr := r.UI.Step("run tests", func(sink io.Writer) error {
		return r.runGinkgo(labels, artifacts, state, sink)
	})

	result := Result{Status: StatusPass}
	result.Specs, result.SpecsFailed = r.printSpecResults(filepath.Join(artifacts, "report.json"))

	if testErr != nil {
		result.Status = StatusFail
		result.Detail = "tests failed"
		r.UI.Err("")
		r.UI.Err("test output: %s", r.Paths.Rel(filepath.Join(artifacts, "ginkgo.log")))
	}
	return result
}

// showLogTail prints the end of a failed command's log, which is otherwise only
// in the artifact directory.
func (r *Runner) showLogTail(path string) {
	lines := 20
	if r.Opts.Verbose {
		lines = 100
	}
	r.UI.Err("")
	r.UI.Err("last %d lines of %s:", lines, r.Paths.Rel(path))
	r.UI.Err("%s", indentTail(path, lines, "  | "))
}

func (r *Runner) teardown(combo, artifacts, detail string) string {
	if r.Opts.NoTeardown {
		r.UI.Log("")
		r.UI.Log("  --no-teardown: playground left RUNNING; VMs, kind clusters and the BMC")
		r.UI.Log("  container persist. Clean up with: %s clean %s", r.Opts.Prog, combo)
		return detail
	}

	deleteLog := filepath.Join(artifacts, "delete.log")
	if err := r.UI.Step("tear down playground", func(sink io.Writer) error {
		return r.deletePlayground(playgroundAt(artifacts), deleteLog, sink)
	}); err != nil {
		r.UI.Warn("teardown failed (%v); see %s", err, r.Paths.Rel(deleteLog))
		r.UI.Warn("retry with: %s clean %s", r.Opts.Prog, combo)
		if detail != "" {
			return detail + "; teardown failed"
		}
		return "teardown failed"
	}
	return detail
}

// indentTail returns the last n lines of a file with each line prefixed.
func indentTail(path string, n int, prefix string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return prefix + err.Error()
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	for i := range lines {
		lines[i] = prefix + lines[i]
	}
	return strings.Join(lines, "\n")
}
