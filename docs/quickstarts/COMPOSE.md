# Quick start guide for Docker Compose

This option will stand up the provisioner using Docker Compose.
You will need to bring your own machines to provision.

## Prerequisites

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) is installed
- [Docker](https://docs.docker.com/get-docker/) is installed (version >= 19.03)
- [Docker Compose](https://docs.docker.com/compose/install/) is installed (version >= 2.10.2)

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/sandbox.git
   cd sandbox
   ```

2. Set the public IP address for the provisioner

   ```bash
   # This should be an IP that's on an interface where you will be provisioning machines
   export TINKERBELL_HOST_IP=192.168.2.111
   ```

3. Set the IP and MAC address of the machine you want to provision (if you want Tink hardware, template, and workflow records auto-generated)

   ```bash
   # This IP and MAC of the machine to be provisioned
   # The IP should normally be in the same network as the IP used for the provisioner
   export TINKERBELL_CLIENT_IP=192.168.2.211
   export TINKERBELL_CLIENT_MAC=08:00:27:9E:F5:3A
   ```

   > Modify the [hardware.yaml](../../deploy/compose/manifests/hardware.yaml), as needed, for your machine.

4. Start the provisioner

   ```bash
   cd deploy/compose
   docker compose up -d
   # This process will take about 5-10 minutes depending on your internet connection.
   # Hook (OSIE) is about 400MB in size and the Ubuntu Focal image is about 500MB
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   [+] Running 15/15
   ⠿ Network compose_default                              Created             0.0s
   ⠿ Volume "compose_k3s-server"                          Created             0.0s
   ⠿ Container compose-fetch-and-convert-ubuntu-img-1     Exited              2.9s
   ⠿ Container compose-fetch-osie-1                       Exited              1.7s
   ⠿ Container compose-manifest-update-1                  Started             1.2s
   ⠿ Container compose-k3s-1                              Healthy            99.7s
   ⠿ Container compose-web-assets-server-1                Started             3.1s
   ⠿ Container compose-tink-crds-apply-1                  Exited            128.0s
   ⠿ Container compose-rufio-crds-apply-1                 Exited            127.5s
   ⠿ Container compose-tink-controller-1                  Started           128.5s
   ⠿ Container compose-boots-1                            Started           128.0s
   ⠿ Container compose-tink-server-1                      Started           128.8s
   ⠿ Container compose-hegel-1                            Started           128.9s
   ⠿ Container compose-manifest-apply-1                   Started           128.9s
   ⠿ Container compose-rufio-1                            Started           127.7s
   ```

   </details>

5. Power up the machine to be provisioned

6. Watch for the provisioner to complete

   ```bash
   # watch for the workflow to completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   KUBECONFIG=./state/kube/kubeconfig.yaml kubectl get workflow sandbox-workflow --watch
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

   <details>
   <summary>Postgres backend</summary>

   ```bash
   # watch the workflow events and status for workflow completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   wid=$(tink workflow get --no-headers | awk '/^\|/ {print $2}'); watch -n1 "tink workflow events ${wid}; tink workflow state ${wid}"

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

7. Reboot the machine

8. Login to the machine

   The machine has been provisioned with Ubuntu Focal.
   You can now SSH into the machine.

   ```bash
   # crtl-c to exit the watch
   ssh tink@${TINKERBELL_CLIENT_IP} # user/pass => tink/tink
   ```
