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
   cd deploy/vagrant
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
   ==> provisioner:  -- Description:       Source: /home/tink/repos/tinkerbell/sandbox/deploy/vagrant/Vagrantfile
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
       provisioner: SSH address: 192.168.121.9:22
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
   ==> provisioner: Rsyncing folder: /home/tink/repos/tinkerbell/sandbox/deploy/compose/ => /sandbox/compose
   ==> provisioner: Running provisioner: shell...
       provisioner: Running: /tmp/vagrant-shell20221003-2211944-3knjk9.sh
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
       provisioner: Get:5 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 Packages [609 kB]
       provisioner: Get:6 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main Translation-en [142 kB]
       provisioner: Get:7 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 c-n-f Metadata [8,764 B]
       provisioner: Get:8 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted amd64 Packages [344 kB]
       provisioner: Get:9 https://mirrors.edge.kernel.org/ubuntu jammy-updates/restricted Translation-en [53.5 kB]
       provisioner: Get:10 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 Packages [423 kB]
       provisioner: Get:11 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 Packages [6,752 B]
       provisioner: Get:12 https://mirrors.edge.kernel.org/ubuntu jammy-backports/universe amd64 c-n-f Metadata [352 B]
       provisioner: Get:13 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 Packages [350 kB]
       provisioner: Get:14 https://mirrors.edge.kernel.org/ubuntu jammy-security/main Translation-en [81.7 kB]
       provisioner: Get:15 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted amd64 Packages [304 kB]
       provisioner: Get:16 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted Translation-en [47.2 kB]
       provisioner: Get:17 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 Packages [287 kB]
       provisioner: Get:18 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe Translation-en [63.2 kB]
       provisioner: Fetched 3,045 kB in 9s (354 kB/s)
       provisioner: Reading package lists...
       provisioner: + install_docker
       provisioner: + sudo apt-key add -
       provisioner: + curl -fsSL https://download.docker.com/linux/ubuntu/gpg
       provisioner: Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
       provisioner: OK
       provisioner: ++ lsb_release -cs
       provisioner: + add-apt-repository 'deb https://download.docker.com/linux/ubuntu jammy stable'
       provisioner: Get:1 https://download.docker.com/linux/ubuntu jammy InRelease [48.9 kB]
       provisioner: Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 Packages [7,065 B]
       provisioner: Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
       provisioner: Hit:4 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease
       provisioner: Hit:5 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease
       provisioner: Hit:6 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease
       provisioner: Fetched 55.9 kB in 1s (62.5 kB/s)
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
       provisioner: + apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli
       provisioner: + DEBIAN_FRONTEND=noninteractive
       provisioner: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes install --no-install-recommends containerd.io docker-ce docker-ce-cli
       provisioner: Reading package lists...
       provisioner: Building dependency tree...
       provisioner: Reading state information...
       provisioner: Suggested packages:
       provisioner:   aufs-tools cgroupfs-mount | cgroup-lite
       provisioner: Recommended packages:
       provisioner:   docker-ce-rootless-extras libltdl7 pigz docker-scan-plugin
       provisioner: The following NEW packages will be installed:
       provisioner:   containerd.io docker-ce docker-ce-cli
       provisioner: 0 upgraded, 3 newly installed, 0 to remove and 4 not upgraded.
       provisioner: Need to get 90.0 MB of archives.
       provisioner: After this operation, 365 MB of additional disk space will be used.
       provisioner: Get:1 https://download.docker.com/linux/ubuntu jammy/stable amd64 containerd.io amd64 1.6.8-1 [28.1 MB]
       provisioner: Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce-cli amd64 5:20.10.18~3-0~ubuntu-jammy [41.5 MB]
       provisioner: Get:3 https://download.docker.com/linux/ubuntu jammy/stable amd64 docker-ce amd64 5:20.10.18~3-0~ubuntu-jammy [20.4 MB]
       provisioner: Fetched 90.0 MB in 2s (38.6 MB/s)
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
       provisioner: Setting up containerd.io (1.6.8-1) ...
       provisioner: Created symlink /etc/systemd/system/multi-user.target.wants/containerd.service → /lib/systemd/system/containerd.service.
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
       provisioner: + install_docker_compose
       provisioner: + apt-get install --no-install-recommends python3-pip
       provisioner: + DEBIAN_FRONTEND=noninteractive
       provisioner: + command apt-get --allow-change-held-packages --allow-downgrades --allow-remove-essential --allow-unauthenticated --option Dpkg::Options::=--force-confdef --option Dpkg::Options::=--force-confold --yes install --no-install-recommends python3-pip
       provisioner: Reading package lists...
       provisioner: Building dependency tree...
       provisioner: Reading state information...
       provisioner: The following additional packages will be installed:
       provisioner:   python3-wheel
       provisioner: Recommended packages:
       provisioner:   build-essential python3-dev
       provisioner: The following NEW packages will be installed:
       provisioner:   python3-pip python3-wheel
       provisioner: 0 upgraded, 2 newly installed, 0 to remove and 4 not upgraded.
       provisioner: Need to get 1,337 kB of archives.
       provisioner: After this operation, 7,176 kB of additional disk space will be used.
       provisioner: Get:1 https://mirrors.edge.kernel.org/ubuntu jammy/universe amd64 python3-wheel all 0.37.1-2 [31.9 kB]
       provisioner: Get:2 https://mirrors.edge.kernel.org/ubuntu jammy/universe amd64 python3-pip all 22.0.2+dfsg-1 [1,306 kB]
       provisioner: Fetched 1,337 kB in 3s (386 kB/s)
       provisioner: Selecting previously unselected package python3-wheel.
   (Reading database ... 75572 files and directories currently installed.)
       provisioner: Preparing to unpack .../python3-wheel_0.37.1-2_all.deb ...
       provisioner: Unpacking python3-wheel (0.37.1-2) ...
       provisioner: Selecting previously unselected package python3-pip.
       provisioner: Preparing to unpack .../python3-pip_22.0.2+dfsg-1_all.deb ...
       provisioner: Unpacking python3-pip (22.0.2+dfsg-1) ...
       provisioner: Setting up python3-wheel (0.37.1-2) ...
       provisioner: Setting up python3-pip (22.0.2+dfsg-1) ...
       provisioner: Processing triggers for man-db (2.10.2-1) ...
       provisioner: NEEDRESTART-VER: 3.5
       provisioner: NEEDRESTART-KCUR: 5.15.0-48-generic
       provisioner: NEEDRESTART-KEXP: 5.15.0-48-generic
       provisioner: NEEDRESTART-KSTA: 1
       provisioner: + pip install docker-compose
       provisioner: Collecting docker-compose
       provisioner:   Downloading docker_compose-1.29.2-py2.py3-none-any.whl (114 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 114.8/114.8 KB 1.1 MB/s eta 0:00:00
       provisioner: Collecting requests<3,>=2.20.0
       provisioner:   Downloading requests-2.28.1-py3-none-any.whl (62 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 62.8/62.8 KB 2.7 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: distro<2,>=1.5.0 in /usr/lib/python3/dist-packages (from docker-compose) (1.7.0)
       provisioner: Collecting docker[ssh]>=5
       provisioner:   Downloading docker-6.0.0-py3-none-any.whl (147 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 147.2/147.2 KB 2.5 MB/s eta 0:00:00
       provisioner: Collecting texttable<2,>=0.9.0
       provisioner:   Downloading texttable-1.6.4-py2.py3-none-any.whl (10 kB)
       provisioner: Collecting websocket-client<1,>=0.32.0
       provisioner:   Downloading websocket_client-0.59.0-py2.py3-none-any.whl (67 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 67.2/67.2 KB 5.6 MB/s eta 0:00:00
       provisioner: Collecting dockerpty<1,>=0.4.1
       provisioner:   Downloading dockerpty-0.4.1.tar.gz (13 kB)
       provisioner:   Preparing metadata (setup.py): started
       provisioner:   Preparing metadata (setup.py): finished with status 'done'
       provisioner: Collecting python-dotenv<1,>=0.13.0
       provisioner:   Downloading python_dotenv-0.21.0-py3-none-any.whl (18 kB)
       provisioner: Collecting jsonschema<4,>=2.5.1
       provisioner:   Downloading jsonschema-3.2.0-py2.py3-none-any.whl (56 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 56.3/56.3 KB 2.5 MB/s eta 0:00:00
       provisioner: Collecting docopt<1,>=0.6.1
       provisioner:   Downloading docopt-0.6.2.tar.gz (25 kB)
       provisioner:   Preparing metadata (setup.py): started
       provisioner:   Preparing metadata (setup.py): finished with status 'done'
       provisioner: Requirement already satisfied: PyYAML<6,>=3.10 in /usr/lib/python3/dist-packages (from docker-compose) (5.4.1)
       provisioner: Collecting urllib3>=1.26.0
       provisioner:   Downloading urllib3-1.26.12-py2.py3-none-any.whl (140 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 140.4/140.4 KB 3.7 MB/s eta 0:00:00
       provisioner: Collecting packaging>=14.0
       provisioner:   Downloading packaging-21.3-py3-none-any.whl (40 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 40.8/40.8 KB 1.9 MB/s eta 0:00:00
       provisioner: Collecting paramiko>=2.4.3
       provisioner:   Downloading paramiko-2.11.0-py2.py3-none-any.whl (212 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 212.9/212.9 KB 3.5 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: six>=1.3.0 in /usr/lib/python3/dist-packages (from dockerpty<1,>=0.4.1->docker-compose) (1.16.0)
       provisioner: Collecting pyrsistent>=0.14.0
       provisioner:   Downloading pyrsistent-0.18.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (115 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 115.8/115.8 KB 3.4 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: setuptools in /usr/lib/python3/dist-packages (from jsonschema<4,>=2.5.1->docker-compose) (59.6.0)
       provisioner: Requirement already satisfied: attrs>=17.4.0 in /usr/lib/python3/dist-packages (from jsonschema<4,>=2.5.1->docker-compose) (21.2.0)
       provisioner: Requirement already satisfied: idna<4,>=2.5 in /usr/lib/python3/dist-packages (from requests<3,>=2.20.0->docker-compose) (3.3)
       provisioner: Collecting certifi>=2017.4.17
       provisioner:   Downloading certifi-2022.9.24-py3-none-any.whl (161 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 161.1/161.1 KB 4.2 MB/s eta 0:00:00
       provisioner: Collecting charset-normalizer<3,>=2
       provisioner:   Downloading charset_normalizer-2.1.1-py3-none-any.whl (39 kB)
       provisioner: Requirement already satisfied: pyparsing!=3.0.5,>=2.0.2 in /usr/lib/python3/dist-packages (from packaging>=14.0->docker[ssh]>=5->docker-compose) (2.4.7)
       provisioner: Requirement already satisfied: bcrypt>=3.1.3 in /usr/lib/python3/dist-packages (from paramiko>=2.4.3->docker[ssh]>=5->docker-compose) (3.2.0)
       provisioner: Requirement already satisfied: cryptography>=2.5 in /usr/lib/python3/dist-packages (from paramiko>=2.4.3->docker[ssh]>=5->docker-compose) (3.4.8)
       provisioner: Collecting pynacl>=1.0.1
       provisioner:   Downloading PyNaCl-1.5.0-cp36-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.manylinux_2_24_x86_64.whl (856 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 856.7/856.7 KB 3.8 MB/s eta 0:00:00
       provisioner: Collecting cffi>=1.4.1
       provisioner:   Downloading cffi-1.15.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (441 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 441.8/441.8 KB 3.2 MB/s eta 0:00:00
       provisioner: Collecting pycparser
       provisioner:   Downloading pycparser-2.21-py2.py3-none-any.whl (118 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 118.7/118.7 KB 3.0 MB/s eta 0:00:00
       provisioner: Building wheels for collected packages: dockerpty, docopt
       provisioner:   Building wheel for dockerpty (setup.py): started
       provisioner:   Building wheel for dockerpty (setup.py): finished with status 'done'
       provisioner:   Created wheel for dockerpty: filename=dockerpty-0.4.1-py3-none-any.whl size=16614 sha256=f3e53d50dcd4a3cae5449e8b43a3874b803641e73fbad5648b9e8e32e2758184
       provisioner:   Stored in directory: /root/.cache/pip/wheels/18/00/32/f75cd03098074f988a01c59a2e3a55ae9c0773eb66acb4cb5e
       provisioner:   Building wheel for docopt (setup.py): started
       provisioner:   Building wheel for docopt (setup.py): finished with status 'done'
       provisioner:   Created wheel for docopt: filename=docopt-0.6.2-py2.py3-none-any.whl size=13723 sha256=a836e95bae4804a5e0e37dc9bb570569c451cf0000f66c53d2cab406b2bf7354
       provisioner:   Stored in directory: /root/.cache/pip/wheels/fc/ab/d4/5da2067ac95b36618c629a5f93f809425700506f72c9732fac
       provisioner: Successfully built dockerpty docopt
       provisioner: Installing collected packages: texttable, docopt, websocket-client, urllib3, python-dotenv, pyrsistent, pycparser, packaging, dockerpty, charset-normalizer, certifi, requests, jsonschema, cffi, pynacl, docker, paramiko, docker-compose
       provisioner: Successfully installed certifi-2022.9.24 cffi-1.15.1 charset-normalizer-2.1.1 docker-6.0.0 docker-compose-1.29.2 dockerpty-0.4.1 docopt-0.6.2 jsonschema-3.2.0 packaging-21.3 paramiko-2.11.0 pycparser-2.21 pynacl-1.5.0 pyrsistent-0.18.1 python-dotenv-0.21.0 requests-2.28.1 texttable-1.6.4 urllib3-1.26.12 websocket-client-0.59.0
       provisioner: WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv
       provisioner: + install_kubectl
       provisioner: + curl -LO https://dl.k8s.io/v1.25.2/bin/linux/amd64/kubectl
       provisioner:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
       provisioner:                                  Dload  Upload   Total   Spent    Left  Speed
   100   138  100   138    0     0    342      0 --:--:-- --:--:-- --:--:--   343
   100 42.9M  100 42.9M    0     0  27.5M      0  0:00:01  0:00:01 --:--:-- 59.6M
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
       provisioner: + grep -q vda
       provisioner: + lsblk
       provisioner: + disk_device=/dev/vda
       provisioner: + [[ /sandbox/compose = *\p\o\s\t\g\r\e\s* ]]
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
       provisioner: + docker-compose -f /sandbox/compose/docker-compose.yml up -d
       provisioner: Creating network "compose_default" with the default driver
       provisioner: Creating volume "compose_k3s-server" with default driver
       provisioner: Pulling k3s (rancher/k3s:v1.24.4-k3s1)...
       provisioner: v1.24.4-k3s1: Pulling from rancher/k3s
       provisioner: Digest: sha256:05cd81e3fede9006e422faef1c23950f5b475919bb96a911efd231f688f0df20
       provisioner: Status: Downloaded newer image for rancher/k3s:v1.24.4-k3s1
       provisioner: Pulling tink-crds-apply (bitnami/kubectl:1.24.6)...
       provisioner: 1.24.6: Pulling from bitnami/kubectl
       provisioner: Digest: sha256:cdfde359a9a658be47a7d7df664d072291d926a2f6dbc1e560786a76ffd0f803
       provisioner: Status: Downloaded newer image for bitnami/kubectl:1.24.6
       provisioner: Pulling tink-server (quay.io/tinkerbell/tink:v0.7.0)...
       provisioner: v0.7.0: Pulling from tinkerbell/tink
       provisioner: Digest: sha256:b4ee7cf6da1e7dc5a5107e51e725b4fa7e46aac65cbe42cfe22139b07d6363b3
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/tink:v0.7.0
       provisioner: Pulling tink-controller (quay.io/tinkerbell/tink-controller:sha-eeb2a454)...
       provisioner: sha-eeb2a454: Pulling from tinkerbell/tink-controller
       provisioner: Digest: sha256:3cd56aaaf02fcbfcada752013db85f23816300b52527df0fb8f5481252bbc925
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/tink-controller:sha-eeb2a454
       provisioner: Pulling hegel (quay.io/tinkerbell/hegel:v0.7.0)...
       provisioner: v0.7.0: Pulling from tinkerbell/hegel
       provisioner: Digest: sha256:6cae60bc29eaee5b213b258894f50caebd8c229a2bafa666e88772da4e4f8ded
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/hegel:v0.7.0
       provisioner: Pulling boots (quay.io/tinkerbell/boots:v0.7.0)...
       provisioner: v0.7.0: Pulling from tinkerbell/boots
       provisioner: Digest: sha256:4ac5c895d9ec455872352daffb659a359df8caa89616d62c66442e36b5cef6ac
       provisioner: Status: Downloaded newer image for quay.io/tinkerbell/boots:v0.7.0
       provisioner: Pulling manifest-update (bash:4.4)...
       provisioner: 4.4: Pulling from library/bash
       provisioner: Digest: sha256:ade9306aa8b4ca03953c1833316601df144e463d414a037c1f1fcc738f974b07
       provisioner: Status: Downloaded newer image for bash:4.4
       provisioner: Pulling web-assets-server (nginx:alpine)...
       provisioner: alpine: Pulling from library/nginx
       provisioner: Digest: sha256:082f8c10bd47b6acc8ef15ae61ae45dd8fde0e9f389a8b5cb23c37408642bf5d
       provisioner: Status: Downloaded newer image for nginx:alpine
       provisioner: Creating compose_k3s_1 ...
       provisioner: Creating compose_manifest-update_1 ...
       provisioner: Creating compose_fetch-and-convert-ubuntu-img_1 ...
       provisioner: Creating compose_fetch-osie_1                   ...
       provisioner: Creating compose_fetch-osie_1                   ... done
       provisioner: Creating compose_manifest-update_1              ... done
       provisioner: Creating compose_k3s_1                          ... done
       provisioner: Creating compose_fetch-and-convert-ubuntu-img_1 ... done
       provisioner: Creating compose_web-assets-server_1            ...
       provisioner: Creating compose_web-assets-server_1            ... done
       provisioner: Creating compose_tink-crds-apply_1              ...
       provisioner: Creating compose_tink-crds-apply_1              ... done
       provisioner: Creating compose_boots_1                        ...
       provisioner: Creating compose_hegel_1                        ...
       provisioner: Creating compose_tink-server_1                  ...
       provisioner: Creating compose_tink-controller_1              ...
       provisioner: Creating compose_manifest-apply_1               ...
       provisioner: Creating compose_boots_1                        ... done
       provisioner: Creating compose_tink-server_1                  ... done
       provisioner: Creating compose_manifest-apply_1               ... done
       provisioner: Creating compose_hegel_1                        ... done
       provisioner: Creating compose_tink-controller_1              ... done
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
       provisioner: + grep -q dc=docker-compose /home/vagrant/.bash_aliases
       provisioner: grep: /home/vagrant/.bash_aliases: No such file or directory
       provisioner: all done!
       provisioner: + echo 'alias dc=docker-compose'
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
   kubectl get workflow sandbox-workflow --watch
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
   # log in to the provisioner
   vagrant ssh provisioner
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
