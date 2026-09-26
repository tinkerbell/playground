# How to add or modify an e2e test

_Task-oriented recipes. For why the harness is shaped this way, read the
[explanation](./explanation-e2e.md)._

All commands are run from `capt/`.

## Run what already exists

```bash
./e2e/run.sh list                              # every combination and its axes
./e2e/run.sh colocated-ipv4-netboot-direct     # run one
./e2e/run.sh run --all                         # run all sixteen, in turn
./e2e/run.sh config colocated-ipv6-isoboot-direct   # preview the config.yaml only
```

A full combination takes roughly 7–15 minutes and needs KVM, libvirt and docker.
Output lands in `e2e/artifacts/<combo>/`.

## Add a test that runs everywhere

Tests live in [e2e/test/provisioning_test.go](../e2e/test/provisioning_test.go).
Add an `It` to the existing `Describe`, with a timeout:

```go
It("has a reachable workload API server", func(ctx SpecContext) {
    WaitForAPIServerReady(ctx, workloadKubeconfig, nodeTimeout, 10*time.Second)
}, SpecTimeout(15*time.Minute))
```

Three rules, each of which has bitten:

1. **Assert on a condition, not a moment.** Use a `WaitFor...` helper with a
   timeout. Provisioning takes minutes and varies by combination.
2. **Take paths from the flags**, never from a working directory or an
   environment default: `mgmtKubeconfig`, `workloadKubeconfig`, `tinkKubeconfig`,
   `stateFile`, `namespace`, `artifactsDir`. The runner passes all of them.
3. **The suite is `Ordered`.** Tests run in file order and later ones assume
   earlier ones succeeded — there is no cluster to check pods on until CNI is
   deployed. Put yours where its preconditions hold.

If the assertion needs a new helper, add it to
[e2e/test/helpers.go](../e2e/test/helpers.go) (actions on the cluster) or
[e2e/test/health.go](../e2e/test/health.go) (waiting and inspection).

## Add a test that only applies to one axis

Label it with the axis value, and the combination filters do the rest:

```go
It("reaches the registry through NAT64", Label("ipv6"), func(ctx SpecContext) {
    ...
}, SpecTimeout(5*time.Minute))
```

The vocabulary is exactly the combination name's segments: `ipv4`, `ipv6`,
`netboot`, `isoboot`, `direct`, `mirror`, `colocated`, `external`. Every
`-ipv4-` combination filters with `!ipv4`, so the test above is skipped there
with no further changes.

Check the filter a combination will use:

```bash
cue eval ./e2e/cue -e 'comboLabels["colocated-ipv6-netboot-direct"]'
```

## Add a combination

Only if you are adding a value to an axis — the sixteen existing combinations
already cover the current four. In [e2e/cue/matrix.cue](../e2e/cue/matrix.cue),
add an entry to `_overrides`:

```cue
"colocated-ipv4-netboot-mirror": {
    bootMode:           "netboot"
    externalTinkerbell: false
    registryMirror:     _mirrorConfig
}
```

`comboNames`, `comboLabels`, `comboInfo` and `mirrorCombos` are derived, so
nothing else needs editing. Then:

```bash
./e2e/run.sh list                     # it should appear
./e2e/run.sh config <new-combo>       # and render a sane config.yaml
```

To offer it in CI, add the name to both the `combination` dropdown and the
`all=` list in [.github/workflows/e2e.yaml](../../.github/workflows/e2e.yaml).
Leave `-mirror` combinations out: hosted runners have no pull-through cache.

## Change a default for every combination

Shared settings live in [e2e/cue/base.cue](../e2e/cue/base.cue) — counts,
versions, the chart location, VM sizing. Changing `versions.kube` there changes
it for all sixteen.

Do not add a chart version pin. The runner resolves what `latest` points at and
passes it in; a default in CUE would go stale behind it. Use `--chart-version`
for a one-off.

## Test against your own Tinkerbell build

```bash
./e2e/run.sh run --tinkerbell-ref my-branch colocated-ipv4-netboot-direct
./e2e/run.sh run --tinkerbell-repo ~/repos/tinkerbell colocated-ipv4-isoboot-direct
```

Either flag alone is enough: the repo defaults to upstream, the ref to the
repo's default branch. The build produces the chart and both images, so
`--chart-version` is rejected alongside these.

## Debug a failure

Everything is in `e2e/artifacts/<combo>/`:

| File                   | What it tells you                                  |
| ---------------------- | -------------------------------------------------- |
| `create.log`           | Whether the playground ever came up                |
| `ginkgo.log`           | Full test output, including `By` steps             |
| `report.json`          | Machine-readable results, per test                 |
| `config.yaml`          | Exactly what was asked for, chart version included |
| `state.yaml`           | Addresses, MACs, BMC ports the run actually used   |
| `output/`              | kubeconfigs, SSH key, rendered CRs                 |
| dumps from `AfterEach` | Cluster state, workflows, hardware, vBMC logs      |

To keep the playground alive and poke at it:

```bash
./e2e/run.sh run --no-teardown colocated-ipv4-netboot-direct
export KUBECONFIG=$PWD/e2e/artifacts/colocated-ipv4-netboot-direct/output/*/kind.kubeconfig
kubectl get hardware,workflow -A
```

Clean up afterwards — those resources persist:

```bash
./e2e/run.sh clean colocated-ipv4-netboot-direct
./e2e/run.sh clean --all
```

To see what would run without building anything:

```bash
./e2e/run.sh run --dry-run colocated-ipv4-netboot-direct
```

## Change how a run is reported

The per-run terminal output is in
[e2e/internal/runner/ui.go](../e2e/internal/runner/ui.go) and
[report.go](../e2e/internal/runner/report.go). The CI job summary is
[.github/scripts/e2e-summary.sh](../../.github/scripts/e2e-summary.sh), which
reads each artifact's `report.json`, `result.tsv` and `state.yaml`.

Test it without a CI run by pointing it at a directory of artifacts:

```bash
COMBINATIONS='["colocated-ipv4-netboot-direct"]' \
  GITHUB_REF_NAME=main GITHUB_SERVER_URL=https://github.com \
  GITHUB_REPOSITORY=tinkerbell/playground GITHUB_SHA=$(git rev-parse HEAD) \
  ../.github/scripts/e2e-summary.sh e2e/artifacts
```

It expects directories named `e2e-<combo>/`, as `download-artifact` lays them
out, so rename or symlink accordingly.

## Before you push

```bash
cd e2e && go test ./... && go vet ./...   # runner unit tests
cd .. && cue vet ./e2e/cue -c -t chartVersion=v0.0.0 -t mirrorHost=x
./.github/workflows/ci-non-go.sh          # prettier, shfmt (from the repo root)
```

Then run at least one combination end to end. The unit tests cover the runner,
not the playground.
