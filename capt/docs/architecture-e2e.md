# Architecture: the e2e harness

C4 diagrams for the end-to-end test harness in [capt/e2e](../e2e). For what the
tests actually do and why they are shaped this way, read the
[explanation](./explanation-e2e.md); to change them, follow the
[how-to](./how-to-e2e.md).

The harness exists to answer one question repeatedly: **does a playground of
shape X still provision a working cluster?** Everything below follows from
needing that answer for sixteen shapes of X, on a laptop and on a CI runner,
with enough evidence left behind to debug a failure hours later.

## Level 1: system context

```mermaid
C4Context
    title e2e harness — system context

    Person(dev, "Developer", "Runs one combination locally")
    System_Ext(actions, "GitHub Actions", "Runs the matrix on dispatch, one combination per runner")

    System(e2e, "e2e harness", "Renders a config, builds a playground, runs the suite against it, tears it down, and reports")

    System(playground, "CAPT playground", "The system under test")
    System_Ext(ghcr, "ghcr.io", "Resolves which Tinkerbell chart 'latest' means")

    Rel(dev, e2e, "./e2e/run.sh <combo>")
    Rel(actions, e2e, "./e2e/run.sh <combo> --plain")
    Rel(e2e, playground, "task create-playground, then task delete-playground")
    Rel(e2e, ghcr, "Resolves the chart version to install")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

## Level 2: containers

```mermaid
C4Container
    title e2e harness — containers

    Person(dev, "Developer")

    System_Boundary(harness, "capt/e2e") {
        Container(runsh, "run.sh", "bash", "Builds and execs the runner, so there is no binary to keep up to date")
        Container(runner, "e2e runner", "Go", "Owns the lifecycle: render, create, test, tear down, report")
        Container(cue, "Combination matrix", "CUE", "Sixteen named configurations, built from four binary axes")
        Container(suite, "Ginkgo suite", "Go", "The assertions, run against a playground that already exists")
        ContainerDb(artifacts, "artifacts/<combo>/", "Files", "config.yaml, state.yaml, create.log, ginkgo.log, report.json, output/")
    }

    System(playground, "CAPT playground", "task create-playground")
    Container(summary, "e2e-summary.sh", "bash + jq", "Turns the artifacts of every combination into one job summary")

    Rel(dev, runsh, "Runs")
    Rel(runsh, runner, "go run ./cmd/e2e")
    Rel(runner, cue, "cue export combos[<name>]")
    Rel(cue, artifacts, "config.yaml")
    Rel(runner, playground, "task create-playground CONFIG_FILE=... STATE_FILE=...")
    Rel(runner, suite, "ginkgo --label-filter=... -- -e2e.<flags>")
    Rel(suite, playground, "Asserts against the live clusters")
    Rel(suite, artifacts, "report.json, junit.xml, dumps on failure")
    Rel(summary, artifacts, "Reads")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

The playground never learns it is under test. The runner writes a `config.yaml`
into the combination's artifact directory and points `task` at it with
`CONFIG_FILE` and `STATE_FILE`, so a combination cannot disturb the checked-in
`capt/config.yaml` or another combination's state.

## Level 3: components of the runner

```mermaid
C4Component
    title e2e runner — components

    Container_Boundary(runner, "e2e runner") {
        Component(cli, "cli.go", "Flags and validation", "Parses flags and environment, rejects impossible combinations early")
        Component(matrix, "matrix.go", "Orchestration", "Runs each combination in turn and collects results")
        Component(combos, "combos.go", "CUE bridge", "Renders a combination to config.yaml, lists names and labels")
        Component(chart, "chart.go", "Version resolution", "Resolves what the chart 'latest' points at, anonymously")
        Component(pg, "playground.go", "Lifecycle", "task create and delete, and whether one is still live")
        Component(tests, "tests.go", "Ginkgo driver", "Installs the pinned Ginkgo, builds its arguments, reads the report")
        Component(report, "report.go", "Verdicts", "Per-combination results and the final summary")
        Component(ui, "ui.go", "Terminal UI", "Steps, live log pane, colour — or plain output for CI")
    }

    Container(cuepkg, "CUE matrix")
    Container(taskfile, "task")
    Container(ginkgo, "ginkgo")
    System_Ext(ghcr, "ghcr.io")

    Rel(cli, matrix, "Options")
    Rel(matrix, combos, "Render")
    Rel(combos, cuepkg, "cue export")
    Rel(combos, chart, "Which chart version?")
    Rel(chart, ghcr, "Tag and digest lookups")
    Rel(matrix, pg, "Create, tear down")
    Rel(pg, taskfile, "task create-playground")
    Rel(matrix, tests, "Run the suite")
    Rel(tests, ginkgo, "Executes")
    Rel(matrix, report, "Results")
    Rel(matrix, ui, "Progress")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## The matrix

Four binary axes, named in a fixed order, so a combination name says exactly
what it exercises:

```
<topology>-<ipFamily>-<bootMode>-<registry>

colocated | external    Tinkerbell in the management cluster, or its own
ipv4      | ipv6        dual-stack bridge, or IPv6-only machines
netboot   | isoboot     iPXE, or virtual media
direct    | mirror      straight to upstream, or a pull-through cache
```

Sixteen combinations are defined in
[e2e/cue/matrix.cue](../e2e/cue/matrix.cue); the eight `-direct` ones are
offered in CI, because `-mirror` needs a reachable pull-through cache that a
hosted runner does not have.

## One run, end to end

```mermaid
sequenceDiagram
    participant R as Runner
    participant C as CUE
    participant T as task
    participant G as Ginkgo
    participant A as artifacts/

    R->>R: Resolve the chart version once, reuse for every combination
    loop each combination
        R->>C: cue export combos["<name>"]
        C-->>A: config.yaml
        R->>T: task create-playground
        T-->>A: create.log, state.yaml, output/
        R->>C: cue eval comboLabels["<name>"]
        R->>G: ginkgo --label-filter=<filter>
        G-->>A: ginkgo.log, report.json, junit.xml
        R->>R: Read report.json for the verdict
        R->>T: task delete-playground
    end
    R->>R: Print the summary table
```

In CI each iteration of that loop is a separate runner, and a final `summary`
job reads every artifact to build one job summary
([.github/scripts/e2e-summary.sh](../../.github/scripts/e2e-summary.sh)).

## Why the suite is given no defaults

Every path the Ginkgo suite needs arrives as an explicit flag — `-e2e.config`,
`-e2e.artifacts`, `-e2e.mgmt-kubeconfig`, `-e2e.workload-kubeconfig`,
`-e2e.tink-kubeconfig`, `-e2e.namespace`, `-e2e.state-file`, `-e2e.cni-script`
([e2e/internal/runner/tests.go](../e2e/internal/runner/tests.go)). The suite has
no working directory it could derive one from and no fallback to the checked-in
playground. Running several combinations in sequence would otherwise risk a
suite asserting against the previous playground's kubeconfig, which fails in a
way that looks like a product bug rather than a harness bug.

`-e2e.mgmt-kubeconfig` doubles as the guard: without it the suite skips rather
than fails, so `go test ./...` over the repository stays green.
