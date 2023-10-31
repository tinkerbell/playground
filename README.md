# Playground

The playground is an example deployment of the Tinkerbell stack for use in learning and testing. It is not a production reference architecture.
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

Now that you have a Tinkerbell stack up and running, you can start provisioning machines.
Tinkerbell.org has a [list of guides](https://docs.tinkerbell.org/deploying-operating-systems/the-deployment/) for provisioning machines.
You can also create your own.
The following docs will help you get started.

1. [Example Hardware object](https://github.com/tinkerbell/tink/tree/main/config/crd/examples/hardware.yaml)
2. [Example Template object](https://github.com/tinkerbell/tink/tree/main/config/crd/examples/template.yaml)
   - Template [documentation](https://docs.tinkerbell.org/templates/)
3. [Example Workflow object](https://github.com/tinkerbell/tink/tree/main/config/crd/examples/workflow.yaml)

### In the Sandbox

1. Add your templates

   ```bash
   kubectl apply -f my-custom-template.yaml
   ```

2. Create the workflow

   ```bash
   kubectl apply -f my-custom-workflow.yaml
   ```

3. Restart the machine to provision (if using the vagrant sandbox test machine this is done by running `vagrant destroy -f machine1 && vagrant up machine1`)
