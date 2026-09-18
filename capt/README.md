# Cluster API Provider Tinkerbell (CAPT) Playground

The Cluster API Provider Tinkerbell (CAPT) is a Kubernetes Cluster API provider that uses Tinkerbell to provision machines. You can find more information about CAPT [here](https://github.com/tinkerbell/cluster-api-provider-tinkerbell). The CAPT playground is an example deployment for use in learning and testing. It is not a production reference architecture.

## Getting Started

The CAPT playground is a tool that will create a local CAPT deployment and a single workload cluster. This includes creating and installing a Kubernetes cluster (KinD), the Tinkerbell stack, all CAPI and CAPT components, Virtual machines that will be used to create the workload cluster, and a Virtual BMC server to manage the VMs.

Start by reviewing and installing the [prerequisites](#prerequisites) and understanding and customizing the [configuration file](./config.yaml) as needed.

## Prerequisites

### Operating System

This playground has only been tested on Ubuntu 22.04 LTS. If you are using a virtual machine, ensure that you have hardware virtualization enabled.

### Binaries

The following must be installed system-wide:

- [Libvirtd](https://wiki.debian.org/KVM) >= libvirtd (libvirt) 8.0.0
- [Docker](https://docs.docker.com/engine/install/) >= 24.0.7
- [virt-install](https://virt-manager.org/) >= 4.0.0
- [task](https://taskfile.dev/installation/) >= 3.37.2
- `curl`, `tar`, `ssh-keygen` (from `openssh-client`)

By default, the following are downloaded automatically into `./bin/` by `task install-binaries` (invoked as part of `task create-playground`); pinned versions live near the top of [Taskfile.yaml](./Taskfile.yaml):

- `cue` — workload-manifest renderer
- `helm`
- `kind`
- `kubectl`
- `clusterctl`
- `yq`

To use the tools already available in `PATH` instead of downloading binaries
into `./bin/`, set `USE_PATH_BINARIES=true`. For example, with the
repository's Flox environment:

```bash
flox activate
USE_PATH_BINARIES=true task create-playground
```

Flox supplies both the system dependencies and the tools in the list above.
Docker and libvirtd must still be running as host services.

### Packages

The `ovmf` package is required for the libvirt VMs to run properly. OVMF is a port of Intel's tianocore firmware to the qemu virtual machine. Install it with the following command.

```bash
sudo apt install ovmf
```

### Hardware

- at least 60GB of free and very fast disk space (etcd is very disk I/O sensitive)
- at least 8GB of free RAM
- at least 4 CPU cores

## Usage

Start by looking at the [`config.yaml`](./config.yaml) file. This file contains the configuration for the playground. You can customize the playground by changing the values in this file. We recommend you start with the defaults to get familiar with the playground before customizing.

Create the CAPT playground:

```bash
# Run the creation process and follow the outputted next steps at the end of the process.
task create-playground
```

Delete the CAPT playground:

```bash
task delete-playground
```

### Running more than one playground

Several playgrounds can run on one host at the same time, and an e2e run can
run alongside a playground you are working in. Each is identified by a short
id derived from the path of its state file, and every name that has to be
unique on the host — the docker network, both KinD clusters, the libvirt
domains, the output directory — carries that id:

```bash
task create-playground                                  # id from capt/.state
task create-playground CONFIG_FILE=$PWD/other.yaml \
                       STATE_FILE=$PWD/other.state      # a different id
```

Nothing is registered or allocated: the id is a hash of the path, so it is
stable across re-runs and distinct between playgrounds without coordination.
The IPv6 subnet is the one exception, and docker arbitrates it — each
playground takes the lowest free `fd00:cafe:<n>::/64`, so a single playground
still gets `fd00:cafe::/64`.

To see what is running:

```bash
task instances
```

```
INSTANCE  NETWORK                   FAMILY  SUBNET6           CLUSTERS
11bdc88f  capt-playground-11bdc88f  ipv6    fd00:cafe:1::/64  2

Shared services:
  vbmc     up, serving 1 playground(s)
  nat64    not running
```

That listing is read back off labels on the docker networks, so it is right
even for a playground whose state file was lost.

**Shared services.** Some things are per host rather than per playground, and
are created on demand and removed with the last playground that needs them:

| Service                  | Shared because                          | Released when                                        |
| ------------------------ | --------------------------------------- | ---------------------------------------------------- |
| vBMC (`capt-vbmc`)       | it drives libvirt, which is per host    | no playground network is attached to it              |
| NAT64 (`nat64`)          | its TUN device and routes are host-wide | no IPv6 playground is left                           |
| libvirt pool (`default`) | one directory pool serves everyone      | no playground is left, and the playground created it |

Because one vBMC serves everyone, its credentials are fixed rather than
configurable, and BMC ports are assigned per playground from what is free.

The pool name is fixed for a different reason: the redfish emulator hardcodes
`default`, so the playground has to use libvirt's conventional pool. It only
removes a pool it created, which it recognises by the pool's target directory.

**Running concurrently by hand.** `task` keys its up-to-date checks by task
name, so two playgrounds sharing a fingerprint directory make each other
redo work. Point each at its own:

```bash
TASK_TEMP_DIR=$PWD/.task-other task create-playground \
  CONFIG_FILE=$PWD/other.yaml STATE_FILE=$PWD/other.state
```

The e2e runner does this per combo already. It is only wasted time, not
incorrect results, if you forget.

### External Tinkerbell mode

When `externalTinkerbell: true` is set in [`config.yaml`](./config.yaml), the
playground spins up a **second** KinD cluster (named `<clusterName>-tinkerbell`)
on the same `kind` docker network and deploys the Tinkerbell stack there
instead of into the management cluster. Hardware, Machine (BMC), and Workflow
CRs all live in this second cluster. CAPT, running in the management cluster,
talks to it via the `external-tinkerbell-kubeconfig` Secret in the
`capt-system` namespace (created by
[scripts/create_external_kubeconfig_secret.sh](./scripts/create_external_kubeconfig_secret.sh)
and labeled for `clusterctl move`).

Two kubeconfigs are produced under `output/`:

- `kind.kubeconfig` — the management cluster (CAPI/CAPT components live here)
- `tinkerbell-kind.kubeconfig` — the Tinkerbell cluster (Hardware/BMC/Workflows live here)

Caveat: after `task pivot`, the workload cluster receives the secret via
`clusterctl move`, but it must still be able to reach the Tinkerbell KinD
container's API server at the IP embedded in the kubeconfig — that IP is only
reachable from containers on the host's `kind` docker network, so cross-host
pivots are not supported in this mode.

### IPv6 mode

`ipFamily: ipv6` turns off DHCPv4 and drives Smee's DHCPv6 server in `derived`
mode, makes the KinD and workload clusters IPv6-only, and starts radvd on the
KinD bridge — Tinkerbell does not send Router Advertisements, and without one
systemd-networkd never starts its DHCPv6 client.

It also starts the NAT64/DNS64 translation layer
([tasks/Taskfile-nat64.yaml](./tasks/Taskfile-nat64.yaml)), which is what lets
IPv6-only machines reach the IPv4-only registries. A mirror is **not** required
for `ipv6`.

### Registry mirror

`registryMirror` routes every image this directory pulls through a
pull-through cache. It is off by default. When enabled:

- Host-side image strings (`chart.location`, `os.registry`, `virtualBMC.image`)
  are rewritten to `<host>/...` in `cue/state` by `cue/mirror/#rewrite`, so they
  reach helm/docker/crane already pointing at the mirror.
- Workflow action images are rewritten the same way, because the containerd
  inside CaptainOS that pulls them gets no `certs.d` tree and so cannot be
  redirected at runtime.
- KinD nodes get a rendered `certs.d` tree bind-mounted at
  `/etc/containerd/certs.d` via `extraMounts` in the cluster config.
- Workload nodes get the same drop-in via `KubeadmConfigSpec.files`
  (`cue/capi/resources.cue` + `cue/mirror/#cloudInitFiles`).

Everything else — kube-vip `ctr` pulls, all chart Pod images including
CaptainOS, kubeadm pulls — keeps its upstream hostname, and the containerd
mirror redirects it at pull time.

On `ipFamily: ipv6` the mirror does not need to be dual-stack: NAT64/DNS64 gives
the machines a synthesised AAAA and a translated path to it. That is transparent
to TLS, so the mirror must still present a publicly-trusted certificate for its
real hostname — there are no insecure knobs.

**A real pull-through mirror is required.** The rewritten references have no
fallback: if the mirror does not carry an image, the pull fails outright rather
than reaching upstream. (The containerd `certs.d` path does fall back, because
`hosts.toml` also names the upstream as `server`.) A push-only registry will 404
on everything it has not been given.

### Building Tinkerbell from source

Uncomment the `source` block in [`config.yaml`](./config.yaml) to build the
Tinkerbell image, the Tink Agent image and the Helm chart from a git repository
instead of using released artifacts. `versions.chart` and `chart.location` are
then ignored — the build supplies both.

```yaml
source:
  ref: "main"
  repo: "https://github.com/tinkerbell/tinkerbell"
```

`repo` takes a URL or a path and defaults to upstream Tinkerbell, so a block
naming only a `ref` means "upstream at that ref". `ref` takes a branch, tag or
commit, and defaults to the repository's default branch. How the two combine
matters:

| `repo`  | `ref`   | What happens                                                      |
| ------- | ------- | ----------------------------------------------------------------- |
| omitted | set     | Upstream Tinkerbell at that ref                                   |
| path    | omitted | Built **where it sits**, uncommitted changes included             |
| path    | set     | Cloned into the cache and built there; your worktree is untouched |
| URL     | either  | Cloned into the cache                                             |

The e2e runner takes the same two values as flags, so everything here applies
to it as well:

```bash
./e2e/run.sh run <combo> --tinkerbell-ref main
./e2e/run.sh run <combo> --tinkerbell-repo ~/repos/tinkerbell/tinkerbell
```

Because the build produces the chart, `--chart-version` has nothing left to
select and is rejected when combined with either flag.

`task instances` reports which checkout each running playground is built from,
and which checkouts nothing is using any more.

The cache is `~/.cache/capt-playground/src`. Building a working tree in place
reuses whatever is already compiled there and writes only to its gitignored
`out/`.

Images are tagged with the resolved commit, so a second run on the same commit
finds them already published and skips the build. A dirty working tree is the
exception and is always rebuilt: its contents can change without its version
changing.

The build itself is the repo's own `make` targets, so what runs here is what
runs in CI. The images go to a registry container shared by every playground on
the host, because the agent image has no other way onto a machine — CaptainOS
pulls it at boot with its own containerd, which cannot be handed a file. The
chart stays a local package, since the chart carrying the build's version as its
`appVersion` is what makes the image tags follow from it.

Two things deliberately outlive a playground: the image volume
(`capt-registry-data`), so a later run still finds its build published, and the
buildx builder (`capt-playground`), which holds the layer cache. Remove them by
hand if you want them gone.

## Next Steps

With the playground up and running and a workload cluster created, you can run through a few CAPI lifecycle operations.

### Move/pivot the Tinkerbell stack and CAPI/CAPT components to a workload cluster

To be written.

### Upgrade the management cluster

To be written.

### Upgrade the workload cluster

To be written.

### Scale out the workload cluster

To be written.

### Scale in the workload cluster

To be written.

## Running E2E Tests

The `e2e/run.sh` script orchestrates a matrix of provisioning combos
(topology × bootmode × mirror) defined in [`e2e/cue/matrix.cue`](e2e/cue/matrix.cue).
Each combo renders its own `config.yaml` from CUE, runs
`task create-playground`, executes Ginkgo specs against the resulting
clusters, then tears the playground down. The script is a thin wrapper that
builds and runs [`e2e/cmd/e2e`](e2e/cmd/e2e); the implementation lives in
[`e2e/internal/runner`](e2e/internal/runner).

A combo selects both the configuration and the tests that apply to it: its
Ginkgo label filter excludes the axis values it does not exercise (see
`comboLabels` in `e2e/cue/matrix.cue`).

Combo names carry one segment per axis, always in the same order:

```
<topology>-<ipFamily>-<bootMode>-<registry>
colocated|external  ipv4|ipv6  netboot|isoboot  direct|mirror
```

`colocated` runs Tinkerbell in the management cluster, `external` runs it
separately; `direct` pulls images from upstream registries, `mirror` pulls
them through a pull-through cache. The segments are also the Ginkgo label
vocabulary, so a name says exactly which specs run.

### Commands

| Command              | What it does                              |
| -------------------- | ----------------------------------------- |
| `run <combo>...`     | run the matrix for one or more combos     |
| `list`               | show the combos and what each exercises   |
| `config <combo>...`  | print the `config.yaml` a combo would use |
| `clean [<combo>...]` | delete a playground a run left behind     |
| `version`            | print the runner version                  |
| `help [command]`     | help for any command                      |

Each command has its own flags and its own help:

```bash
./e2e/run.sh help          # commands and global flags
./e2e/run.sh help run      # everything 'run' accepts
```

List available combos and what each one exercises:

```bash
./e2e/run.sh list
```

Run a single combo — `run` may be omitted, so a bare combo name is enough:

```bash
./e2e/run.sh colocated-ipv4-netboot-direct
```

Show the `config.yaml` a combo would run with, without running anything:

```bash
./e2e/run.sh config colocated-ipv4-netboot-direct
```

It renders exactly what the run would use, so `--mirror-host`, `--spares` and
`--chart-version` all apply, and the output is plain YAML — pipe it to a file
to use as the basis for `--config`, or to `diff` to compare two combos.

Run the whole matrix (combos that use the registry mirror require
`--mirror-host`, or `E2E_MIRROR_HOST`):

```bash
./e2e/run.sh run --mirror-host reg.example.com --all
```

Delete a playground left running by `--no-teardown`, or one a failed run left
behind:

```bash
./e2e/run.sh clean colocated-ipv4-netboot-direct   # one combo
./e2e/run.sh clean --all                           # every combo with a state file
./e2e/run.sh clean                                 # the playground capt/.state describes
```

### Each combo owns its config and state

A run never writes to `capt/config.yaml` or `capt/.state`. Every combo gets
its own pair under `e2e/artifacts/<combo>/`:

```
e2e/artifacts/<combo>/config.yaml   # rendered from the combo
e2e/artifacts/<combo>/state.yaml    # written by task generate-state
e2e/artifacts/<combo>/output/       # kubeconfigs, certs, rendered CRs
```

`run` empties `e2e/artifacts/<combo>/` before it starts, so the directory
always describes the most recent run and nothing else. Without that, files
only written on failure — `create-error.log` in particular — outlive the run
that produced them and misrepresent the next one. A combo whose `output/`
directory is still present was never torn down, and the run refuses to start
rather than deleting the state file that names those resources; clean it up
with `./e2e/run.sh clean <combo>` first. `--dry-run` leaves artifacts alone.

The runner passes these to `task` as `CONFIG_FILE` and `STATE_FILE`, which is
why `clean <combo>` tears down the right resources even after other combos
have run since. Those two variables are part of the Taskfile's interface, so
the same works by hand:

```bash
task delete-playground \
  CONFIG_FILE=$PWD/e2e/artifacts/<combo>/config.yaml \
  STATE_FILE=$PWD/e2e/artifacts/<combo>/state.yaml
```

With neither set they default to `config.yaml` and `.state` at the capt root,
which is what an interactive `task create-playground` uses. Your own
`config.yaml` is never touched by the e2e runner.

### Deleting reads the state file, not the config

`config.yaml` says what a playground _would_ be built from; `.state` records
what a run _did_ build. Every `delete-playground` task reads `.state` — the
cluster names, VM names, BMC container, docker network and output directory
all come from it. Edit `config.yaml` after creating a playground and teardown
still removes what is actually running.

This means `.state` is required to delete. Without it there is no record of
what exists, so `delete-playground` fails a precondition rather than guessing
from `config.yaml` and, at best, silently deleting nothing. `delete-playground`
does not remove `.state` itself — it is yours to inspect, and the delete tasks
all guard on whether a resource actually exists, so a leftover one is inert.

### Flags

Global, accepted by every command and ahead of the command name:

- `-v, --verbose` — show label filters, full paths and longer log excerpts.
- `-q, --quiet` — print only the final verdict.
- `--plain` — disable colour, glyphs and progress updates. Colour is also
  disabled automatically when output is not a terminal, and honours
  `NO_COLOR`.
- `--no-color` — drop colour but keep glyphs and progress updates.

`run` (and, where they shape the rendered config, `config`):

- `--mirror-host HOST` — registry mirror hostname, required by the
  `*-mirror` combos.
- `--no-teardown` — keep the playground running after tests so you can
  poke at it. **Resources persist; clean up with `./e2e/run.sh clean`.**
- `-n, --dry-run` — render configs and print what would run, but skip
  `task` and `ginkgo` invocations.
- `--config FILE` — use `FILE` as `config.yaml` instead of rendering the
  combo. A combo given alongside it still selects which tests run.
- `--chart-version V` — install this Tinkerbell Helm chart version instead of
  the latest. By default the runner resolves what `latest` points at on
  `ghcr.io/tinkerbell/tinkerbell` and installs the chart published alongside it,
  so a run picks up main without anyone editing a pin. Cannot be combined with
  the `--tinkerbell-*` flags below, which produce the chart.
- `--tinkerbell-repo R` — build Tinkerbell from this git URL or local checkout
  instead of using released artifacts.
- `--tinkerbell-ref REF` — build Tinkerbell from this branch, tag or commit.
  Either `--tinkerbell-*` flag alone is enough; the repo defaults to upstream
  and the ref to that repo's default branch. See
  [Building Tinkerbell from source](#building-tinkerbell-from-source) for how
  the two combine and what is cached.
- `--labels FILTER` — Ginkgo `--label-filter` (default: derived from the combo).
- `--artifacts DIR` — where per-combo logs and JUnit reports are written
  (default `e2e/artifacts/`).
- `--log-lines N` — how many lines of the running command's output to show
  beneath its phase line (default 5, `0` disables). The full output is always
  written to the combo's `create.log` / `ginkgo.log` regardless.

`list`:

- `--json` — machine-readable output.

`clean`:

- `-a, --all` — clean every combo with a state file on disk.
- `-n, --dry-run` — print what would be deleted, touch nothing.
- `--artifacts DIR` — where the combo artifacts live.

Every flag can also be set from the environment: prefix `E2E_`, upper-case,
and replace `-` with `_`. `--mirror-host` is `E2E_MIRROR_HOST`, `--log-lines`
is `E2E_LOG_LINES`, and so on. Flags take precedence over the environment,
which makes CI defaults easy to set once and override per invocation:

```bash
export E2E_MIRROR_HOST=reg.example.com
export E2E_ARTIFACTS=/tmp/e2e
./e2e/run.sh run --all
```

The Ginkgo suite under [`e2e/test/`](e2e/test/) can also be run directly
against an already-provisioned playground by exporting the kubeconfig
paths:

```bash
E2E_MGMT_KUBECONFIG="$(yq .kind.kubeconfig .state)" \
E2E_WORKLOAD_KUBECONFIG="$(yq .outputDir .state)/$(yq .clusterName .state).kubeconfig" \
E2E_NAMESPACE="$(yq .namespace .state)" \
ginkgo -v --label-filter=provisioning ./e2e/test/...
```

## How CUE renders the playground

`config.yaml` is the only file most users touch. Everything else
(`.state`, generated CAPI manifests, kind config, hardware/BMC YAML,
`hosts.toml` mirror drop-ins) is derived by CUE packages under
[`cue/`](cue/):

- [`cue/state`](cue/state/state.cue) — reads `config.yaml`, computes
  derived names/IPs/MACs, writes `.state` (the source of truth for
  every downstream renderer).
- [`cue/values`](cue/values/values.cue) — the `#Config` schema for
  `.state`. Inner structs are closed so typos fail `cue vet`.
- [`cue/capi`](cue/capi/render.cue), [`cue/infra`](cue/infra/render.cue),
  [`cue/clusterctl`](cue/clusterctl/clusterctl.cue), [`cue/kind`](cue/kind/kind.cue)
  — render Kubernetes resources from `.state`.
- [`cue/mirror`](cue/mirror/schema.cue) — optional pull-through OCI
  registry mirror. Disabled by default; the wiring sentinel in
  [`cue/wiring`](cue/wiring/wiring.cue) ensures the feature can't be
  half-removed by accident.

`task generate-state` runs `cue vet` before `cue export`, so schema
errors surface with line numbers before any other task runs.

## Known Issues

### DNS issue

KinD on Ubuntu has a known issue with DNS resolution in KinD pod containers. This affect the Download of HookOS in the Tink stack helm deployment. There are a few [known workarounds](https://github.com/kubernetes-sigs/kind/issues/1594#issuecomment-629509450). The recommendation for the CAPT playground is to add a DNS nameservers to Docker's `daemon.json` file. This can be done by adding the following to `/etc/docker/daemon.json`:

```json
{
  "dns": ["1.1.1.1"]
}
```

Then restart Docker:

```bash
sudo systemctl restart docker
```
