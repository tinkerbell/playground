# Cluster API Provider Tinkerbell (CAPT) Playground

The Cluster API Provider Tinkerbell (CAPT) is a Kubernetes Cluster API provider that uses Tinkerbell to provision machines. You can find more information about CAPT [here](https://github.com/tinkerbell/cluster-api-provider-tinkerbell). The CAPT playground is an example deployment for use in learning and testing. It is not a production reference architecture.

## Getting Started

The CAPT playground is a tool that will create a local CAPT deployment and a single workload cluster. This includes creating and installing a Kubernetes cluster (KinD), the Tinkerbell stack, all CAPI and CAPT components, Virtual machines that will be used to create the workload cluster, and a Virtual BMC server to manage the VMs.

Start by reviewing and installing the [prerequisites](#prerequisites) and understanding and customizing the [configuration file](./config.yaml) as needed.

## Prerequisites

### Binaries

- [Libvirtd](https://wiki.debian.org/KVM) >= libvirtd (libvirt) 8.0.0
- [Docker](https://docs.docker.com/engine/install/) >= 24.0.7
- [Helm](https://helm.sh/docs/intro/install/) >= v3.13.1
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) >= v0.20.0
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start#install-clusterctl) >= v1.6.0
- [kubectl](https://www.downloadkubernetes.com/) >= v1.28.2
- [virt-install](https://virt-manager.org/) >= 4.0.0
- [yq](https://github.com/mikefarah/yq/#install) >= v4.44.2
- [task](https://taskfile.dev/installation/) >= 3.37.2

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
