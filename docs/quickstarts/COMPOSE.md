# Quick start guide for Docker Compose

This option will stand up the provisioner using Docker Compose.
You will need to bring your own machines to provision.

## Prerequisites

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) is installed
- [Docker](https://docs.docker.com/get-docker/) is installed (version >= 19.03)
- [Docker Compose](https://docs.docker.com/compose/install/) is installed (version >= 2.10.2)

Both the Tinkerbell host and client require internet access to pull images, this sandbox is not designed to work in an isolated network. 

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/sandbox.git
   cd sandbox
   ```

2. Modify the [.env file](https://github.com/tinkerbell/sandbox/blob/47cfd6d0a0b659f1e364a78a4e63e08cdf168ca8/deploy/stack/compose/.env)

   ```bash
   # This should be an IP that's on an interface where you will be provisioning machines
   # This is the IP and MAC of the machine to be provisioned
   # The IP should normally be in the same network as the IP used for the provisioner
   TINKERBELL_CLIENT_IP=192.168.56.43
   TINKERBELL_CLIENT_MAC=08:00:27:9e:f5:3a

   # These are the Gateway and DNS addresses the client should use, required for tink-worker to pull action images
   TINKERBELL_CLIENT_GW=192.168.65.1
   TINKERBELL_CLIENT_NAMESERVER_1=1.1.1.1
   TINKERBELL_CLIENT_NAMESERVER_2=8.8.8.8

   # This should be an IP that's on an interface where you will be provisioning machines
   TINKERBELL_HOST_IP=192.168.56.4
   ```

   If you are provisioning bare metal machines with NVME SSDs, use NVME device paths:

   ```bash
   # This is the boot/primary disk device and the device for its first partition 
   # for the machine to be provisioned (as it would appear with lsblk)
   #DISK_DEVICE=/dev/sda
   #DISK_DEVICE_PARTITION_1=/dev/sda1
   # Example for a device with an NVME SSD
   DISK_DEVICE=/dev/nvme0n1
   DISK_DEVICE_PARTITION_1=/dev/nvme0n1p1
   ```

   > Optionally modify the [hardware.yaml](../../deploy/stack/compose/manifests/hardware.yaml), as needed, for your machine.

3. Start the provisioner

   ```bash
   cd deploy/stack/compose
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

4. Power up the machine to be provisioned

5. Watch for the provisioner to complete

   ```bash
   # watch for the workflow to completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   KUBECONFIG=./state/kube/kubeconfig.yaml kubectl get -n default workflow sandbox-workflow --watch
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

6. Reboot the machine

7. Login to the machine

   The machine has been provisioned with Ubuntu Focal.
   You can now SSH into the machine.

   ```bash
   # crtl-c to exit the watch
   ssh tink@${TINKERBELL_CLIENT_IP} # user/pass => tink/tink
   ```
