// Command e2e orchestrates the CAPT playground test matrix.
//
// Loops over user-selected combos, generates config.yaml via CUE,
// creates/validates/deletes the playground for each combo, and prints a summary.
//
// A combo names both the configuration to run and the set of tests that apply to
// it: its Ginkgo label filter excludes the axis values it does not exercise (see
// comboLabels in e2e/cue/matrix.cue). Passing --config replaces only the
// generated config.yaml; the combo still selects the tests.
//
// Run 'e2e help' for the commands, and 'e2e help <command>' for their flags.
package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/tinkerbell/playground/e2e/internal/runner"
)

func main() {
	os.Exit(run())
}

func run() int {
	ui := runner.NewUI()

	captDir, err := captDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}

	prog := os.Getenv("E2E_PROG")
	if prog == "" {
		prog = "e2e"
	}

	r := runner.New(runner.Options{Prog: prog}, runner.NewPaths(captDir), ui)

	if err := r.ParseArgs(os.Args[1:]); err != nil {
		// Help was requested and has already been printed.
		if errors.Is(err, runner.ErrHelpRequested) {
			return 0
		}
		fmt.Fprintf(os.Stderr, "\nError: %v\n", err)
		return 1
	}

	return r.Execute()
}

// captDir resolves the playground directory. E2E_CAPT_DIR is set by the run.sh
// entrypoint, which knows its own location; otherwise the working directory is
// searched upwards for the Taskfile that marks it.
func captDir() (string, error) {
	if dir := os.Getenv("E2E_CAPT_DIR"); dir != "" {
		return filepath.Abs(dir)
	}

	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "Taskfile.yaml")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", errors.New("not inside the capt playground directory")
		}
		dir = parent
	}
}
