# Quick start guide for Vagrant and Libvirt

This option will stand up the provisioner in Libvirt using Vagrant.
This option will also show you how to create a machine to provision.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) is installed
- [Libvirt](https://ubuntu.com/server/docs/virtualization-libvirt) is installed

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/sandbox.git
   cd sandbox
   ```

2. Start the provisioner

   ```bash
   cd deploy/vagrant
   vagrant up
   # This process will take about 5-10 minutes depending on your internet connection.
   # OSIE is about 2GB in size and the Ubuntu Focal image is about 500MB
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'provisioner' up with 'libvirt' provider...
   ==> provisioner: Checking if box 'generic/ubuntu2004' version '3.3.4' is up to date...
   ==> provisioner: Creating image (snapshot of base box volume).
   ==> provisioner: Creating domain with the following settings...
   ==> provisioner:  -- Name:              vagrant_provisioner
   ==> provisioner:  -- Domain type:       kvm
   ==> provisioner:  -- Cpus:              2
   ==> provisioner:  -- Feature:           acpi
   ==> provisioner:  -- Feature:           apic
   ==> provisioner:  -- Feature:           pae
   ==> provisioner:  -- Memory:            2048M
   ==> provisioner:  -- Management MAC:
   ==> provisioner:  -- Loader:
   ==> provisioner:  -- Nvram:
   ==> provisioner:  -- Base box:          generic/ubuntu2004
   ==> provisioner:  -- Storage pool:      default
   ==> provisioner:  -- Image:             /var/lib/libvirt/images/vagrant_provisioner.img (128G)
   ==> provisioner:  -- Volume Cache:      default
   ==> provisioner:  -- Kernel:
   ==> provisioner:  -- Initrd:
   ==> provisioner:  -- Graphics Type:     vnc
   ==> provisioner:  -- Graphics Port:     -1
   ==> provisioner:  -- Graphics IP:       127.0.0.1
   ==> provisioner:  -- Graphics Password: Not defined
   ==> provisioner:  -- Video Type:        cirrus
   ==> provisioner:  -- Video VRAM:        256
   ==> provisioner:  -- Sound Type:
   ==> provisioner:  -- Keymap:            en-us
   ==> provisioner:  -- TPM Path:
   ==> provisioner:  -- INPUT:             type=mouse, bus=ps2
   ==> provisioner: Pruning invalid NFS exports. Administrator privileges will be required...
   [sudo] password for tink:
   ==> provisioner: Creating shared folders metadata...
   ==> provisioner: Starting domain.
   ==> provisioner: Waiting for domain to get an IP address...
   ==> provisioner: Waiting for SSH to become available...
       provisioner:
       provisioner: Vagrant insecure key detected. Vagrant will automatically replace
       provisioner: this with a newly generated keypair for better security.
       provisioner:
       provisioner: Inserting generated public key within guest...
       provisioner: Removing insecure key from the guest if it's present...
       provisioner: Key inserted! Disconnecting and reconnecting using new SSH key...
   ==> provisioner: Configuring and enabling network interfaces...
   ==> provisioner: Installing NFS client...
   ==> provisioner: Exporting NFS shared folders...
   ==> provisioner: Preparing to edit /etc/exports. Administrator privileges will be required...
   ==> provisioner: Mounting NFS shared folders...
   ==> provisioner: Running provisioner: docker...
       provisioner: Installing Docker onto machine...
   ==> provisioner: Running provisioner: shell...
       provisioner: Running: inline script
   ==> provisioner: Running provisioner: docker_compose...
       provisioner: Checking for Docker Compose installation...
       provisioner: Getting machine and kernel name from guest machine...
       provisioner: Downloading Docker Compose 1.29.1 for Linux x86_64
       provisioner: Downloaded Docker Compose 1.29.1 has SHA256 signature 8097769d32e34314125847333593c8edb0dfc4a5b350e4839bef8c2fe8d09de7
       provisioner: Uploading Docker Compose 1.29.1 to guest machine...
       provisioner: Installing Docker Compose 1.29.1 in guest machine...
       provisioner: Symlinking Docker Compose 1.29.1 in guest machine...
       provisioner: Running docker-compose up...
   ==> provisioner: Creating network "vagrant_default" with the default driver
   ==> provisioner: Creating volume "vagrant_postgres_data" with default driver
   ==> provisioner: Creating volume "vagrant_certs" with default driver
   ==> provisioner: Creating volume "vagrant_auth" with default driver
   ==> provisioner: Pulling tls-gen (cfssl/cfssl:)...
       provisioner: latest: Pulling from cfssl/cfssl
       provisioner: Digest: sha256:c21e852f3904e2ba77960e9cba23c69d9231467795a8a160ce1d848e621381ea
       provisioner: Status: Downloaded newer image for cfssl/cfssl:latest
   ==> provisioner: Pulling registry-auth (httpd:2)...
       provisioner: 2: Pulling from library/httpd
       provisioner: Digest: sha256:eacdd6c7419ab95b43a258321fc6b38cf56004de4f6a952fc0d96a12730e04de
       provisioner: Status: Downloaded newer image for httpd:2
   ==> provisioner: Pulling osie-work (alpine:)...
       provisioner: latest: Pulling from library/alpine
       provisioner: Digest: sha256:eb3e4e175ba6d212ba1d6e04fc0782916c08e1c9d7b45892e9796141b1d379ae
       provisioner: Status: Downloaded newer image for alpine:latest
   ==> provisioner: Pulling ubuntu-image-setup (ubuntu:)...
       provisioner: latest: Pulling from library/ubuntu
       provisioner: Digest: sha256:82becede498899ec668628e7cb0ad87b6e1c371cb8a1e597d83a47fac21d6af3
       provisioner: Status: Downloaded newer image for ubuntu:latest
   ==> provisioner: Pulling db (postgres:10-alpine)...
       provisioner: 10-alpine: Pulling from library/postgres
       provisioner: Digest: sha256:07bb8292fa57fbe87f5426841105a19db7229e8e684299642e9c2046203abb10
       provisioner: Status: Downloaded newer image for postgres:10-alpine
   ==> provisioner: Pulling tink-server-migration (quay.io/tinkerbell/tink:sha-8ea8a0e5)...
       provisioner: sha-8ea8a0e5: Pulling from tinkerbell/tink
       provisioner: Digest: sha256:84fc83f8562901d0b27e7ebb453a7f27e5797d17fb0b6899f92002df840fbf21
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/tink:sha-8ea8a0e5
   ==> provisioner: Pulling create-tink-records (quay.io/tinkerbell/tink-cli:sha-8ea8a0e5)...
       provisioner: sha-8ea8a0e5: Pulling from tinkerbell/tink-cli
       provisioner: Digest: sha256:0fc5441e9ef6e94eff7bf1ae9cf9a15a98581c742890d2d7130fd9542b12802d
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/tink-cli:sha-8ea8a0e5
   ==> provisioner: Pulling registry (registry:2.7.1)...
       provisioner: 2.7.1: Pulling from library/registry
       provisioner: Digest: sha256:121baf25069a56749f249819e36b386d655ba67116d9c1c6c8594061852de4da
       provisioner: Status: Downloaded newer image for registry:2.7.1
   ==> provisioner: Pulling images-to-local-registry (quay.io/containers/skopeo:latest)...
       provisioner: latest: Pulling from containers/skopeo
       provisioner: Digest: sha256:7ae70111960190f0f638191a707a57301e6b71c2571be2d188c692ead47e9a23
       provisioner: Status: Downloaded newer image for quay.io/containers/skopeo:latest
   ==> provisioner: Pulling boots (quay.io/tinkerbell/boots:sha-94f43947)...
       provisioner: sha-94f43947: Pulling from tinkerbell/boots
       provisioner: Digest: sha256:def67c645dc0517a166bb3ef7eba955e2112a28583ac908a8f84d1382b6046e8
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/boots:sha-94f43947
   ==> provisioner: Pulling osie-bootloader (nginx:alpine)...
       provisioner: alpine: Pulling from library/nginx
       provisioner: Digest: sha256:bead42240255ae1485653a956ef41c9e458eb077fcb6dc664cbc3aa9701a05ce
       provisioner: Status: Downloaded newer image for nginx:alpine
   ==> provisioner: Pulling hegel (quay.io/tinkerbell/hegel:sha-9f5da0a8)...
       provisioner: sha-9f5da0a8: Pulling from tinkerbell/hegel
       provisioner: Digest: sha256:9d3c6d5e4bc957cedafbeec22da4f59d94c78b65d84adbd0c8f947c51cf3668b
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/hegel:sha-9f5da0a8
   ==> provisioner: Creating vagrant_registry-auth_1 ...
   ==> provisioner: Creating vagrant_osie-work_1     ...
   ==> provisioner: Creating vagrant_db_1            ...
   ==> provisioner: Creating vagrant_ubuntu-image-setup_1 ...
   ==> provisioner: Creating vagrant_tls-gen_1            ...
   ==> provisioner: Creating vagrant_osie-work_1          ... done
   ==> provisioner: Creating vagrant_ubuntu-image-setup_1 ... done
   ==> provisioner: Creating vagrant_db_1                 ... done
   ==> provisioner: Creating vagrant_tls-gen_1            ... done
   ==> provisioner: Creating vagrant_registry-auth_1      ... done
   ==> provisioner: Creating vagrant_registry_1           ...
   ==> provisioner: Creating vagrant_registry_1           ... done
   ==> provisioner: Creating vagrant_tink-server-migration_1 ...
   ==> provisioner: Creating vagrant_tink-server-migration_1 ... done
   ==> provisioner: Creating vagrant_tink-server_1           ...
   ==> provisioner: Creating vagrant_images-to-local-registry_1 ...
   ==> provisioner: Creating vagrant_tink-server_1              ... done
   ==> provisioner: Creating vagrant_images-to-local-registry_1 ... done
   ==> provisioner: Creating vagrant_hegel_1                    ...
   ==> provisioner: Creating vagrant_boots_1                    ...
   ==> provisioner: Creating vagrant_create-tink-records_1      ...
   ==> provisioner: Creating vagrant_tink-cli_1                 ...
   ==> provisioner: Creating vagrant_registry-ca-crt-download_1 ...
   ==> provisioner: Creating vagrant_boots_1                    ... done
   ==> provisioner: Creating vagrant_tink-cli_1                 ... done
   ==> provisioner: Creating vagrant_hegel_1                    ... done
   ==> provisioner: Creating vagrant_create-tink-records_1      ... done
   ==> provisioner: Creating vagrant_registry-ca-crt-download_1 ... done
   ==> provisioner: Creating vagrant_osie-bootloader_1          ...
   ==> provisioner: Creating vagrant_osie-bootloader_1          ... done
   ```

   </details>

3. Start the machine to be provisioned

   ```bash
   vagrant up machine1
   # This will start a VM to pxe boot.
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'machine1' up with 'libvirt' provider...
   ==> machine1: Creating domain with the following settings...
   ==> machine1:  -- Name:              vagrant_machine1
   ==> machine1:  -- Domain type:       kvm
   ==> machine1:  -- Cpus:              2
   ==> machine1:  -- Feature:           acpi
   ==> machine1:  -- Feature:           apic
   ==> machine1:  -- Feature:           pae
   ==> machine1:  -- Memory:            4096M
   ==> machine1:  -- Management MAC:
   ==> machine1:  -- Loader:
   ==> machine1:  -- Nvram:
   ==> machine1:  -- Storage pool:      default
   ==> machine1:  -- Image:              (G)
   ==> machine1:  -- Volume Cache:      default
   ==> machine1:  -- Kernel:
   ==> machine1:  -- Initrd:
   ==> machine1:  -- Graphics Type:     vnc
   ==> machine1:  -- Graphics Port:     -1
   ==> machine1:  -- Graphics IP:       0.0.0.0
   ==> machine1:  -- Graphics Password: Not defined
   ==> machine1:  -- Video Type:        cirrus
   ==> machine1:  -- Video VRAM:        9216
   ==> machine1:  -- Sound Type:
   ==> machine1:  -- Keymap:            en-us
   ==> machine1:  -- TPM Path:
   ==> machine1:  -- Boot device:        hd
   ==> machine1:  -- Boot device:        network
   ==> machine1:  -- Disks:         vdb(qcow2,20G)
   ==> machine1:  -- Disk(vdb):     /var/lib/libvirt/images/vagrant_machine1-vdb.qcow2 Not created - using existed.
   ==> machine1:  -- INPUT:             type=mouse, bus=ps2
   ==> machine1: Starting domain.
   ```

   </details>

4. Watch the provision complete

   ```bash
   # log in to the provisioner
   vagrant ssh provisioner
   # watch the workflow events and status for workflow completion
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   wid=$(cat /vagrant/compose/create-tink-records/manifests/workflow/workflow_id.txt); watch -n1 "tink workflow events ${wid}; tink workflow state ${wid}"
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

5. Reboot the machine

   ```bash
   # crtl-c to exit the watch
   # exit the provisioner
   vagrant@ubuntu2004:~$ exit
   # restart machine1
   # the output will be the same as step 3, once the command line control is returned to you, you can move on to the next step.
   vagrant reload machine1
   ```

6. Login to the machine

   The machine has been provisioned with Ubuntu Focal.
   You can now SSH into the machine.

   ```bash
   vagrant ssh provisioner
   ssh tink@192.168.56.43 # user/pass => tink/tink
   ```
