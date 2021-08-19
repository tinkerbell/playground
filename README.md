# Quick-Starts

The following quick-start guides will walk you through standing up the Tinkerbell stack.
There are a few options for this.
Pick the one that works best for you.

## Options

- [Vagrant and VirtualBox](docs/quickstarts/VAGRANTVBOX.md)
- [Vagrant and Libvirt](docs/quickstarts/VAGRANTLVIRT.md)
- [Docker Compose](docs/quickstarts/COMPOSE.md)
- [Terraform and Equinix Metal](docs/quickstarts/TERRAFORMEM.md)
- [Kubernetes](docs/quickstarts/KUBERNETES.md)
- [Multipass](docs/quickstarts/MULTIPASS.md)

## Next Steps

Now that you have a Tinkerbell stack up and running, you can start provisioning machines.
Tinkerbell.org has a [list of guides](https://docs.tinkerbell.org/deploying-operating-systems/the-deployment/) for provisioning machines.
You can also create your own.
The following docs will help you get started.

1. [Create Hardware Data](https://docs.tinkerbell.org/setup/local-vagrant/#creating-the-workers-hardware-data)
2. [Create a Template](https://docs.tinkerbell.org/setup/local-vagrant/#creating-a-template)
3. [Create a Workflow](https://docs.tinkerbell.org/setup/local-vagrant/#creating-the-workflow)

### In the Sandbox

1. Create your own templates

   ```bash
   docker exec -i compose_tink-cli_1 tink template create < ./custom-template.yaml
   ```

2. Upload any container images you want to use in the templates to the internal registry

   ```bash
   docker run -it --rm quay.io/containers/skopeo copy --all --dest-tls-verify=false --dest-creds="admin":"Admin1234" docker://hello-world docker://192.168.50.4/hello-world
   ```

3. Create a workflow

   ```bash
   docker exec -i compose_tink-cli_1 tink workflow create -t <TEMPLATE ID> -r '{"device_1":"08:00:27:00:00:01"}')
   ```

4. Restart the machine to provision (if using the vagrant sandbox test machine this is done by running vagrant destroy -f machine1 && vagrant up machine1
