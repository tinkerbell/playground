package runner

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"gopkg.in/yaml.v3"
)

// How long to wait for CAPI to write the workload cluster kubeconfig.
const workloadKubeconfigTimeout = 5 * time.Minute

// State is the subset of the playground's .state file the runner needs.
type State struct {
	ClusterName        string `yaml:"clusterName"`
	Instance           string `yaml:"instance"`
	OutputDir          string `yaml:"outputDir"`
	Namespace          string `yaml:"namespace"`
	ExternalTinkerbell bool   `yaml:"externalTinkerbell"`
	Kind               struct {
		Kubeconfig string `yaml:"kubeconfig"`
		Tinkerbell struct {
			Kubeconfig string `yaml:"kubeconfig"`
		} `yaml:"tinkerbell"`
	} `yaml:"kind"`

	path string
}

// Path is the location the state was read from, which the suite needs as a flag.
func (s State) Path() string { return s.path }

// MgmtKubeconfig is the management (kind) cluster kubeconfig.
func (s State) MgmtKubeconfig() string { return s.Kind.Kubeconfig }

// TinkKubeconfig is the separate Tinkerbell cluster kubeconfig, empty unless the
// combo runs Tinkerbell externally.
func (s State) TinkKubeconfig() string {
	if !s.ExternalTinkerbell {
		return ""
	}
	return s.Kind.Tinkerbell.Kubeconfig
}

// WorkloadKubeconfig is where CAPI writes the workload cluster's kubeconfig.
func (s State) WorkloadKubeconfig() string {
	return filepath.Join(s.OutputDir, s.ClusterName+".kubeconfig")
}

// playground is the pair of files that say what a playground is made of.
// Passing them to `task` instead of writing them to the capt root is what
// keeps one combo's teardown from acting on another's resources.
type playground struct {
	Config string
	State  string
}

// playgroundAt is the playground a combo's artifact directory describes.
func playgroundAt(artifacts string) playground {
	return playground{
		Config: filepath.Join(artifacts, "config.yaml"),
		State:  filepath.Join(artifacts, "state.yaml"),
	}
}

func (p playground) taskVars() []string {
	return []string{"CONFIG_FILE=" + p.Config, "STATE_FILE=" + p.State}
}

// taskEnv keeps this playground's task fingerprints to itself. They are keyed
// by task name alone, so playgrounds sharing a directory overwrite each
// other's and re-run work that was already done. TASK_TEMP_DIR is read from
// the environment before the Taskfile is parsed, so it cannot be set there.
func (p playground) taskEnv() []string {
	return []string{"TASK_TEMP_DIR=" + filepath.Join(filepath.Dir(p.State), ".task")}
}

func taskArgs(pg playground, name string, leading ...string) []string {
	return append(append(leading, name), pg.taskVars()...)
}

func (r *Runner) createPlayground(pg playground, logPath string, sink io.Writer) error {
	return r.runToLog(pg, logPath, sink, "task", taskArgs(pg, "create-playground", "--yes")...)
}

func (r *Runner) deletePlayground(pg playground, logPath string, sink io.Writer) error {
	return r.runToLog(pg, logPath, sink, "task", taskArgs(pg, "delete-playground")...)
}

// cleanTarget is one playground the clean command will tear down.
type cleanTarget struct {
	name string
	pg   playground
}

// Cleanup deletes one playground, driven by the config and state that built
// it rather than by whatever happens to sit at the capt root.
func (r *Runner) Cleanup(t cleanTarget) error {
	if r.Opts.DryRun {
		r.UI.Info("%s: would delete the playground recorded in %s", t.name, r.Paths.Rel(t.pg.State))
		return nil
	}

	r.UI.Info("%s: deleting playground", t.name)
	if err := runWithEnv(r.Paths.Capt, r.UI.Out, t.pg.taskEnv(), "task", taskArgs(t.pg, "delete-playground")...); err != nil {
		return fmt.Errorf("%s: %w", t.name, err)
	}
	return nil
}

// ReadState loads the playground's state file.
func (r *Runner) ReadState(pg playground) (State, error) {
	data, err := os.ReadFile(pg.State)
	if err != nil {
		return State{}, fmt.Errorf("reading state: %w", err)
	}
	var s State
	if err := yaml.Unmarshal(data, &s); err != nil {
		return State{}, fmt.Errorf("parsing %s: %w", pg.State, err)
	}
	s.path = pg.State
	return s, nil
}

// waitForWorkloadKubeconfig blocks until CAPI has written the file, or the
// timeout expires.
func waitForWorkloadKubeconfig(path string) bool {
	deadline := time.Now().Add(workloadKubeconfigTimeout)
	for {
		if _, err := os.Stat(path); err == nil {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(5 * time.Second)
	}
}

// runToLog records a command's output to logPath, and mirrors it to sink for
// live display.
func (r *Runner) runToLog(pg playground, logPath string, sink io.Writer, name string, args ...string) error {
	f, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer f.Close()

	var w io.Writer = f
	if sink != nil {
		w = io.MultiWriter(f, sink)
	}
	return runWithEnv(r.Paths.Capt, w, pg.taskEnv(), name, args...)
}
