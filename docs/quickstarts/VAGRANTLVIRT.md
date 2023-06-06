# Quick start guide for Vagrant and Libvirt

This option will stand up the provisioner in Libvirt using Vagrant.
This option will also show you how to create a machine to provision.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) is installed
- [Libvirt](https://ubuntu.com/server/docs/virtualization-libvirt) is installed
- Vagrant Libvirt plugin is installed: `vagrant plugin install vagrant-libvirt`

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/sandbox.git
   cd sandbox
   ```

2. Start the provisioner

   ```bash
   cd deploy/infrastructure/vagrant
   vagrant up
   # This process will take about 5-10 minutes depending on your internet connection.
   # Hook is about 400MB in size and the Ubuntu Focal image is about 500MB
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'provisioner' up with 'libvirt' provider...
   ==> provisioner: Checking if box 'generic/ubuntu2204' version '4.1.14' is up to date...
   ==> provisioner: Creating image (snapshot of base box volume).
   ==> provisioner: Creating domain with the following settings...
   ==> provisioner:  -- Name:              vagrant_provisioner
   ==> provisioner:  -- Description:       Source: /home/tink/repos/tinkerbell/sandbox/deploy/infrastructure/vagrant/Vagrantfile
   ==> provisioner:  -- Domain type:       kvm
   ==> provisioner:  -- Cpus:              2
   ==> provisioner:  -- Feature:           acpi
   ==> provisioner:  -- Feature:           apic
   ==> provisioner:  -- Feature:           pae
   ==> provisioner:  -- Clock offset:      utc
   ==> provisioner:  -- Memory:            2048M
   ==> provisioner:  -- Management MAC:
   ==> provisioner:  -- Loader:
   ==> provisioner:  -- Nvram:
   ==> provisioner:  -- Base box:          generic/ubuntu2204
   ==> provisioner:  -- Storage pool:      default
   ==> provisioner:  -- Image(vda):        /var/lib/libvirt/images/vagrant_provisioner.img, virtio, 128G
   ==> provisioner:  -- Disk driver opts:  cache='default'
   ==> provisioner:  -- Kernel:
   ==> provisioner:  -- Initrd:
   ==> provisioner:  -- Graphics Type:     vnc
   ==> provisioner:  -- Graphics Port:     -1
   ==> provisioner:  -- Graphics IP:       127.0.0.1
   ==> provisioner:  -- Graphics Password: Not defined
   ==> provisioner:  -- Video Type:        cirrus
   ==> provisioner:  -- Video VRAM:        256
   ==> provisioner:  -- Video 3D accel:    false
   ==> provisioner:  -- Sound Type:
   ==> provisioner:  -- Keymap:            en-us
   ==> provisioner:  -- TPM Backend:       passthrough
   ==> provisioner:  -- TPM Path:
   ==> provisioner:  -- INPUT:             type=mouse, bus=ps2
   ==> provisioner: Creating shared folders metadata...
   ==> provisioner: Starting domain.
   ==> provisioner: Waiting for domain to get an IP address...
   ==> provisioner: Waiting for machine to boot. This may take a few minutes...
       provisioner: SSH address: 192.168.121.254:22
       provisioner: SSH username: vagrant
       provisioner: SSH auth method: private key
       provisioner:
       provisioner: Vagrant insecure key detected. Vagrant will automatically replace
       provisioner: this with a newly generated keypair for better security.
       provisioner:
       provisioner: Inserting generated public key within guest...
       provisioner: Removing insecure key from the guest if it's present...
       provisioner: Key inserted! Disconnecting and reconnecting using new SSH key...
   ==> provisioner: Machine booted and ready!
   ==> provisioner: Rsyncing folder: /home/tink/repos/tinkerbell/sandbox/deploy/stack/compose/ => /sandbox/compose
   ==> provisioner: Running provisioner: shell...
       provisioner: Running: /tmp/vagrant-shell20221004-689177-1x7ep6c.sh
       provisioner: + main 192.168.56.4 192.168.56.43 08:00:27:9e:f5:3a /sandbox/compose
       provisioner: + local host_ip=192.168.56.4
       provisioner: + local worker_ip=192.168.56.43
       provisioner: + local worker_mac=08:00:27:9e:f5:3a
       provisioner: + local compose_dir=/sandbox/compose
       provisioner: + update_apt
       provisioner: + apt-get update
       provisioner: + DEBIAN_FRONTEND=noninteractive
       provisioner: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes update
       provisioner: Hit:1 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       provisioner: Get:2 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease [114 kB]
       provisioner: Get:3 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease [99.8 kB]
       provisioner: Get:4 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease [110 kB]
       provisioner: Get:5 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 Packages [611 kB]
       provisioner: Get:6 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main Translation-en [144 kB]
       provisioner: Get:7 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 c-n-f Metadata [8,788 B]
       provisioner: Get:8 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted amd64 Packages [344 kB]
       provisioner: Get:9 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted Translation-en [53.5 kB]
       provisioner: Get:10 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 Packages [425 kB]
       provisioner: Get:11 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe Translation-en [108 kB]
       provisioner: Get:12 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 Packages [6,752 B]
       provisioner: Get:13 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 c-n-f Metadata [352 B]
       provisioner: Get:14 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 Packages [352 kB]
       provisioner: Get:15 https://mirrors.edge.kernel.org/ubuntu jammy-security/main Translation-en [81.8 kB]
       provisioner: Get:16 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted amd64 Packages [308 kB]
       provisioner: Get:17 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted Translation-en [47.8 kB]
       provisioner: Get:18 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 Packages [287 kB]
       provisioner: Get:19 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe Translation-en [63.2 kB]
       provisioner: Fetched 3,164 kB in 7s (425 kB/s)
       provisioner: Reading package lists...
       provisioner: + install_docker
       provisioner: + curl -fsSL https://download.docker.com/linux/ubuntu/gpg
       provisioner: + sudo apt-key add -
       provisioner: Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
       provisioner: OK
       provisioner: ++ lsb_release -cs
       provisioner: + add-apt-repository 'deb https://download.docker.com/linux/ubuntu jammy stable'
       provisioner: Hit:1 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       provisioner: Hit:2 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease
       provisioner: Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease
       provisioner: Get:4 https://download.docker.com/linux/ubuntu jammy InRelease [48.9 kB]
       provisioner: Hit:5 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease
       provisioner: Get:6 https://download.docker.com/linux/ubuntu jammy/stable amd64 Packages [7,065 B]
       provisioner: Fetched 55.9 kB in 1s (94.7 kB/s)
       provisioner: Reading package lists...
       provisioner: W: https://download.docker.com/linux/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
       provisioner: Repository: 'deb https://download.docker.com/linux/ubuntu jammy stable'
       provisioner: Description:
       provisioner: Archive for codename: jammy components: stable
       provisioner: More info: https://download.docker.com/linux/ubuntu
       provisioner: Adding repository.
       provisioner: Adding deb entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
       provisioner: Adding disabled deb-src entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
       provisioner: + update_apt
       provisioner: + apt-get update
       provisioner: + DEBIAN_FRONTEND=noninteractive
       provisioner: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes update
       provisioner: Hit:1 https://download.docker.com/linux/ubuntu jammy InRelease
       provisioner: Hit:2 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       provisioner: Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease
       provisioner: Hit:4 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease
       provisioner: Hit:5 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease
       provisioner: Reading package lists...
       provisioner: W: https://download.docker.com/linux/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
       provisioner: + apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli docker-compose-plugin
       provisioner: + DEBIAN_FRONTEND=noninteractive
       provisioner: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes install --no-install-recommends containerd.io docker-ce docker-ce-cli docker-compose-plugin
       provisioner: Reading package lists...
       provisioner: Building dependency tree...
       provisioner: Reading state information...
       provisioner: Suggested packages:
       provisioner:   aufs-tools cgroupfs-mount | cgroup-lite
       provisioner: Recommended packages:
       provisioner:   docker-ce-rootless-extras libltdl7 pigz docker-scan-plugin
       provisioner: The following NEW packages will be installed:
       provisioner:   containerd.io docker-ce docker-ce-cli docker-compose-plugin
       provisioner: 0 upgraded, 4 newly installed, 0 to remove and 4 not upgraded.
       provisioner: Need to get 96.7 MB of archives.
       provisioner: After this operation, 390 MB of additional disk space will be used.
       provisioner: Get:1 https://download.docker.com/linux/ubuntu jammy/stable amd64 containerd.io amd64 1.6.8-1 [28.1 MB]
       provisioner: Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce-cli amd64 5:20.10.18~3-0~ubuntu-jammy [41.5 MB]
       provisioner: Get:3 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce amd64 5:20.10.18~3-0~ubuntu-jammy [20.4 MB]
       provisioner: Get:4 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-compose-plugin amd64 2.10.2~ubuntu-jammy [6,693 kB]
       provisioner: Fetched 96.7 MB in 3s (36.5 MB/s)
       provisioner: Selecting previously unselected package containerd.io.
   (Reading database ... 75347 files and directories currently installed.)
       provisioner: Preparing to unpack .../containerd.io_1.6.8-1_amd64.deb ...
       provisioner: Unpacking containerd.io (1.6.8-1) ...
       provisioner: Selecting previously unselected package docker-ce-cli.
       provisioner: Preparing to unpack .../docker-ce-cli_5%3a20.10.18~3-0~ubuntu-jammy_amd64.deb ...
       provisioner: Unpacking docker-ce-cli (5:20.10.18~3-0~ubuntu-jammy) ...
       provisioner: Selecting previously unselected package docker-ce.
       provisioner: Preparing to unpack .../docker-ce_5%3a20.10.18~3-0~ubuntu-jammy_amd64.deb ...
       provisioner: Unpacking docker-ce (5:20.10.18~3-0~ubuntu-jammy) ...
       provisioner: Selecting previously unselected package docker-compose-plugin.
       provisioner: Preparing to unpack .../docker-compose-plugin_2.10.2~ubuntu-jammy_amd64.deb ...
       provisioner: Unpacking docker-compose-plugin (2.10.2~ubuntu-jammy) ...
       provisioner: Setting up containerd.io (1.6.8-1) ...
       provisioner: Created symlink /etc/systemd/system/multi-user.target.wants/containerd.service → /lib/systemd/system/containerd.service.
       provisioner: Setting up docker-compose-plugin (2.10.2~ubuntu-jammy) ...
       provisioner: Setting up docker-ce-cli (5:20.10.18~3-0~ubuntu-jammy) ...
       provisioner: Setting up docker-ce (5:20.10.18~3-0~ubuntu-jammy) ...
       provisioner: Created symlink /etc/systemd/system/multi-user.target.wants/docker.service → /lib/systemd/system/docker.service.
       provisioner: Created symlink /etc/systemd/system/sockets.target.wants/docker.socket → /lib/systemd/system/docker.socket.
       provisioner: Processing triggers for man-db (2.10.2-1) ...
       provisioner: NEEDRESTART-VER: 3.5
       provisioner: NEEDRESTART-KCUR: 5.15.0-48-generic
       provisioner: NEEDRESTART-KEXP: 5.15.0-48-generic
       provisioner: NEEDRESTART-KSTA: 1
       provisioner: + gpasswd -a vagrant docker
       provisioner: Adding user vagrant to group docker
       provisioner: + install_kubectl
       provisioner: + curl -LO https://dl.k8s.io/v1.25.2/bin/linux/amd64/kubectl
       provisioner:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
       provisioner:                                  Dload  Upload   Total   Spent    Left  Speed
   100   138  100   138    0     0    537      0 --:--:-- --:--:-- --:--:--   536
   100 42.9M  100 42.9M    0     0  29.3M      0  0:00:01  0:00:01 --:--:-- 61.2M
       provisioner: + chmod +x ./kubectl
       provisioner: + mv ./kubectl /usr/local/bin/kubectl
       provisioner: + setup_layer2_network 192.168.56.4
       provisioner: + local host_ip=192.168.56.4
       provisioner: + ip addr show dev eth1
       provisioner: + grep -q 192.168.56.4
       provisioner: + ip addr add 192.168.56.4/24 dev eth1
       provisioner: + ip link set dev eth1 up
       provisioner: + setup_compose_env_overrides 192.168.56.4 192.168.56.43 08:00:27:9e:f5:3a /sandbox/compose
       provisioner: + local host_ip=192.168.56.4
       provisioner: + local worker_ip=192.168.56.43
       provisioner: + local worker_mac=08:00:27:9e:f5:3a
       provisioner: + local compose_dir=/sandbox/compose
       provisioner: + local disk_device
       provisioner: + disk_device=/dev/sda
       provisioner: + lsblk
       provisioner: + grep -q vda
       provisioner: + disk_device=/dev/vda
       provisioner: + [[ /sandbox/compose == *\p\o\s\t\g\r\e\s* ]]
       provisioner: + readarray -t lines
       provisioner: + for line in "${lines[@]}"
       provisioner: + grep -q 'TINKERBELL_HOST_IP="192.168.56.4"' /sandbox/compose/.env
       provisioner: + echo 'TINKERBELL_HOST_IP="192.168.56.4"'
       provisioner: + for line in "${lines[@]}"
       provisioner: + grep -q 'TINKERBELL_CLIENT_IP="192.168.56.43"' /sandbox/compose/.env
       provisioner: + echo 'TINKERBELL_CLIENT_IP="192.168.56.43"'
       provisioner: + for line in "${lines[@]}"
       provisioner: + grep -q 'TINKERBELL_CLIENT_MAC="08:00:27:9e:f5:3a"' /sandbox/compose/.env
       provisioner: + echo 'TINKERBELL_CLIENT_MAC="08:00:27:9e:f5:3a"'
       provisioner: + for line in "${lines[@]}"
       provisioner: + grep -q 'DISK_DEVICE="/dev/vda"' /sandbox/compose/.env
       provisioner: + echo 'DISK_DEVICE="/dev/vda"'
       provisioner: + docker compose -f /sandbox/compose/docker-compose.yml up -d
       provisioner: manifest-update Pulling
       provisioner: rufio Pulling
       provisioner: manifest-apply Pulling
       provisioner: boots Pulling
       provisioner: fetch-and-convert-ubuntu-img Pulling
       provisioner: rufio-crds-apply Pulling
       provisioner: fetch-osie Pulling
       provisioner: tink-controller Pulling
       provisioner: tink-crds-apply Pulling
       provisioner: k3s Pulling
       provisioner: hegel Pulling
       provisioner: tink-server Pulling
       provisioner: web-assets-server Pulling
       provisioner: web-assets-server Pulled
       provisioner: Network compose_default  Creating
       provisioner: Network compose_default  Created
       provisioner: Volume "compose_k3s-server"  Creating
       provisioner: Volume "compose_k3s-server"  Created
       provisioner: Container compose-k3s-1  Creating
       provisioner: Container compose-fetch-osie-1  Creating
       provisioner: Container compose-manifest-update-1  Creating
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Creating
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Created
       provisioner: Container compose-manifest-update-1  Created
       provisioner: Container compose-fetch-osie-1  Created
       provisioner: Container compose-web-assets-server-1  Creating
       provisioner: Container compose-k3s-1  Created
       provisioner: Container compose-tink-crds-apply-1  Creating
       provisioner: Container compose-rufio-crds-apply-1  Creating
       provisioner: Container compose-tink-crds-apply-1  Created
       provisioner: Container compose-manifest-apply-1  Creating
       provisioner: Container compose-hegel-1  Creating
       provisioner: Container compose-tink-server-1  Creating
       provisioner: Container compose-boots-1  Creating
       provisioner: Container compose-tink-controller-1  Creating
       provisioner: Container compose-web-assets-server-1  Created
       provisioner: Container compose-rufio-crds-apply-1  Created
       provisioner: Container compose-rufio-1  Creating
       provisioner: Container compose-boots-1  Created
       provisioner: Container compose-hegel-1  Created
       provisioner: Container compose-manifest-apply-1  Created
       provisioner: Container compose-rufio-1  Created
       provisioner: Container compose-tink-controller-1  Created
       provisioner: Container compose-tink-server-1  Created
       provisioner: Container compose-manifest-update-1  Starting
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Starting
       provisioner: Container compose-fetch-osie-1  Starting
       provisioner: Container compose-k3s-1  Starting
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Started
       provisioner: Container compose-manifest-update-1  Started
       provisioner: Container compose-k3s-1  Started
       provisioner: Container compose-k3s-1  Waiting
       provisioner: Container compose-k3s-1  Waiting
       provisioner: Container compose-fetch-osie-1  Started
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Waiting
       provisioner: Container compose-fetch-osie-1  Waiting
       provisioner: Container compose-fetch-and-convert-ubuntu-img-1  Exited
       provisioner: Container compose-fetch-osie-1  Exited
       provisioner: Container compose-web-assets-server-1  Starting
       provisioner: Container compose-web-assets-server-1  Started
       provisioner: Container compose-k3s-1  Healthy
       provisioner: Container compose-k3s-1  Healthy
       provisioner: Container compose-rufio-crds-apply-1  Starting
       provisioner: Container compose-tink-crds-apply-1  Starting
       provisioner: Container compose-rufio-crds-apply-1  Started
       provisioner: Container compose-rufio-crds-apply-1  Waiting
       provisioner: Container compose-tink-crds-apply-1  Started
       provisioner: Container compose-tink-crds-apply-1  Waiting
       provisioner: Container compose-tink-crds-apply-1  Waiting
       provisioner: Container compose-tink-crds-apply-1  Waiting
       provisioner: Container compose-tink-crds-apply-1  Waiting
       provisioner: Container compose-tink-crds-apply-1  Waiting
       provisioner: Container compose-rufio-crds-apply-1  Exited
       provisioner: Container compose-rufio-1  Starting
       provisioner: Container compose-rufio-1  Started
       provisioner: Container compose-tink-crds-apply-1  Exited
       provisioner: Container compose-boots-1  Starting
       provisioner: Container compose-tink-crds-apply-1  Exited
       provisioner: Container compose-tink-crds-apply-1  Exited
       provisioner: Container compose-tink-crds-apply-1  Exited
       provisioner: Container compose-tink-crds-apply-1  Exited
       provisioner: Container compose-manifest-apply-1  Starting
       provisioner: Container compose-tink-server-1  Starting
       provisioner: Container compose-hegel-1  Starting
       provisioner: Container compose-tink-controller-1  Starting
       provisioner: Container compose-boots-1  Started
       provisioner: Container compose-tink-server-1  Started
       provisioner: Container compose-tink-controller-1  Started
       provisioner: Container compose-manifest-apply-1  Started
       provisioner: Container compose-hegel-1  Started
       provisioner: + create_tink_helper_script /sandbox/compose
       provisioner: + local compose_dir=/sandbox/compose
       provisioner: + mkdir -p /home/vagrant/.local/bin
       provisioner: + cat
       provisioner: + chmod +x /home/vagrant/.local/bin/tink
       provisioner: + tweak_bash_interactive_settings /sandbox/compose
       provisioner: + local compose_dir=/sandbox/compose
       provisioner: + grep -q 'cd /sandbox/compose' /home/vagrant/.bashrc
       provisioner: + echo 'cd /sandbox/compose'
       provisioner: + echo 'export KUBECONFIG=/sandbox/compose/state/kube/kubeconfig.yaml'
       provisioner: + readarray -t aliases
       provisioner: + for alias in "${aliases[@]}"
       provisioner: + grep -q 'dc="docker compose"' /home/vagrant/.bash_aliases
       provisioner: grep: /home/vagrant/.bash_aliases: No such file or directory
       provisioner: + echo 'alias dc="docker compose"'
       provisioner: all done!
       provisioner: + echo 'all done!'
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

   # watch for the workflow to complete
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   kubectl get -n tink-system workflow sandbox-workflow --watch
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

5. Reboot the machine

   ```bash
   # crtl-c to exit the watch
   # exit the provisioner
   vagrant@ubuntu2204:~$ exit
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
