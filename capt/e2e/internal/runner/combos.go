package runner

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const cuePackage = "./e2e/cue"

// ComboNames lists every combo defined by the CUE matrix.
func (r *Runner) ComboNames() ([]string, error) {
	return r.cueStrings("comboNames")
}

// MirrorComboNames lists combos whose config cannot be rendered without a
// registry mirror host.
func (r *Runner) MirrorComboNames() ([]string, error) {
	return r.cueStrings("mirrorCombos")
}

// ComboInfo is what a combo exercises, as shown by the list command.
type ComboInfo struct {
	Combo      string `json:"combo,omitempty"`
	Tinkerbell string `json:"tinkerbell"`
	Family     string `json:"family"`
	Boot       string `json:"boot"`
	Registry   string `json:"registry"`
}

// ComboInfos returns the axis values for every combo.
func (r *Runner) ComboInfos() (map[string]ComboInfo, error) {
	out, err := capture(r.Paths.Capt, "cue", "eval", cuePackage, "-e", "comboInfo", "--out", "json")
	if err != nil {
		return nil, err
	}
	var infos map[string]ComboInfo
	if err := json.Unmarshal([]byte(out), &infos); err != nil {
		return nil, fmt.Errorf("parsing comboInfo: %w", err)
	}
	return infos, nil
}

// ComboLabels returns the Ginkgo label filter for a combo, which excludes the
// axis values the combo does not exercise.
func (r *Runner) ComboLabels(combo string) (string, error) {
	out, err := capture(r.Paths.Capt, "cue", "export", cuePackage,
		"-e", fmt.Sprintf("comboLabels[%q]", combo), "--out", "text")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func (r *Runner) cueStrings(expr string) ([]string, error) {
	out, err := capture(r.Paths.Capt, "cue", "eval", cuePackage, "-e", expr, "--out", "json")
	if err != nil {
		return nil, err
	}
	var names []string
	if err := json.Unmarshal([]byte(out), &names); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", expr, err)
	}
	return names, nil
}

// RenderComboConfig writes a combo's config.yaml to dest. On failure the CUE
// error is left in dest for the caller to show.
func (r *Runner) RenderComboConfig(combo, dest string) error {
	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()

	return r.renderCombo(combo, outputDirFor(dest), f)
}

// renderCombo exports one combo's config, with the same tags a real run uses,
// so what is shown is what would be written.
func (r *Runner) renderCombo(combo, outputDir string, w io.Writer) error {
	chart, err := r.chartVersion()
	if err != nil {
		return err
	}

	args := []string{"export", cuePackage, "-e", fmt.Sprintf("combos[%q]", combo),
		"-t", fmt.Sprintf("spares=%d", r.Opts.Spares),
		"-t", "outputDir=" + outputDir}
	if r.Opts.MirrorHost != "" {
		args = append(args, "-t", "mirrorHost="+r.Opts.MirrorHost)
	}
	if chart != "" {
		args = append(args, "-t", "chartVersion="+chart)
	}
	if r.Opts.TinkerbellRepo != "" {
		args = append(args, "-t", "sourceRepo="+r.Opts.TinkerbellRepo)
	}
	if r.Opts.TinkerbellRef != "" {
		args = append(args, "-t", "sourceRef="+r.Opts.TinkerbellRef)
	}
	args = append(args, "--out", "yaml")

	return run(r.Paths.Capt, w, "cue", args...)
}

// CopySuppliedConfig installs a user-supplied config, applying the overrides
// the runner owns.
func (r *Runner) CopySuppliedConfig(src, dest string) error {
	return r.copySuppliedConfigTo(src, dest, outputDirFor(dest))
}

func (r *Runner) copySuppliedConfigTo(src, dest, outputDir string) error {
	if err := copyFile(src, dest); err != nil {
		return err
	}

	chart, err := r.chartVersion()
	if err != nil {
		return err
	}

	// yq edits in place, preserving the rest of the document as written.
	edits := []string{fmt.Sprintf(".outputDir = %q", outputDir)}
	if chart != "" {
		edits = append(edits, fmt.Sprintf(".versions.chart = %q", chart))
	}
	// Written even when empty so the block exists and the playground's own
	// default repo applies; a `source` key with no repo is what signals a build.
	if r.SourceRequested() {
		edits = append(edits,
			fmt.Sprintf(".source.repo = %q", r.Opts.TinkerbellRepo),
			fmt.Sprintf(".source.ref = %q", r.Opts.TinkerbellRef))
	}
	return run(r.Paths.Capt, os.Stderr, "yq", "-i", strings.Join(edits, " | "), dest)
}

// PrintComboConfig writes the config.yaml each selected combo would run with.
// Output is valid YAML so it can be piped straight to a file or to diff.
func (r *Runner) PrintComboConfig() error {
	for i, combo := range r.Opts.Combos {
		if len(r.Opts.Combos) > 1 {
			if i > 0 {
				fmt.Fprintln(r.UI.Out)
			}
			fmt.Fprintf(r.UI.Out, "---\n# %s\n", combo)
		}
		if err := r.writeComboConfig(combo, r.UI.Out); err != nil {
			return fmt.Errorf("%s: %w", combo, err)
		}
	}
	return nil
}

// writeComboConfig produces a combo's config without touching the artifact
// directory, so showing a config never looks like the start of a run.
func (r *Runner) writeComboConfig(combo string, w io.Writer) error {
	dest := filepath.Join(r.Opts.ArtifactsDir, combo, "config.yaml")

	if r.Opts.ConfigFile == "" {
		return r.renderCombo(combo, outputDirFor(dest), w)
	}

	tmp, err := os.MkdirTemp("", "e2e-config")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	// Render into the temp dir but keep dest's outputDir, so the preview shows
	// the paths the real run would use.
	staged := filepath.Join(tmp, "config.yaml")
	if err := r.copySuppliedConfigTo(r.Opts.ConfigFile, staged, outputDirFor(dest)); err != nil {
		return err
	}
	data, err := os.ReadFile(staged)
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// outputDirFor keeps the playground's generated files (kubeconfigs, certs.d,
// VM disks) beside the config that produced them.
func outputDirFor(configPath string) string {
	return filepath.Join(filepath.Dir(configPath), "output")
}
