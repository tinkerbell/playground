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
   cd deploy/terraform
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

4. Reboot the machine

   In the [Equinix Metal Web UI](https://console.equinix.com), find the `tink_worker` and reboot it.
   Or if you have the [Equinix Metal CLI](https://github.com/equinix/metal-cli) installed run the following:

   ```bash
   metal device reboot -i $(terraform show -json | jq -r '.values.root_module.resources[1].values.id')
   ```

5. Watch the provision complete

   ```bash
   # log in to the provisioner
   ssh root@139.178.69.231
   # watch the workflow events and status for workflow completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   wid=$(cat sandbox/compose/create-tink-records/manifests/workflow/workflow_id.txt); docker exec -it compose_tink-cli_1 watch -n1 "tink workflow events ${wid}; tink workflow state ${wid}"
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   +--------------------------------------+-----------------+---------------------+----------------+---------------------------------+---------------+
   | WORKER ID                            | TASK NAME       | ACTION NAME         | EXECUTION TIME | MESSAGE                         | ACTION STATUS |
   +--------------------------------------+-----------------+---------------------+----------------+---------------------------------+---------------+
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | stream-ubuntu-image |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | stream-ubuntu-image |             15 | finished execution successfully | STATE_SUCCESS |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | install-openssl     |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | install-openssl     |              1 | finished execution successfully | STATE_SUCCESS |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | create-user         |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | create-user         |              0 | finished execution successfully | STATE_SUCCESS |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | enable-ssh          |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | enable-ssh          |              0 | finished execution successfully | STATE_SUCCESS |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | disable-apparmor    |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | disable-apparmor    |              0 | finished execution successfully | STATE_SUCCESS |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | write-netplan       |              0 | Started execution               | STATE_RUNNING |
   | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 | os-installation | write-netplan       |              0 | finished execution successfully | STATE_SUCCESS |
   +--------------------------------------+-----------------+---------------------+----------------+---------------------------------+---------------+
   +----------------------+--------------------------------------+
   | FIELD NAME           | VALUES                               |
   +----------------------+--------------------------------------+
   | Workflow ID          | 3107919b-e59d-11eb-bf99-0242ac120005 |
   | Workflow Progress    | 100%                                 |
   | Current Task         | os-installation                      |
   | Current Action       | write-netplan                        |
   | Current Worker       | 0eba0bf8-3772-4b4a-ab9f-6ebe93b90a94 |
   | Current Action State | STATE_SUCCESS                        |
   +----------------------+--------------------------------------+
   ```

   </details>

6. Reboot the machine

   Now reboot the `tink-worker` via the [Equinix Metal Web UI](https://console.equinix.com), or if you have the [Equinix Metal CLI](https://github.com/equinix/metal-cli) installed run the following:

   ```bash
   metal device reboot -i $(terraform show -json | jq -r '.values.root_module.resources[1].values.id')
   ```

7. Login to the machine

   The machine has been provisioned with Ubuntu Focal.
   Wait for the reboot to complete and then you can SSH into it.

   ```bash
   # crtl-c to exit the watch
   ssh tink@192.168.56.43 # user/pass => tink/tink
   ```
