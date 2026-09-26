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
// the combo's ginkgo.log; per-test results come from report.json.
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

// TestResult is one Ginkgo It, flattened for reporting.
type TestResult struct {
	Containers []string
	Text       string
	State      types.SpecState
	Duration   time.Duration
}

// Group is the container hierarchy the test sits in.
func (s TestResult) Group(ui *UI) string {
	return ui.Join(s.Containers...)
}

// outcome maps a Ginkgo state onto a marker, with a note for anything that is
// neither a pass nor a failure.
func (s TestResult) outcome() (Outcome, string) {
	switch s.State {
	case types.SpecStatePassed:
		return OutcomeOK, ""
	case types.SpecStateFailed, types.SpecStatePanicked, types.SpecStateAborted, types.SpecStateInterrupted, types.SpecStateTimedout:
		return OutcomeFail, ""
	default:
		return OutcomeOther, s.State.String()
	}
}

// readTestResults flattens a Ginkgo JSON report into the It tests it contains.
func readTestResults(path string) ([]TestResult, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var reports []types.Report
	if err := json.Unmarshal(data, &reports); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", path, err)
	}

	var tests []TestResult
	for _, report := range reports {
		for _, test := range report.SpecReports {
			if test.LeafNodeType != types.NodeTypeIt {
				continue
			}
			tests = append(tests, TestResult{
				Containers: test.ContainerHierarchyTexts,
				Text:       test.LeafNodeText,
				State:      test.State,
				Duration:   test.RunTime,
			})
		}
	}
	return tests, nil
}

// printTestResults lists every test the suite ran, grouped by the container
// hierarchy so the shared prefix is stated once. Ginkgo's own per-test output
// goes to ginkgo.log, which is not shown while the matrix runs. It returns the
// number of tests and how many of them failed.
func (r *Runner) printTestResults(reportPath string) (total, failed int) {
	tests, err := readTestResults(reportPath)
	if err != nil {
		r.UI.Log("")
		r.UI.Log("       (no test results: %v)", err)
		return 0, 0
	}
	if len(tests) == 0 {
		r.UI.Log("")
		r.UI.Log("       (no tests ran)")
		return 0, 0
	}

	lastGroup := "\x00"
	for _, test := range tests {
		if group := test.Group(r.UI); group != lastGroup {
			r.UI.TestGroup(group)
			lastGroup = group
		}
		outcome, note := test.outcome()
		if outcome == OutcomeFail {
			failed++
		}
		r.UI.TestLine(test.Text, outcome, note, test.Duration)
	}
	r.UI.Log("")

	return len(tests), failed
}
