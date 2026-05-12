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

The following are downloaded automatically into `./bin/` by `task install-binaries` (invoked as part of `task create-playground`); pinned versions live near the top of [Taskfile.yaml](./Taskfile.yaml):

- `cue` — workload-manifest renderer
- `helm`
- `kind`
- `kubectl`
- `clusterctl`
- `yq`

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
clusters, then tears the playground down.

List available combos:

```bash
./e2e/run.sh --list
```

Run a single combo:

```bash
./e2e/run.sh single-nomirror-netboot
```

Run the whole matrix (combos that use the registry mirror require
`--mirror-host`):

```bash
./e2e/run.sh --mirror-host reg.example.com all
```

Useful flags:

- `--no-teardown` — keep the playground running after tests so you can
  poke at it. **Resources persist; clean up with `./e2e/run.sh --cleanup`.**
- `--dry-run` — render configs and print what would run, but skip
  `task` and `ginkgo` invocations.
- `--labels FILTER` — Ginkgo `--label-filter` (default `provisioning`).
- `--artifacts DIR` — where per-combo logs and JUnit reports are written
  (default `e2e/artifacts/`).

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
