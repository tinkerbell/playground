package runner

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

// Status is a combo's outcome.
type Status string

const (
	StatusPass Status = "PASS"
	StatusFail Status = "FAIL"
	StatusDry  Status = "DRY"
)

// Result is one combo's outcome, as reported in the summary.
type Result struct {
	Name        string
	Status      Status
	Duration    time.Duration
	Detail      string
	Specs       int
	SpecsFailed int
}

// testSummary describes the test tally, e.g. "7 tests" or "1 of 7 tests failed".
func (r Result) testSummary() string {
	switch {
	case r.Specs == 0:
		return ""
	case r.SpecsFailed > 0:
		return fmt.Sprintf("%d of %d tests failed", r.SpecsFailed, r.Specs)
	case r.Specs == 1:
		return "1 test"
	default:
		return fmt.Sprintf("%d tests", r.Specs)
	}
}

// printSummary writes the verdict and artifact pointers, reporting whether any
// combo failed.
func (r *Runner) printSummary(results []Result) bool {
	var passed, failed, dry, other int
	var total time.Duration

	for _, res := range results {
		total += res.Duration
		switch res.Status {
		case StatusPass:
			passed++
		case StatusFail:
			failed++
		case StatusDry:
			dry++
		default:
			other++
		}
	}

	r.UI.Info("")

	// A single combo needs no table; the one row is the verdict.
	if len(results) == 1 {
		res := results[0]
		parts := []string{res.Name}
		if s := res.testSummary(); s != "" {
			parts = append(parts, s)
		}
		r.UI.Verdict(res.Status, r.UI.Join(parts...), res.Duration)

		if res.Detail != "" {
			r.UI.Info("      %s", res.Detail)
		}
		r.UI.Info("      artifacts: %s", r.Paths.Rel(filepath.Join(r.Opts.ArtifactsDir, res.Name)))
		return failed > 0
	}

	for _, res := range results {
		text := res.Name
		if detail := res.Detail; detail != "" {
			text = r.UI.Join(text, detail)
		} else if s := res.testSummary(); s != "" {
			text = r.UI.Join(text, s)
		}
		r.UI.Verdict(res.Status, text, res.Duration)
	}

	var parts []string
	for _, p := range []struct {
		count int
		label string
	}{{passed, "passed"}, {failed, "failed"}, {dry, "dry-run"}, {other, "other"}} {
		if p.count > 0 {
			parts = append(parts, fmt.Sprintf("%d %s", p.count, p.label))
		}
	}

	r.UI.Info("")
	r.UI.Total(strings.Join(parts, ", "), total)
	r.UI.Info("      artifacts: %s", r.Paths.Rel(r.Opts.ArtifactsDir))

	return failed > 0
}
