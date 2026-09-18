// Package runner orchestrates the CAPT playground e2e matrix: it renders a
// config for each combo, creates the playground, runs the Ginkgo suite against
// it, tears it down, and reports the results.
package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Paths holds the directory layout the runner works within.
type Paths struct {
	Capt      string // capt/
	E2E       string // capt/e2e/
	Bin       string // capt/bin/
	Config    string // capt/config.yaml, the interactive playground's config
	State     string // capt/.state, the interactive playground's state
	CNIScript string // capt/scripts/deploy_cni.sh, shared with the playground
	Artifacts string // capt/e2e/artifacts/ unless overridden
}

// NewPaths derives the layout from the location of the running binary's source
// tree root, which the entrypoint passes in as the capt directory.
func NewPaths(captDir string) Paths {
	return Paths{
		Capt:      captDir,
		E2E:       filepath.Join(captDir, "e2e"),
		Bin:       filepath.Join(captDir, "bin"),
		Config:    filepath.Join(captDir, "config.yaml"),
		State:     filepath.Join(captDir, ".state"),
		CNIScript: filepath.Join(captDir, "scripts", "deploy_cni.sh"),
		Artifacts: filepath.Join(captDir, "e2e", "artifacts"),
	}
}

// Rel renders a path relative to capt/, leaving paths outside it absolute.
func (p Paths) Rel(path string) string {
	rel, err := filepath.Rel(p.Capt, path)
	if err != nil || strings.HasPrefix(rel, "..") {
		return path
	}
	return rel
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("reading %s: %w", src, err)
	}
	if err := os.WriteFile(dst, data, 0o600); err != nil {
		return fmt.Errorf("writing %s: %w", dst, err)
	}
	return nil
}
