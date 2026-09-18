package runner

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/onsi/ginkgo/v2/types"
)

const ginkgoVersion = "v2.28.1"

// ensureGinkgo installs the pinned Ginkgo CLI into capt/bin alongside the other
// playground tools.
func (r *Runner) ensureGinkgo() (string, error) {
	versioned := filepath.Join(r.Paths.Bin, "ginkgo-"+ginkgoVersion)
	link := filepath.Join(r.Paths.Bin, "ginkgo")

	if _, err := os.Stat(versioned); err != nil {
		r.UI.Log("installing ginkgo %s to %s", ginkgoVersion, r.Paths.Rel(r.Paths.Bin))
		cmd := []string{"install", "github.com/onsi/ginkgo/v2/ginkgo@" + ginkgoVersion}
		if err := runWithEnv(r.Paths.Capt, r.UI.Out, []string{"GOBIN=" + r.Paths.Bin}, "go", cmd...); err != nil {
			return "", fmt.Errorf("installing ginkgo: %w", err)
		}
		if err := os.Rename(filepath.Join(r.Paths.Bin, "ginkgo"), versioned); err != nil {
			return "", err
		}
	}

	_ = os.Remove(link)
	if err := os.Symlink("ginkgo-"+ginkgoVersion, link); err != nil {
		return "", err
	}
	return link, nil
}

// ginkgoArgs builds the suite invocation. Every path the suite needs is passed
// explicitly; it is given no directory it could derive one from.
func (r *Runner) ginkgoArgs(labels, artifacts string, state State) []string {
	args := []string{
		"-v",
		"--label-filter=" + labels,
		"--output-dir=" + artifacts,
		"--junit-report=junit.xml",
		"--json-report=report.json",
		"./...",
		"--",
		"-e2e.config=" + filepath.Join(r.Paths.E2E, "test", "config", "e2e.yaml"),
		"-e2e.artifacts=" + artifacts,
		"-e2e.mgmt-kubeconfig=" + state.MgmtKubeconfig(),
		"-e2e.workload-kubeconfig=" + state.WorkloadKubeconfig(),
		"-e2e.namespace=" + state.Namespace,
		"-e2e.state-file=" + state.Path(),
		"-e2e.cni-script=" + r.Paths.CNIScript,
	}
	if tink := state.TinkKubeconfig(); tink != "" {
		args = append(args, "-e2e.tink-kubeconfig="+tink)
	}
	return args
}

// runGinkgo runs the suite against the current playground. Full output goes to
// the combo's ginkgo.log; per-spec results come from report.json.
func (r *Runner) runGinkgo(labels, artifacts string, state State, sink io.Writer) error {
	logFile, err := os.Create(filepath.Join(artifacts, "ginkgo.log"))
	if err != nil {
		return err
	}
	defer logFile.Close()

	var w io.Writer = logFile
	if sink != nil {
		w = io.MultiWriter(logFile, sink)
	}

	return run(filepath.Join(r.Paths.E2E, "test"), w, r.ginkgo, r.ginkgoArgs(labels, artifacts, state)...)
}

// SpecResult is one Ginkgo It, flattened for reporting.
type SpecResult struct {
	Containers []string
	Text       string
	State      types.SpecState
	Duration   time.Duration
}

// Group is the container hierarchy the spec sits in.
func (s SpecResult) Group(ui *UI) string {
	return ui.Join(s.Containers...)
}

// outcome maps a Ginkgo state onto a marker, with a note for anything that is
// neither a pass nor a failure.
func (s SpecResult) outcome() (Outcome, string) {
	switch s.State {
	case types.SpecStatePassed:
		return OutcomeOK, ""
	case types.SpecStateFailed, types.SpecStatePanicked, types.SpecStateAborted, types.SpecStateInterrupted, types.SpecStateTimedout:
		return OutcomeFail, ""
	default:
		return OutcomeOther, s.State.String()
	}
}

// readSpecResults flattens a Ginkgo JSON report into the It specs it contains.
func readSpecResults(path string) ([]SpecResult, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var reports []types.Report
	if err := json.Unmarshal(data, &reports); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", path, err)
	}

	var specs []SpecResult
	for _, report := range reports {
		for _, spec := range report.SpecReports {
			if spec.LeafNodeType != types.NodeTypeIt {
				continue
			}
			specs = append(specs, SpecResult{
				Containers: spec.ContainerHierarchyTexts,
				Text:       spec.LeafNodeText,
				State:      spec.State,
				Duration:   spec.RunTime,
			})
		}
	}
	return specs, nil
}

// printSpecResults lists every spec the suite ran, grouped by the container
// hierarchy so the shared prefix is stated once. Ginkgo's own per-spec output
// goes to ginkgo.log, which is not shown while the matrix runs. It returns the
// number of specs and how many of them failed.
func (r *Runner) printSpecResults(reportPath string) (total, failed int) {
	specs, err := readSpecResults(reportPath)
	if err != nil {
		r.UI.Log("")
		r.UI.Log("       (no spec results: %v)", err)
		return 0, 0
	}
	if len(specs) == 0 {
		r.UI.Log("")
		r.UI.Log("       (no specs ran)")
		return 0, 0
	}

	lastGroup := "\x00"
	for _, spec := range specs {
		if group := spec.Group(r.UI); group != lastGroup {
			r.UI.SpecGroup(group)
			lastGroup = group
		}
		outcome, note := spec.outcome()
		if outcome == OutcomeFail {
			failed++
		}
		r.UI.SpecLine(spec.Text, outcome, note, spec.Duration)
	}
	r.UI.Log("")

	return len(specs), failed
}
