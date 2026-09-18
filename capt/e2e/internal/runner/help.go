package runner

import (
	"fmt"
	"io"
	"strings"
)

const tagline = "e2e — run the CAPT playground test matrix"

// Help texts are plain text so they read as they render. %[1]s is the program
// name; %[2]s, where present, is filled in by PrintHelp. Two conventions carry
// the visual hierarchy: the first line is the title, and an unindented line
// ending in a colon is a section heading.

const rootHelp = tagline + `

Usage:
  %[1]s <command> [flags]
  %[1]s <combo>... [flags]      shorthand for '%[1]s run'

Commands:
%[2]s

Flags:
  -v, --verbose      label filters, full paths, longer log excerpts
  -q, --quiet        only the final verdict
      --plain        no colour, glyphs or progress (automatic when piped)
      --no-color     no colour, keep glyphs and progress
      --version      print the runner version
  -h, --help         show this help

Examples:
  %[1]s list
  %[1]s colocated-ipv4-netboot-direct
  %[1]s run --mirror-host reg.example.com --all

Run '%[1]s help <command>' for a command's flags and what it does.
`

const globalFlagsNote = `
Global flags: -v/--verbose, -q/--quiet, --plain, --no-color.
Every flag is also an environment variable, prefixed E2E_ and upper-cased:
--mirror-host is E2E_MIRROR_HOST. Flags take precedence over the environment.
`

const runHelp = `Run the CAPT playground test matrix.

Usage:
  %[1]s run <combo>... [flags]
  %[1]s run --all [flags]
  %[1]s <combo>... [flags]      'run' may be omitted

A combo selects both the configuration to build and the tests that apply to
it. Run '%[1]s list' to see them. Each combo is built, tested and
torn down in turn; full output goes to the artifacts directory either way.

Configuration:
      --mirror-host HOST   registry mirror hostname, required by *-mirror
      --config FILE        use FILE instead of rendering the combo's config
      --chart-version VER  chart version to install (default: latest)
      --tinkerbell-repo R  build Tinkerbell from this git repo or checkout
      --tinkerbell-ref REF build Tinkerbell from this branch, tag or commit
      --spares N           spare VMs to create (default 0)

Execution:
  -a, --all                run every combo
  -n, --dry-run            print what would run, touch nothing
      --no-teardown        leave the playground running when tests finish
      --labels FILTER      Ginkgo label filter (default: derived from combo)
      --artifacts DIR      logs and reports (default e2e/artifacts)
      --log-lines N        live output lines under the step (default 5)

Examples:
  %[1]s colocated-ipv4-netboot-direct
  %[1]s run --mirror-host reg.example.com colocated-ipv6-netboot-mirror
  %[1]s run --no-teardown --dry-run colocated-ipv4-isoboot-direct
  %[1]s run --config ./my-config.yaml colocated-ipv6-netboot-mirror
  %[1]s run --tinkerbell-ref main colocated-ipv4-netboot-direct
  %[1]s run --tinkerbell-repo ~/tinkerbell colocated-ipv4-isoboot-direct
  %[1]s run --mirror-host reg.example.com --all
` + globalFlagsNote

const listHelp = `Show the combos and what each one exercises.

Usage:
  %[1]s list [flags]

One row per combo, with the value it takes on each axis of the matrix. Any
name shown here can be passed to '%[1]s run' or '%[1]s config'.

Flags:
      --json               machine-readable output

Examples:
  %[1]s list
  %[1]s list --json | jq -r '.[].combo'
` + globalFlagsNote

const configHelp = `Print the config.yaml a combo would run with.

Usage:
  %[1]s config <combo>... [flags]

Output is valid YAML, so it can be piped to a file or to diff. Nothing is
built and the playground's own config.yaml is left alone. More than one combo
produces a multi-document stream, each preceded by its name.

Flags:
      --mirror-host HOST   registry mirror hostname, required by *-mirror
      --config FILE        preview FILE with the runner's overrides applied
      --chart-version VER  chart version to install (default: latest)
      --tinkerbell-repo R  build Tinkerbell from this repo or local checkout
      --tinkerbell-ref REF build Tinkerbell from this branch, tag or commit
      --spares N           spare VMs to create (default 0)
      --artifacts DIR      artifacts directory the paths assume

Examples:
  %[1]s config colocated-ipv4-netboot-direct
  %[1]s config colocated-ipv4-netboot-direct > my-config.yaml
  %[1]s config colocated-ipv4-netboot-direct | diff - config.yaml
` + globalFlagsNote

const cleanHelp = `Delete a playground a run left behind.

Usage:
  %[1]s clean [flags]
  %[1]s clean <combo>... [flags]
  %[1]s clean --all [flags]

Deletes the VMs, kind clusters, docker network and BMC container a run leaves
behind when it fails or is interrupted. Each combo is torn down from the
state file in its own artifact directory, which records what that run built,
so the right resources go even after other combos have run since. With no
combo named, capt/.state is used instead — that is the playground an
interactive 'task create-playground' builds.

A combo with no state file never recorded anything and is skipped. Doing this
with nothing running is not an error.

Flags:
  -a, --all                clean every combo with a state file
  -n, --dry-run            print what would be deleted, touch nothing
      --artifacts DIR      where the combo artifacts live

Examples:
  %[1]s clean
  %[1]s clean colocated-ipv4-netboot-direct
  %[1]s clean --all --dry-run
` + globalFlagsNote

const versionHelp = `Print the runner version.

Usage:
  %[1]s version

Reports the VCS revision Go stamped into the binary, with -dirty appended when
the working tree had uncommitted changes at build time.
`

const helpHelp = `Show help for any command.

Usage:
  %[1]s help [command]

Examples:
  %[1]s help
  %[1]s help run
`

// PrintHelp writes the help for one command, or the root help when cmd is nil.
func (r *Runner) PrintHelp(w io.Writer, cmd *command) {
	text := rootHelp
	args := []any{r.Opts.Prog, commandList()}
	if cmd != nil {
		text, args = cmd.help, []any{r.Opts.Prog}
	}
	fmt.Fprint(w, renderHelp(fmt.Sprintf(text, args...)))
}

// commandList is the root help's command table, built from the command table
// itself so the two cannot drift apart.
func commandList() string {
	width := 0
	for _, c := range commands {
		width = max(width, len(c.name))
	}

	var b strings.Builder
	for i, c := range commands {
		if i > 0 {
			b.WriteString("\n")
		}
		fmt.Fprintf(&b, "  %-*s   %s", width, c.name, c.summary)
	}
	return b.String()
}

// renderHelp adds the emphasis the templates deliberately leave out: the first
// line is the title, and an unindented line ending in a colon is a heading.
func renderHelp(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		switch {
		case line == "" || strings.HasPrefix(line, " "):
		case i == 0, strings.HasSuffix(line, ":"):
			lines[i] = styleBold.Render(line)
		}
	}
	return strings.Join(lines, "\n")
}
