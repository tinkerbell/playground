# Architecture: the CAPT playground (IPv4)

C4 diagrams for a playground created with the default `ipFamily: ipv4`. The
[IPv6 architecture](./architecture-playground-ipv6.md) is described as a delta
against this one, so read this first.

Diagrams follow the [C4 model](https://c4model.com/): context, then containers,
then the components inside the one container that matters most.

## Level 1: system context

What the playground is, and what it needs from the machine it runs on.

```mermaid
C4Context
    title CAPT playground — system context

    Person(operator, "Operator", "Runs task create-playground, or the e2e runner")

    System(playground, "CAPT playground", "A disposable Cluster API + Tinkerbell environment that provisions VMs as if they were bare metal")

    System_Ext(docker, "Docker Engine", "Runs the kind clusters, the virtual BMC and the playground bridge network")
    System_Ext(libvirt, "libvirt / KVM", "Runs the VMs that stand in for bare metal machines")
    System_Ext(registries, "Container registries", "ghcr.io, quay.io — Tinkerbell chart and images, workflow actions, OS images")
    System_Ext(capt_releases, "CAPT releases", "github.com/tinkerbell/cluster-api-provider-tinkerbell")

    Rel(operator, playground, "Creates, inspects, deletes")
    Rel(playground, docker, "Creates networks and containers")
    Rel(playground, libvirt, "Defines and boots VMs")
    Rel(playground, registries, "Pulls chart, images and OS")
    Rel(playground, capt_releases, "clusterctl init downloads the provider")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

Everything the playground creates is namespaced by an **instance id** — the
first 8 characters of the SHA-256 of the state file's path
([cue/state/state.cue](../cue/state/state.cue)). That is what lets several
playgrounds share one host without colliding, and it is why the e2e runner gives
each combination its own artifact directory.

## Level 2: containers

The moving parts of one colocated playground (`externalTinkerbell: false`).

```mermaid
C4Container
    title CAPT playground (IPv4, colocated) — containers

    Person(operator, "Operator")

    System_Boundary(host, "Developer machine") {
        Container(task, "task + CUE", "Taskfile, CUE, bash", "Renders config.yaml into state.yaml, then drives every step in order")

        Container_Boundary(net, "Playground docker bridge") {
            Container(kind, "Management kind cluster", "Kubernetes in Docker", "CAPI core, CAPT, and the Tinkerbell stack")
            Container(tink, "Tinkerbell", "Single Go binary, Helm chart", "Smee, Tootles, Tink server and controller, Rufio")
            Container(vbmc, "Virtual BMC", "sushy-tools container, shared", "Redfish and IPMI facade over libvirt domains")
        }

        Container(vms, "Node VMs", "libvirt domains, UEFI", "node1..nodeN — the pretend bare metal")
        ContainerDb(output, "output/", "Files", "kubeconfigs, SSH key, rendered CRs, cluster manifest")
    }

    System_Ext(registries, "Container registries")

    Rel(operator, task, "task create-playground")
    Rel(task, kind, "kind create cluster, kubectl apply, helm install")
    Rel(task, vms, "virt-install")
    Rel(task, vbmc, "Registers one BMC port per VM")
    Rel(task, output, "Writes")

    Rel(kind, tink, "Hosts")
    Rel(tink, vbmc, "Power and boot-device control")
    Rel(vbmc, vms, "libvirt start, stop, set boot device")
    Rel(vms, tink, "DHCP, TFTP, iPXE, metadata, workflow reporting")
    Rel(vms, registries, "Pulls the OS image and action images")
    Rel(tink, registries, "Pulls its own images")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

Two details that the diagram cannot show:

- **The virtual BMC is shared between playgrounds and outlives any one of
  them.** It runs on the host network so it can reach libvirt, and is attached
  to each playground's bridge as playgrounds come and go. Ports are handed out
  from 6231 in blocks of 16, with the block chosen from the instance id
  ([scripts/vbmc_ports.sh](../scripts/vbmc_ports.sh)), so two playgrounds
  created at the same moment do not start from the same port.
- **A registry only exists for source builds.** With `source:` set, the
  playground builds Tinkerbell and the agent, pushes them to a shared local
  registry, and rewrites the image references in the state file. Otherwise
  nothing local is published.

### External Tinkerbell

With `externalTinkerbell: true` there are two kind clusters on the same bridge:

```mermaid
C4Container
    title CAPT playground — external Tinkerbell topology

    Container_Boundary(net, "Playground docker bridge") {
        Container(mgmt, "Management kind cluster", "Kubernetes", "CAPI core and CAPT only")
        Container(tinkc, "Tinkerbell kind cluster", "Kubernetes", "The Tinkerbell stack and its CRs")
        Container(vbmc, "Virtual BMC", "sushy-tools")
    }

    Container(vms, "Node VMs", "libvirt domains")

    Rel(mgmt, tinkc, "Reads and writes Hardware and Workflow CRs", "kubeconfig in a Secret")
    Rel(tinkc, vbmc, "Power control")
    Rel(vbmc, vms, "libvirt")
    Rel(vms, tinkc, "Boot and workflow")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

CAPT reaches the second cluster through a kubeconfig Secret written by
[scripts/create_external_kubeconfig_secret.sh](../scripts/create_external_kubeconfig_secret.sh).
The address in it is the kind node's container IP, which is why a pivot to
another host is not supported in this mode.

## Level 3: components of the Tinkerbell container

The Helm chart deploys **one** container running **one** binary
([cmd/tinkerbell](https://github.com/tinkerbell/tinkerbell/tree/main/cmd/tinkerbell)).
What are separate services in other deployments are subsystems here, each
toggled by a flag, which is why the playground has a single Deployment to watch
rather than five.

```mermaid
C4Component
    title Tinkerbell deployment — components

    Container_Boundary(pod, "tinkerbell Deployment") {
        Component(smee, "Smee", "DHCP, TFTP, HTTP/iPXE", "Answers the VM's boot request and serves the provisioning OS")
        Component(tootles, "Tootles", "HTTP :7080", "EC2-style metadata, which cloud-init reads on first boot")
        Component(tinkserver, "Tink server", "gRPC", "Hands workflow actions to the agent and records their results")
        Component(tinkcontroller, "Tink controller", "Kubernetes controller", "Reconciles Workflow CRs")
        Component(rufio, "Rufio", "Kubernetes controller", "Turns BMC Machine and Job CRs into Redfish or IPMI calls")
    }

    ContainerDb(api, "Kubernetes API", "Hardware, BMCMachine, Workflow, Template CRs")
    Container(vbmc, "Virtual BMC")
    Container(vm, "Node VM")
    Container(agent, "tink-agent", "Runs inside the provisioning OS")

    Rel(smee, api, "Looks up Hardware by MAC")
    Rel(vm, smee, "DHCP, then fetches iPXE or the ISO")
    Rel(agent, tinkserver, "Asks for the next action, reports the result")
    Rel(tinkcontroller, api, "Watches Workflows")
    Rel(rufio, api, "Watches BMC CRs")
    Rel(rufio, vbmc, "Power on, set boot device")
    Rel(agent, tootles, "Reads instance metadata")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## How a node gets provisioned

The diagrams above are static. This is the order things happen in, and it is the
sequence the e2e tests assert on.

```mermaid
sequenceDiagram
    participant CAPI as CAPI + CAPT
    participant K8s as Kubernetes API
    participant Rufio
    participant BMC as Virtual BMC
    participant VM as Node VM
    participant Smee
    participant Agent as tink-agent

    CAPI->>K8s: Create Workflow from the machine template
    CAPI->>K8s: Claim a Hardware by role label
    Rufio->>K8s: See the power job
    Rufio->>BMC: Set boot device, power on
    BMC->>VM: libvirt start
    VM->>Smee: DHCP discover
    Smee->>K8s: Look up Hardware by MAC
    Smee-->>VM: Address, then iPXE script or ISO
    VM->>VM: Boot CaptainOS into memory
    Agent->>Smee: Fetch the workflow
    Agent->>Agent: oci2disk — stream the OS to /dev/vda
    Agent->>Agent: writefile — cloud-init datasource
    Agent->>Agent: kexec — boot the installed OS
    VM->>K8s: kubeadm join, node registers
```

`bootMode` changes only the middle of this: `netboot` fetches an iPXE script and
pulls kernel and initrd over TFTP/HTTP, while `isoboot` has Rufio attach
`http://<hookos-vip>:7080/iso/hook.iso` as virtual media
([cue/capi/bootmode.cue](../cue/capi/bootmode.cue)). Everything before and after
is identical, which is why one test suite covers both.

## Addresses

Derived in [cue/state/state.cue](../cue/state/state.cue) from the bridge gateway
docker allocates, so nothing is hard-coded to a subnet:

| Thing                  | Address                            |
| ---------------------- | ---------------------------------- |
| Node VMs               | gateway `.10.1` upward, one per VM |
| Provisioning OS VIP    | gateway `.10.(nodes+50)`           |
| Tinkerbell VIP         | gateway `.10.(nodes+51)`           |
| Workload control plane | gateway `.10.(nodes+52)`           |
| Pod / service CIDRs    | `10.100.0.0/16` / `172.26.0.0/16`  |

The control-plane VIP is held by kube-vip, started as a static pod by the first
control plane node's `preKubeadmCommands`.

## Where to look next

- [IPv6 architecture](./architecture-playground-ipv6.md) — what the translation
  layer adds.
- [e2e architecture](./architecture-e2e.md) — how the test harness drives all of
  the above.
- [capt/README.md](../README.md) — the reference for configuration keys.
