# How the e2e tests work

_Explanation. For the shape of the harness see the
[architecture](./architecture-e2e.md); to change something, follow the
[how-to](./how-to-e2e.md)._

The playground is a lot of moving parts held together by ordering: docker
networks, two kinds of kind cluster, libvirt domains, a shared BMC emulator, a
Helm chart, and a provisioning flow that only works if every one of them is
right. The e2e suite exists because the only honest way to know that still holds
is to build one and watch a machine come up.

## What is under test, and what is not

The tests assert on **outcomes of the whole playground**, not on the behaviour
of any component in it. There are no unit tests of Smee here and no mocks of
libvirt. A run either ends with a workload cluster whose nodes are `Ready`, or
it does not.

This is deliberate, and it is the reason the suite is small. Seven tests cover
the entire provisioning path:

| Test                                          | What it proves                             |
| --------------------------------------------- | ------------------------------------------ |
| completes all workflows successfully          | Boot, BMC, agent and actions all worked    |
| has a reachable workload API server           | kubeadm ran and the VIP is held            |
| deploys CNI to the workload cluster           | The cluster accepts workloads              |
| has all nodes Ready after CNI deployment      | Every machine joined, not just the first   |
| reports all CAPI and CAPT objects ready       | Cluster API's own view agrees              |
| has all workload cluster pods healthy         | Nothing is crash-looping behind the scenes |
| has every required workload component running | The specific components we depend on exist |

Anything more granular belongs in the Tinkerbell repository, where the component
lives. Anything less would pass while the playground was broken.

## Why a matrix, and why these four axes

The playground has configuration that changes the _shape_ of the system rather
than its parameters. Running Tinkerbell in its own cluster is a different
topology. IPv6-only machines are a different network stack. ISO boot is a
different path through firmware. A pull-through mirror rewrites every image
reference in the system.

Each of those has broken independently, and none of them is exercised by the
others. So they are the axes:

```
<topology>-<ipFamily>-<bootMode>-<registry>
```

Every axis appears in every combination name, in the same order, so a name alone
says what it exercises — and the sixteen combinations are written out by hand in
[e2e/cue/matrix.cue](../e2e/cue/matrix.cue) rather than generated from the axes.
Generating them would be shorter. Writing them out means adding one is a
deliberate act, and a combination that needs a caveat has somewhere to carry it.

## Labels and the filter

A combination is two things: a configuration to build, and a set of tests that
apply to it. The second comes from Ginkgo labels.

The rule is inverted from what you might expect. Tests are **not** labelled with
where they should run; they are labelled only when they are specific, and the
combination's filter **excludes** the axis values it does not exercise:

```
provisioning && !ipv4 && !isoboot && !mirror && !external
```

That filter is `colocated-ipv6-netboot-direct`. An unlabelled test runs
everywhere. A test labelled `Label("provisioning", "ipv6")` is excluded from
every `-ipv4-` combination by `!ipv4`, without anyone maintaining a list.

Today only `provisioning` and `health` are actually used, because nothing yet
needs to be axis-specific. The vocabulary — `ipv4`, `ipv6`, `netboot`,
`isoboot`, `direct`, `mirror`, `colocated`, `external` — is the combination
name's own segments, so there is nothing new to learn when you need one.

## Why the runner is a program

Driving this from a shell script was the obvious first move and it did not
survive contact with the requirements. The runner
([e2e/internal/runner](../e2e/internal/runner)) exists because of four things
that are awkward in bash:

- **Isolation.** Each combination gets its own artifact directory, and the
  config and state files are passed to `task` explicitly. Nothing writes to the
  checked-in `capt/config.yaml`, so a run cannot leave your own playground
  configuration modified.
- **Teardown that actually happens.** A playground that survives a failed run
  holds a docker network, libvirt domains and BMC port registrations. The runner
  tears down after every combination whatever the verdict, and refuses to reuse
  an artifact directory whose playground is still live.
- **Evidence.** On failure the suite dumps cluster state, workflows, hardware
  and virtual BMC logs into the artifact directory before teardown destroys the
  thing being described.
- **A verdict.** `report.json` is read back so the runner can exit non-zero with
  a summary, rather than leaving a human to scroll.

## Configuration comes from CUE, once

The combination matrix imports the playground's own `#ConfigInput` schema
directly from [cue/state](../cue/state). There is no second copy of the schema
to drift, and a combination that sets a key the playground does not have fails
at `cue export` rather than three tasks into a create.

The chart version is resolved rather than pinned. Each push to Tinkerbell's main
publishes three artifacts under one version — the `tinkerbell` image, the
`tink-agent` image and the Helm chart — and moves `latest` on the two images.
The chart carries no `latest`, so the runner reads the version off the image
that does, then confirms the chart exists under it
([e2e/internal/runner/chart.go](../e2e/internal/runner/chart.go)). A pinned
default in CUE would silently rot; `--chart-version` still pins when you need to
reproduce an old run.

## Why tests wait rather than poll once

Every assertion is a `WaitFor...` with a timeout measured in minutes, because
provisioning real firmware is slow and variable: DHCP retries, a TFTP transfer,
an OS image streamed to disk, a kexec, then kubeadm. A test that checked once
would be a flake generator.

The timeouts are deliberately generous and the intervals short, so a passing run
is as fast as the system allows while a broken one still fails with a useful
message instead of a deadline exceeded on the first probe.

## Node counts come from the playground, not the suite

The suite's own config ([e2e/test/config/e2e.yaml](../e2e/test/config/e2e.yaml))
carries `CONTROL_PLANE_MACHINE_COUNT` and `WORKER_MACHINE_COUNT`, but they are
only a fallback. The counts are read from the state file of the playground that
was actually built, so `--config` with a different topology is asserted
correctly rather than against a hard-coded 1+1.

## What CI adds

Nothing about the tests. The workflow
([.github/workflows/e2e.yaml](../../.github/workflows/e2e.yaml)) runs one
combination per runner so a failure does not cancel the rest, then a summary job
turns every artifact into one table. The same `./e2e/run.sh` runs locally and
there; `--plain` is the only concession, and it only turns off colour and the
live log pane.

The `-mirror` combinations are excluded in CI because a hosted runner has no
pull-through cache to point at. That is a property of the runner, not of the
combinations, which is why they remain defined and runnable locally.
