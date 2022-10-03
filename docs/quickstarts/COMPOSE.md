# Quick start guide for Docker Compose

This option will stand up the provisioner using Docker Compose.
You will need to bring your own machines to provision.

## Prerequisites

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) is installed
- [Docker](https://docs.docker.com/get-docker/) is installed (version >= 19.03)
- [Docker Compose](https://docs.docker.com/compose/install/) is installed (version >= 1.29.0)

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
   docker-compose up -d
   # This process will take about 5-10 minutes depending on your internet connection.
   # Hook (OSIE) is about 400MB in size and the Ubuntu Focal image is about 500MB
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Creating network "compose_default" with the default driver
   Creating volume "compose_k3s-server" with default driver
   Pulling tink-server (quay.io/tinkerbell/tink:v0.7.0)...
   v0.7.0: Pulling from tinkerbell/tink
   9621f1afde84: Already exists
   45d75a7e2c40: Pull complete
   c3d0a7e0154d: Pull complete
   Digest: sha256:b4ee7cf6da1e7dc5a5107e51e725b4fa7e46aac65cbe42cfe22139b07d6363b3
   Status: Downloaded newer image for quay.io/tinkerbell/tink:v0.7.0
   Pulling tink-controller (quay.io/tinkerbell/tink-controller:sha-eeb2a454)...
   sha-eeb2a454: Pulling from tinkerbell/tink-controller
   9621f1afde84: Already exists
   d532ffcfa954: Pull complete
   c56b0a87f19d: Pull complete
   Digest: sha256:3cd56aaaf02fcbfcada752013db85f23816300b52527df0fb8f5481252bbc925
   Status: Downloaded newer image for quay.io/tinkerbell/tink-controller:sha-eeb2a454
   Pulling hegel (quay.io/tinkerbell/hegel:v0.7.0)...
   v0.7.0: Pulling from tinkerbell/hegel
   5d20c808ce19: Pull complete
   0c56430d993f: Pull complete
   f6b392cbe540: Pull complete
   14a8d8138b1d: Pull complete
   Digest: sha256:6cae60bc29eaee5b213b258894f50caebd8c229a2bafa666e88772da4e4f8ded
   Status: Downloaded newer image for quay.io/tinkerbell/hegel:v0.7.0
   Pulling boots (quay.io/tinkerbell/boots:v0.7.0)...
   v0.7.0: Pulling from tinkerbell/boots
   6097bfa160c1: Pull complete
   0f3cf798c031: Pull complete
   bcecd77be5a5: Pull complete
   Digest: sha256:4ac5c895d9ec455872352daffb659a359df8caa89616d62c66442e36b5cef6ac
   Status: Downloaded newer image for quay.io/tinkerbell/boots:v0.7.0
   Creating compose_fetch-osie_1                   ... done
   Creating compose_k3s_1                          ... done
   Creating compose_manifest-update_1              ... done
   Creating compose_fetch-and-convert-ubuntu-img_1 ... done
   Creating compose_web-assets-server_1            ... done
   Creating compose_tink-crds-apply_1              ... done
   Creating compose_tink-server_1                  ... done
   Creating compose_tink-controller_1              ... done
   Creating compose_manifest-apply_1               ... done
   Creating compose_boots_1                        ... done
   Creating compose_hegel_1                        ... done
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
