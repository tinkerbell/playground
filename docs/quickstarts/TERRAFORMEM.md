# Quick start guide for Terraform on Equinix Metal

This option will stand up the provisioner on a Bare Metal machine using Terraform with Equinix Metal.
This option will also show you how to create a machine to provision.

## Prerequisites

- [Terraform](https://www.vagrantup.com/downloads) is installed

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/sandbox.git
   cd sandbox
   ```

2. Set your Equinix Metal project id and access token

   ```bash
   cd deploy/infrastructure/terraform
   cat << EOF > terraform.tfvars
   metal_api_token = "awegaga4gs4g"
   project_id = "235-23452-245-345"
   EOF
   ```

3. Start the provisioner

   ```bash
   terraform init
   terraform apply
   # This process will take about 5-10 minutes.
   # Most of the time will be to download OSIE.
   # OSIE is about 2GB in size and the Ubuntu Focal image is about 500MB
   ```

4. Confirm setup.sh script has finished

   ```bash
   # log in to the provisioner
   ssh root@$(terraform output -raw provisioner_ssh)

   # verify that the /root/setup.sh script has finished running
   ps -aux | grep setup.sh
   ```

5. Reboot the machine

   In the [Equinix Metal Web UI](https://console.equinix.com), find the `tink_worker` and reboot it.
   Or if you have the [Equinix Metal CLI](https://github.com/equinix/metal-cli) installed run the following:

   ```bash
   metal device reboot -i $(terraform output -raw worker_id)
   ```

6. Watch the provision complete

   Follow the docker-compose logs: 

   ```bash
   # log in to the provisioner
   ssh root@$(terraform output -raw provisioner_ssh)

   # watch the docker-compose logs
   # you should see Boots offer tink-worker an IP address and see tink-worker downloading files from the web server
   docker-compose -f /sandbox/compose/docker-compose.yml logs -f

   ```
   Some of the steps can take a while to complete. In particular, it may look like tink-worker is hanging and not interacting with the provisioner after pulling the LinuxKit image. It may take a few minutes before it starts any of the workflows. 

   In a separate SSH session, watch the status of workflow tasks:
   ```bash
   # log in to the provisioner
   ssh root@$(terraform output -raw provisioner_ssh)
   
   # watch for the workflow to completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   KUBECONFIG=/sandbox/compose/state/kube/kubeconfig.yaml kubectl get -n default workflow sandbox-workflow --watch
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   NAME               TEMPLATE       STATE
   sandbox-workflow   ubuntu-focal   STATE_PENDING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_RUNNING
   sandbox-workflow   ubuntu-focal   STATE_SUCCESS
   ```

   </details>

7. Reboot the machine

   Disable PXE booting in the [Equinix Metal Web UI](https://console.equinix.com).

   Now reboot the `tink-worker` via the [Equinix Metal Web UI](https://console.equinix.com), or if you have the [Equinix Metal CLI](https://github.com/equinix/metal-cli) installed run the following:

   ```bash
   metal device reboot -i $(terraform output -raw worker_id)
   ```

8. Login to the machine

   The `tink-worker` machine has been provisioned with Ubuntu Focal.
   Wait for the reboot to complete and then you can SSH into it from the `tink-provisioner` machine.
   It may take some time for the worker to become available via SSH.

   ```bash
   # Continuing on the tink-provisioner machine
   # crtl-c to exit the watch
   ssh tink@192.168.56.43 # user/pass => tink/tink
   ```
