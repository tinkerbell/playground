## Tinkerbell Stack Playground

The following section container the Tinkerbell stack playground instructions. It is not a production reference architecture.
Please use the [Helm chart](https://github.com/tinkerbell/charts) for production deployments.

## Quick-Starts

The following quick-start guides will walk you through standing up the Tinkerbell stack.
There are a few options for this.
Pick the one that works best for you.

## Options

- [Vagrant and VirtualBox](docs/quickstarts/VAGRANTVBOX.md)
- [Vagrant and Libvirt](docs/quickstarts/VAGRANTLVIRT.md)
- [Kubernetes](docs/quickstarts/KUBERNETES.md)

## Next Steps

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
