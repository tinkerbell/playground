# Quick start guide for Vagrant and Libvirt

This option will create the stack in a Libvirt VM using Vagrant.
This option will also create a VM and provision an OS onto it.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) is installed
- [Libvirt](https://ubuntu.com/server/docs/virtualization-libvirt) is installed
- Vagrant Libvirt plugin is installed: `vagrant plugin install vagrant-libvirt`
- A connection to the public internet (air gapped and proxied environments are not supported)

## Steps

1. Clone this repository

   ```bash
   git clone https://github.com/tinkerbell/playground.git
   cd playground
   ```

1. Start the stack

   ```bash
   cd stack/vagrant
   vagrant up
   # This process will take about 5-10 minutes depending on your internet connection.
   # Hook is about 400MB in size and the Ubuntu jammy image is about 500MB
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'stack' up with 'libvirt' provider...
   ==> stack: Checking if box 'generic/ubuntu2204' version '4.3.4' is up to date...
   ==> stack: Creating image (snapshot of base box volume).
   ==> stack: Creating domain with the following settings...
   ==> stack:  -- Name:              vagrant_stack
   ==> stack:  -- Description:       Source: /home/tink/repos/tinkerbell/playground/vagrant/Vagrantfile
   ==> stack:  -- Domain type:       kvm
   ==> stack:  -- Cpus:              2
   ==> stack:  -- Feature:           acpi
   ==> stack:  -- Feature:           apic
   ==> stack:  -- Feature:           pae
   ==> stack:  -- Clock offset:      utc
   ==> stack:  -- Memory:            2048M
   ==> stack:  -- Base box:          generic/ubuntu2204
   ==> stack:  -- Storage pool:      default
   ==> stack:  -- Image(vda):        /var/lib/libvirt/images/vagrant_stack.img, virtio, 128G
   ==> stack:  -- Disk driver opts:  cache='default'
   ==> stack:  -- Graphics Type:     vnc
   ==> stack:  -- Video Type:        cirrus
   ==> stack:  -- Video VRAM:        256
   ==> stack:  -- Video 3D accel:    false
   ==> stack:  -- Keymap:            en-us
   ==> stack:  -- TPM Backend:       passthrough
   ==> stack:  -- INPUT:             type=mouse, bus=ps2
   ==> stack: Creating shared folders metadata...
   ==> stack: Starting domain.
   ==> stack: Domain launching with graphics connection settings...
   ==> stack:  -- Graphics Port:      5900
   ==> stack:  -- Graphics IP:        127.0.0.1
   ==> stack:  -- Graphics Password:  Not defined
   ==> stack:  -- Graphics Websocket: 5700
   ==> stack: Waiting for domain to get an IP address...
   ==> stack: Waiting for machine to boot. This may take a few minutes...
       stack: SSH address: 192.168.121.127:22
       stack: SSH username: vagrant
       stack: SSH auth method: private key
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack: Warning: Connection refused. Retrying...
       stack:
       stack: Vagrant insecure key detected. Vagrant will automatically replace
       stack: this with a newly generated keypair for better security.
       stack:
       stack: Inserting generated public key within guest...
       stack: Removing insecure key from the guest if it's present...
       stack: Key inserted! Disconnecting and reconnecting using new SSH key...
   ==> stack: Machine booted and ready!
   ==> stack: Rsyncing folder: /home/tink/repos/tinkerbell/playground/vagrant/ => /playground/stack
   ==> stack: Configuring and enabling network interfaces...
   ==> stack: Running provisioner: shell...
       stack: Running: /tmp/vagrant-shell20231031-285946-1krhzm0.sh
       stack: + main 192.168.56.4 192.168.56.43 08:00:27:9e:f5:3a /playground/stack/ 192.168.56.5 0.4.2 eth1 1.28.3 v5.6.0 ''
       stack: + local host_ip=192.168.56.4
       stack: + local worker_ip=192.168.56.43
       stack: + local worker_mac=08:00:27:9e:f5:3a
       stack: + local manifests_dir=/playground/stack/
       stack: + local loadbalancer_ip=192.168.56.5
       stack: + local helm_chart_version=0.4.2
       stack: + local loadbalancer_interface=eth1
       stack: + local kubectl_version=1.28.3
       stack: + local k3d_version=v5.6.0
       stack: + update_apt
       stack: + apt-get update
       stack: + DEBIAN_FRONTEND=noninteractive
       stack: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes update
       stack: Hit:1 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       stack: Get:2 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease [119 kB]
       stack: Get:3 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease [109 kB]
       stack: Get:4 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease [110 kB]
       stack: Get:5 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 Packages [1,148 kB]
       stack: Get:6 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main Translation-en [245 kB]
       stack: Get:7 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 c-n-f Metadata [16.1 kB]
       stack: Get:8 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted amd64 Packages [1,103 kB]
       stack: Get:9 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted Translation-en [179 kB]
       stack: Get:10 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted amd64 c-n-f Metadata [536 B]
       stack: Get:11 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 Packages [998 kB]
       stack: Get:12 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe Translation-en [218 kB]
       stack: Get:13 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 c-n-f Metadata [22.0 kB]
       stack: Get:14 https://mirrors.edge.kernel.org/ubuntu jammy-backports/main amd64 Packages [64.2 kB]
       stack: Get:15 https://mirrors.edge.kernel.org/ubuntu jammy-backports/main amd64 c-n-f Metadata [388 B]
       stack: Get:16 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 Packages [27.8 kB]
       stack: Get:17 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 c-n-f Metadata [644 B]
       stack: Get:18 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 Packages [938 kB]
       stack: Get:19 https://mirrors.edge.kernel.org/ubuntu jammy-security/main Translation-en [185 kB]
       stack: Get:20 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 c-n-f Metadata [11.4 kB]
       stack: Get:21 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted amd64 Packages [1,079 kB]
       stack: Get:22 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted Translation-en [175 kB]
       stack: Get:23 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted amd64 c-n-f Metadata [536 B]
       stack: Get:24 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 Packages [796 kB]
       stack: Get:25 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe Translation-en [146 kB]
       stack: Get:26 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 c-n-f Metadata [16.8 kB]
       stack: Fetched 7,709 kB in 2s (4,266 kB/s)
       stack: Reading package lists...
       stack: + install_docker
       stack: + curl -fsSL https://download.docker.com/linux/ubuntu/gpg
       stack: + sudo apt-key add -
       stack: Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
       stack: OK
       stack: ++ lsb_release -cs
       stack: + add-apt-repository 'deb https://download.docker.com/linux/ubuntu jammy stable'
       stack: Get:1 https://download.docker.com/linux/ubuntu jammy InRelease [48.8 kB]
       stack: Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 Packages [22.7 kB]
       stack: Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       stack: Hit:4 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease
       stack: Hit:5 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease
       stack: Hit:6 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease
       stack: Fetched 71.5 kB in 6s (11.8 kB/s)
       stack: Reading package lists...
       stack: W: https://download.docker.com/linux/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
       stack: Repository: 'deb https://download.docker.com/linux/ubuntu jammy stable'
       stack: Description:
       stack: Archive for codename: jammy components: stable
       stack: More info: https://download.docker.com/linux/ubuntu
       stack: Adding repository.
       stack: Adding deb entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
       stack: Adding disabled deb-src entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
       stack: + update_apt
       stack: + apt-get update
       stack: + DEBIAN_FRONTEND=noninteractive
       stack: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes update
       stack: Hit:1 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       stack: Hit:2 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease
       stack: Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease
       stack: Hit:4 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease
       stack: Hit:5 https://download.docker.com/linux/ubuntu jammy InRelease
       stack: Reading package lists...
       stack: W: https://download.docker.com/linux/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
       stack: + apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli
       stack: + DEBIAN_FRONTEND=noninteractive
       stack: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes install --no-install-recommends containerd.io docker-ce docker-ce-cli
       stack: Reading package lists...
       stack: Building dependency tree...
       stack: Reading state information...
       stack: Suggested packages:
       stack:   aufs-tools cgroupfs-mount | cgroup-lite
       stack: Recommended packages:
       stack:   docker-ce-rootless-extras libltdl7 pigz docker-buildx-plugin
       stack:   docker-compose-plugin
       stack: The following NEW packages will be installed:
       stack:   containerd.io docker-ce docker-ce-cli
       stack: 0 upgraded, 3 newly installed, 0 to remove and 29 not upgraded.
       stack: Need to get 64.5 MB of archives.
       stack: After this operation, 249 MB of additional disk space will be used.
       stack: Get:1 https://download.docker.com/linux/ubuntu jammy/stable amd64 containerd.io amd64 1.6.24-1 [28.6 MB]
       stack: Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce-cli amd64 5:24.0.7-1~ubuntu.22.04~jammy [13.3 MB]
       stack: Get:3 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce amd64 5:24.0.7-1~ubuntu.22.04~jammy [22.6 MB]
       stack: Fetched 64.5 MB in 1s (77.3 MB/s)
       stack: Selecting previously unselected package containerd.io.
   (Reading database ... 76025 files and directories currently installed.)
       stack: Preparing to unpack .../containerd.io_1.6.24-1_amd64.deb ...
       stack: Unpacking containerd.io (1.6.24-1) ...
       stack: Selecting previously unselected package docker-ce-cli.
       stack: Preparing to unpack .../docker-ce-cli_5%3a24.0.7-1~ubuntu.22.04~jammy_amd64.deb ...
       stack: Unpacking docker-ce-cli (5:24.0.7-1~ubuntu.22.04~jammy) ...
       stack: Selecting previously unselected package docker-ce.
       stack: Preparing to unpack .../docker-ce_5%3a24.0.7-1~ubuntu.22.04~jammy_amd64.deb ...
       stack: Unpacking docker-ce (5:24.0.7-1~ubuntu.22.04~jammy) ...
       stack: Setting up containerd.io (1.6.24-1) ...
       stack: Created symlink /etc/systemd/system/multi-user.target.wants/containerd.service → /lib/systemd/system/containerd.service.
       stack: Setting up docker-ce-cli (5:24.0.7-1~ubuntu.22.04~jammy) ...
       stack: Setting up docker-ce (5:24.0.7-1~ubuntu.22.04~jammy) ...
       stack: Created symlink /etc/systemd/system/multi-user.target.wants/docker.service → /lib/systemd/system/docker.service.
       stack: Created symlink /etc/systemd/system/sockets.target.wants/docker.socket → /lib/systemd/system/docker.socket.
       stack: Processing triggers for man-db (2.10.2-1) ...
       stack: NEEDRESTART-VER: 3.5
       stack: NEEDRESTART-KCUR: 5.15.0-86-generic
       stack: NEEDRESTART-KEXP: 5.15.0-86-generic
       stack: NEEDRESTART-KSTA: 1
       stack: + gpasswd -a vagrant docker
       stack: Adding user vagrant to group docker
       stack: + sudo ethtool -K eth1 tx off sg off tso off
       stack: Actual changes:
       stack: tx-scatter-gather: off
       stack: tx-checksum-ip-generic: off
       stack: tx-generic-segmentation: off [not requested]
       stack: tx-tcp-segmentation: off
       stack: tx-tcp-ecn-segmentation: off
       stack: tx-tcp6-segmentation: off
       stack: + install_kubectl 1.28.3
       stack: + local kubectl_version=1.28.3
       stack: + curl -LO https://dl.k8s.io/v1.28.3/bin/linux/amd64/kubectl
       stack:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
       stack:                                  Dload  Upload   Total   Spent    Left  Speed
   100   138  100   138    0     0    410      0 --:--:-- --:--:-- --:--:--   410
   100 47.5M  100 47.5M    0     0  24.8M      0  0:00:01  0:00:01 --:--:-- 37.9M
       stack: + chmod +x ./kubectl
       stack: + mv ./kubectl /usr/local/bin/kubectl
       stack: + run_helm 192.168.56.4 192.168.56.43 08:00:27:9e:f5:3a /playground/stack/ 192.168.56.5 0.4.2 eth1 v5.6.0
       stack: + local host_ip=192.168.56.4
       stack: + local worker_ip=192.168.56.43
       stack: + local worker_mac=08:00:27:9e:f5:3a
       stack: + local manifests_dir=/playground/stack/
       stack: + local loadbalancer_ip=192.168.56.5
       stack: + local helm_chart_version=0.4.2
       stack: + local loadbalancer_interface=eth1
       stack: + local k3d_version=v5.6.0
       stack: + local namespace=tink-system
       stack: + install_k3d v5.6.0
       stack: + local k3d_Version=v5.6.0
       stack: + wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh
       stack: + TAG=v5.6.0
       stack: + bash
       stack: Preparing to install k3d into /usr/local/bin
       stack: k3d installed into /usr/local/bin/k3d
       stack: Run 'k3d --help' to see what you can do with it.
       stack: + start_k3d
       stack: + k3d cluster create --network host --no-lb --k3s-arg --disable=traefik,servicelb --k3s-arg --kube-apiserver-arg=feature-gates=MixedProtocolLBService=true --host-pid-mode
       stack: INFO[0000] [SimpleConfig] Hostnetwork selected - disabling injection of docker host into the cluster, server load balancer and setting the api port to the k3s default
       stack: WARN[0000] No node filter specified
       stack: WARN[0000] No node filter specified
       stack: INFO[0000] [ClusterConfig] Hostnetwork selected - disabling injection of docker host into the cluster, server load balancer and setting the api port to the k3s default
       stack: INFO[0000] Prep: Network
       stack: INFO[0000] Re-using existing network 'host' (2ecf52da28c15a6bbe026b5e71f3af288fefbbb222b2762bafc29e9b1791ff8b)
       stack: INFO[0000] Created image volume k3d-k3s-default-images
       stack: INFO[0000] Starting new tools node...
       stack: INFO[0001] Creating node 'k3d-k3s-default-server-0'
       stack: INFO[0001] Pulling image 'ghcr.io/k3d-io/k3d-tools:5.6.0'
       stack: INFO[0002] Pulling image 'docker.io/rancher/k3s:v1.27.4-k3s1'
       stack: INFO[0003] Starting Node 'k3d-k3s-default-tools'
       stack: INFO[0010] Using the k3d-tools node to gather environment information
       stack: INFO[0011] Starting cluster 'k3s-default'
       stack: INFO[0011] Starting servers...
       stack: INFO[0011] Starting Node 'k3d-k3s-default-server-0'
       stack: INFO[0014] All agents already running.
       stack: INFO[0014] All helpers already running.
       stack: INFO[0014] Cluster 'k3s-default' created successfully!
       stack: INFO[0014] You can now use it like this:
       stack: kubectl cluster-info
       stack: + mkdir -p /root/.kube/
       stack: + k3d kubeconfig get -a
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: error: no matching resources found
       stack: + sleep 1
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: error: no matching resources found
       stack: + sleep 1
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: error: no matching resources found
       stack: + sleep 1
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: error: no matching resources found
       stack: + sleep 1
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: error: no matching resources found
       stack: + sleep 1
       stack: + kubectl wait --for=condition=Ready nodes --all --timeout=600s
       stack: node/k3d-k3s-default-server-0 condition met
       stack: + install_helm
       stack: + helm_ver=v3.9.4
       stack: + curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
       stack: + chmod 700 get_helm.sh
       stack: + ./get_helm.sh --version v3.9.4
       stack: Downloading https://get.helm.sh/helm-v3.9.4-linux-amd64.tar.gz
       stack: Verifying checksum... Done.
       stack: Preparing to install helm into /usr/local/bin
       stack: helm installed into /usr/local/bin/helm
       stack: + helm_install_tink_stack tink-system 0.4.2 eth1 192.168.56.5
       stack: + local namespace=tink-system
       stack: + local version=0.4.2
       stack: + local interface=eth1
       stack: + local loadbalancer_ip=192.168.56.5
       stack: + trusted_proxies=
       stack: + '[' '' '!=' '' ']'
       stack: ++ kubectl get nodes -o 'jsonpath={.items[*].spec.podCIDR}'
       stack: ++ tr ' ' ,
       stack: + trusted_proxies=
       stack: + '[' '' '!=' '' ']'
       stack: ++ kubectl get nodes -o 'jsonpath={.items[*].spec.podCIDR}'
       stack: ++ tr ' ' ,
       stack: + trusted_proxies=10.42.0.0/24
       stack: + '[' 10.42.0.0/24 '!=' '' ']'
       stack: + helm install tink-stack oci://ghcr.io/tinkerbell/charts/stack --version 0.4.2 --create-namespace --namespace tink-system --wait --set 'smee.trustedProxies={10.42.0.0/24}' --set 'hegel.trustedProxies={10.42.0.0/24}' --set stack.kubevip.interface=eth1 --set stack.relay.sourceInterface=eth1 --set stack.loadBalancerIP=192.168.56.5 --set smee.publicIP=192.168.56.5
       stack: NAME: tink-stack
       stack: LAST DEPLOYED: Tue Oct 31 21:56:58 2023
       stack: NAMESPACE: tink-system
       stack: STATUS: deployed
       stack: REVISION: 1
       stack: TEST SUITE: None
       stack: + apply_manifests 192.168.56.43 08:00:27:9e:f5:3a /playground/stack/ 192.168.56.5 tink-system
       stack: + local worker_ip=192.168.56.43
       stack: + local worker_mac=08:00:27:9e:f5:3a
       stack: + local manifests_dir=/playground/stack/
       stack: + local host_ip=192.168.56.5
       stack: + local namespace=tink-system
       stack: + disk_device=/dev/sda
       stack: + lsblk
       stack: + grep -q vda
       stack: + disk_device=/dev/vda
       stack: + export DISK_DEVICE=/dev/vda
       stack: + DISK_DEVICE=/dev/vda
       stack: + export TINKERBELL_CLIENT_IP=192.168.56.43
       stack: + TINKERBELL_CLIENT_IP=192.168.56.43
       stack: + export TINKERBELL_CLIENT_MAC=08:00:27:9e:f5:3a
       stack: + TINKERBELL_CLIENT_MAC=08:00:27:9e:f5:3a
       stack: + export TINKERBELL_HOST_IP=192.168.56.5
       stack: + TINKERBELL_HOST_IP=192.168.56.5
       stack: + for i in "$manifests_dir"/{hardware.yaml,template.yaml,workflow.yaml}
       stack: + envsubst
       stack: + echo -e ---
       stack: + for i in "$manifests_dir"/{hardware.yaml,template.yaml,workflow.yaml}
       stack: + envsubst
       stack: + echo -e ---
       stack: + for i in "$manifests_dir"/{hardware.yaml,template.yaml,workflow.yaml}
       stack: + envsubst
       stack: + echo -e ---
       stack: + kubectl apply -n tink-system -f /tmp/manifests.yaml
       stack: hardware.tinkerbell.org/machine1 created
       stack: template.tinkerbell.org/ubuntu-jammy created
       stack: workflow.tinkerbell.org/playground-workflow created
       stack: + kubectl apply -n tink-system -f /playground/stack//ubuntu-download.yaml
       stack: configmap/download-image created
       stack: job.batch/download-ubuntu-jammy created
       stack: + kubectl_for_vagrant_user
       stack: + runuser -l vagrant -c 'mkdir -p ~/.kube/'
       stack: + runuser -l vagrant -c 'k3d kubeconfig get -a > ~/.kube/config'
       stack: + chmod 600 /home/vagrant/.kube/config
       stack: + echo 'export KUBECONFIG="/home/vagrant/.kube/config"'
       stack: all done!
       stack: + echo 'all done!'
   ```

   </details>

1. Wait for Ubuntu image and HookOS to be downloaded

   ```bash
   vagrant ssh stack
   kubectl get jobs -n tink-system --watch
   kubectl get pods -n tink-system --watch
   exit
   # There is one Kubernetes job to download the Ubuntu image and an init
   # container in the hookos pod downloading the HookOS artifacts.
   # Once the job is completed and the hookos pod is in running state, exit
   # the stack VM.
   ```

   <details>
   <summary>example output</summary>

   Ubuntu image download:
   ```bash
   kubectl get jobs -n tink-system --watch
   NAME                    COMPLETIONS   DURATION   AGE
   download-ubuntu-jammy   0/1           49s        49s
   download-ubuntu-jammy   0/1           70s        70s
   download-ubuntu-jammy   0/1           72s        72s
   download-ubuntu-jammy   1/1           72s        72s
   ```
   HookOS pod:
   ```bash
   kubectl get pods -n tink-system --watch
   NAME                          READY   STATUS      RESTARTS   AGE
   download-ubuntu-jammy-2w4wn   0/1     Completed   0          38m
   hookos-58b848576b-hzsv4       2/2     Running     0          38m
   kube-vip-kzr6k                1/1     Running     0          38m
   tinkerbell-94b85bb97-tkr9q    1/1     Running     0          38m
   ```

   </details>

1. Start the machine to be provisioned

   ```bash
   vagrant up machine1
   # This will start a VM to pxe boot.
   # The `vagrant up machine1` command will exit quickly and show the following message. This is expected.
   # Once the command line control is returned to you, you can move on to the next step.
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'machine1' up with 'libvirt' provider...
   ==> machine1: Creating domain with the following settings...
   ==> machine1:  -- Name:              vagrant_machine1
   ==> machine1:  -- Description:       Source: /home/tink/repos/tinkerbell/playground/vagrant/Vagrantfile
   ==> machine1:  -- Domain type:       kvm
   ==> machine1:  -- Cpus:              2
   ==> machine1:  -- Feature:           acpi
   ==> machine1:  -- Feature:           apic
   ==> machine1:  -- Feature:           pae
   ==> machine1:  -- Clock offset:      utc
   ==> machine1:  -- Memory:            4096M
   ==> machine1:  -- Storage pool:      default
   ==> machine1:  -- Disk driver opts:  cache='default'
   ==> machine1:  -- Graphics Type:     vnc
   ==> machine1:  -- Video Type:        cirrus
   ==> machine1:  -- Video VRAM:        16384
   ==> machine1:  -- Video 3D accel:    false
   ==> machine1:  -- Keymap:            en-us
   ==> machine1:  -- TPM Backend:       passthrough
   ==> machine1:  -- Boot device:        hd
   ==> machine1:  -- Boot device:        network
   ==> machine1:  -- Disk(vda):         /var/lib/libvirt/images/vagrant_machine1-vda.qcow2, virtio, 20G
   ==> machine1:  -- INPUT:             type=mouse, bus=ps2
   ==> machine1: Starting domain.
   ==> machine1: Domain launching with graphics connection settings...
   ==> machine1:  -- Graphics Port:      5901
   ==> machine1:  -- Graphics IP:        0.0.0.0
   ==> machine1:  -- Graphics Password:  Not defined
   ==> machine1:  -- Graphics Websocket: 5701
   ```

   </details>

1. Watch the provision complete

   ```bash
   # log in to the stack VM
   vagrant ssh stack

   # watch for the workflow to complete
   # once the workflow is complete (see the expected output below for completion), move on to the next step
   kubectl get -n tink-system workflow playground-workflow --watch
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   NAME               TEMPLATE       STATE
   playground-workflow   ubuntu-jammy   STATE_PENDING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_RUNNING
   playground-workflow   ubuntu-jammy   STATE_SUCCESS
   ```

   </details>

1. Login to the machine

   The machine has been provisioned with Ubuntu.
   You can now SSH into the machine.

   ```bash
   ssh tink@192.168.56.43 # user/pass => tink/tink
   ```

1. Clean up

   After you're done with the playground, clean up all VMs:
   ```bash
   vagrant destroy
   ```
