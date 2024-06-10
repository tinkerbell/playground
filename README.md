# Playground

This playground repository holds example deployments for use in learning and testing.
The following playgrounds are available:

- [Tinkerbell stack playground](#tinkerbell-stack-playground)
- [Cluster API Provider Tinkerbell (CAPT) playground](#cluster-api-provider-tinkerbell-capt-playground)

## Tinkerbell Stack Playground

The following section containers the Tinkerbell stack playground instructions. It is not a production reference architecture.
Please use the [Helm chart](https://github.com/tinkerbell/charts) for production deployments.

### Quick-Starts

The following quick-start guides will walk you through standing up the Tinkerbell stack.
There are a few options for this.
Pick the one that works best for you.

### Options

- [Vagrant and VirtualBox](docs/quickstarts/VAGRANTVBOX.md)
- [Vagrant and Libvirt](docs/quickstarts/VAGRANTLVIRT.md)
- [Kubernetes](docs/quickstarts/KUBERNETES.md)

### Next Steps

By default the Vagrant quickstart guides automatically install Ubuntu on the VM (machine1). You can provide your own OS template. To do this:

1. Login to the stack VM

   ```bash
   vagrant ssh stack
   ```

1. Add your template. An example Template object can be found [here](https://github.com/tinkerbell/tink/tree/main/config/crd/examples/template.yaml) and more Template documentation can be found [here](https://tinkerbell.org/docs/concepts/templates/).

   ```bash
   kubectl apply -f my-OS-template.yaml
   ```

1. Create the workflow. An example Workflow object can be found [here](https://github.com/tinkerbell/tink/tree/main/config/crd/examples/workflow.yaml).

   ```bash
   kubectl apply -f my-custom-workflow.yaml
   ```

1. Restart the machine to provision (if using the vagrant playground test machine this is done by running `vagrant destroy -f machine1 && vagrant up machine1`)

## Cluster API Provider Tinkerbell (CAPT) Playground

The Cluster API Provider Tinkerbell (CAPT) is a Kubernetes Cluster API provider that uses Tinkerbell to provision machines. You can find more information about CAPT [here](https://github.com/tinkerbell/cluster-api-provider-tinkerbell). The CAPT playground is an example deployment for use in learning and testing. It is not a production reference architecture.

### Getting Started

The CAPT playground is a tool that will create a local CAPT deployment and a single workload cluster. This includes creating and/or installing a Kubernetes cluster (KinD), the Tinkerbell stack, all CAPI and CAPT components, Virtual machines that will be used to create the workload cluster, and a Virtual BMC server to manage the VMs.

Start by reviewing and installing the [prerequisites](#prerequisites) and understanding and customizing the [configuration file](./capt/config.yaml) as needed.

### Prerequisites

#### Binaries

- [Libvirtd](https://wiki.debian.org/KVM) >= libvirtd (libvirt) 8.0.0
- [Docker](https://docs.docker.com/engine/install/) >= 24.0.7
- [Helm](https://helm.sh/docs/intro/install/) >= v3.13.1
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) >= v0.20.0
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start#install-clusterctl) >= v1.6.0
- [kubectl](https://www.downloadkubernetes.com/) >= v1.28.2
- [virt-install](https://virt-manager.org/) >= 4.0.0
- [task](https://taskfile.dev/installation/) >= 3.37.2

#### Hardware

- at least 60GB of free and very fast disk space (etcd is very disk I/O sensitive)
- at least 8GB of free RAM
- at least 4 CPU cores

### Usage

Create the CAPT playground:

```bash
# Run the creation process and follow the outputted next steps at the end of the process.
task create-playground
```

Delete the CAPT playground:

```bash
task delete-playground
```

### Known Issues

#### DNS issue

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
