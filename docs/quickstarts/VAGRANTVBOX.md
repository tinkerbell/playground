# Quick start guide for Vagrant and VirtualBox

This option will stand up the provisioner in Virtualbox using Vagrant.
This option will also show you how to create a machine to provision.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) is installed
- [VirtualBox](https://www.virtualbox.org/) is installed

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
   Bringing machine 'provisioner' up with 'virtualbox' provider...
   ==> provisioner: Box 'generic/ubuntu2204' could not be found. Attempting to find and install...
       provisioner: Box Provider: virtualbox
       provisioner: Box Version: >= 0
   ==> provisioner: Loading metadata for box 'generic/ubuntu2204'
       provisioner: URL: https://vagrantcloud.com/generic/ubuntu2204
   ==> provisioner: Adding box 'generic/ubuntu2204' (v4.1.14) for provider: virtualbox
       provisioner: Downloading: https://vagrantcloud.com/generic/boxes/ubuntu2204/versions/4.1.14/providers/virtualbox.box
   ==> provisioner: Box download is resuming from prior download progress
       provisioner: Calculating and comparing box checksum...
   ==> provisioner: Successfully added box 'generic/ubuntu2204' (v4.1.14) for 'virtualbox'!
   ==> provisioner: Importing base box 'generic/ubuntu2204'...
   ==> provisioner: Matching MAC address for NAT networking...
   ==> provisioner: Checking if box 'generic/ubuntu2204' version '4.1.14' is up to date...
   ==> provisioner: Setting the name of the VM: vagrant_provisioner_1664821338395_75599
   ==> provisioner: Clearing any previously set network interfaces...
   ==> provisioner: Preparing network interfaces based on configuration...
       provisioner: Adapter 1: nat
       provisioner: Adapter 2: hostonly
   ==> provisioner: Forwarding ports...
       provisioner: 22 (guest) => 2222 (host) (adapter 1)
   ==> provisioner: Running 'pre-boot' VM customizations...
   ==> provisioner: Booting VM...
   ==> provisioner: Waiting for machine to boot. This may take a few minutes...
       provisioner: SSH address: 127.0.0.1:2222
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
   ==> provisioner: Checking for guest additions in VM...
   ==> provisioner: Mounting shared folders...
       provisioner: /sandbox/compose => /private/tmp/sandbox/deploy/compose
   ==> provisioner: Running provisioner: shell...
       provisioner: Running: /var/folders/xt/8w5g0fv54tj4njvjhk_0_25r0000gr/T/vagrant-shell20221003-39663-1jnxzau.sh
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
       provisioner: Fetched 3,045 kB in 6s (505 kB/s)
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
       provisioner: Fetched 55.9 kB in 1s (80.7 kB/s)
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
       provisioner: Fetched 90.0 MB in 3s (29.6 MB/s)
       provisioner: Selecting previously unselected package containerd.io.
   (Reading database ... 75348 files and directories currently installed.)
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
       provisioner: Fetched 1,337 kB in 3s (493 kB/s)
       provisioner: Selecting previously unselected package python3-wheel.
   (Reading database ... 75573 files and directories currently installed.)
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
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 114.8/114.8 KB 1.5 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: distro<2,>=1.5.0 in /usr/lib/python3/dist-packages (from docker-compose) (1.7.0)
       provisioner: Collecting docker[ssh]>=5
       provisioner:   Downloading docker-6.0.0-py3-none-any.whl (147 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 147.2/147.2 KB 7.1 MB/s eta 0:00:00
       provisioner: Collecting python-dotenv<1,>=0.13.0
       provisioner:   Downloading python_dotenv-0.21.0-py3-none-any.whl (18 kB)
       provisioner: Collecting jsonschema<4,>=2.5.1
       provisioner:   Downloading jsonschema-3.2.0-py2.py3-none-any.whl (56 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 56.3/56.3 KB 16.1 MB/s eta 0:00:00
       provisioner: Collecting websocket-client<1,>=0.32.0
       provisioner:   Downloading websocket_client-0.59.0-py2.py3-none-any.whl (67 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 67.2/67.2 KB 16.4 MB/s eta 0:00:00
       provisioner: Collecting dockerpty<1,>=0.4.1
       provisioner:   Downloading dockerpty-0.4.1.tar.gz (13 kB)
       provisioner:   Preparing metadata (setup.py): started
       provisioner:   Preparing metadata (setup.py): finished with status 'done'
       provisioner: Collecting docopt<1,>=0.6.1
       provisioner:   Downloading docopt-0.6.2.tar.gz (25 kB)
       provisioner:   Preparing metadata (setup.py): started
       provisioner:   Preparing metadata (setup.py): finished with status 'done'
       provisioner: Collecting texttable<2,>=0.9.0
       provisioner:   Downloading texttable-1.6.4-py2.py3-none-any.whl (10 kB)
       provisioner: Requirement already satisfied: PyYAML<6,>=3.10 in /usr/lib/python3/dist-packages (from docker-compose) (5.4.1)
       provisioner: Collecting requests<3,>=2.20.0
       provisioner:   Downloading requests-2.28.1-py3-none-any.whl (62 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 62.8/62.8 KB 15.1 MB/s eta 0:00:00
       provisioner: Collecting urllib3>=1.26.0
       provisioner:   Downloading urllib3-1.26.12-py2.py3-none-any.whl (140 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 140.4/140.4 KB 13.7 MB/s eta 0:00:00
       provisioner: Collecting packaging>=14.0
       provisioner:   Downloading packaging-21.3-py3-none-any.whl (40 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 40.8/40.8 KB 11.5 MB/s eta 0:00:00
       provisioner: Collecting paramiko>=2.4.3
       provisioner:   Downloading paramiko-2.11.0-py2.py3-none-any.whl (212 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 212.9/212.9 KB 14.2 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: six>=1.3.0 in /usr/lib/python3/dist-packages (from dockerpty<1,>=0.4.1->docker-compose) (1.16.0)
       provisioner: Collecting pyrsistent>=0.14.0
       provisioner:   Downloading pyrsistent-0.18.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (115 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 115.8/115.8 KB 21.5 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: setuptools in /usr/lib/python3/dist-packages (from jsonschema<4,>=2.5.1->docker-compose) (59.6.0)
       provisioner: Requirement already satisfied: attrs>=17.4.0 in /usr/lib/python3/dist-packages (from jsonschema<4,>=2.5.1->docker-compose) (21.2.0)
       provisioner: Requirement already satisfied: idna<4,>=2.5 in /usr/lib/python3/dist-packages (from requests<3,>=2.20.0->docker-compose) (3.3)
       provisioner: Collecting charset-normalizer<3,>=2
       provisioner:   Downloading charset_normalizer-2.1.1-py3-none-any.whl (39 kB)
       provisioner: Collecting certifi>=2017.4.17
       provisioner:   Downloading certifi-2022.9.24-py3-none-any.whl (161 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 161.1/161.1 KB 22.6 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: pyparsing!=3.0.5,>=2.0.2 in /usr/lib/python3/dist-packages (from packaging>=14.0->docker[ssh]>=5->docker-compose) (2.4.7)
       provisioner: Requirement already satisfied: bcrypt>=3.1.3 in /usr/lib/python3/dist-packages (from paramiko>=2.4.3->docker[ssh]>=5->docker-compose) (3.2.0)
       provisioner: Collecting pynacl>=1.0.1
       provisioner:   Downloading PyNaCl-1.5.0-cp36-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.manylinux_2_24_x86_64.whl (856 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 856.7/856.7 KB 13.5 MB/s eta 0:00:00
       provisioner: Requirement already satisfied: cryptography>=2.5 in /usr/lib/python3/dist-packages (from paramiko>=2.4.3->docker[ssh]>=5->docker-compose) (3.4.8)
       provisioner: Collecting cffi>=1.4.1
       provisioner:   Downloading cffi-1.15.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (441 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 441.8/441.8 KB 67.6 MB/s eta 0:00:00
       provisioner: Collecting pycparser
       provisioner:   Downloading pycparser-2.21-py2.py3-none-any.whl (118 kB)
       provisioner:      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 118.7/118.7 KB 29.5 MB/s eta 0:00:00
       provisioner: Building wheels for collected packages: dockerpty, docopt
       provisioner:   Building wheel for dockerpty (setup.py): started
       provisioner:   Building wheel for dockerpty (setup.py): finished with status 'done'
       provisioner:   Created wheel for dockerpty: filename=dockerpty-0.4.1-py3-none-any.whl size=16614 sha256=55981ac75af5c436e10953dac58fbf0fe16885a35e4b281515f7d994eb4c7f90
       provisioner:   Stored in directory: /root/.cache/pip/wheels/18/00/32/f75cd03098074f988a01c59a2e3a55ae9c0773eb66acb4cb5e
       provisioner:   Building wheel for docopt (setup.py): started
       provisioner:   Building wheel for docopt (setup.py): finished with status 'done'
       provisioner:   Created wheel for docopt: filename=docopt-0.6.2-py2.py3-none-any.whl size=13723 sha256=a6d52c6fda1d484a68603824187aa3502d790e09475fd285788e27a82bbcb0a6
       provisioner:   Stored in directory: /root/.cache/pip/wheels/fc/ab/d4/5da2067ac95b36618c629a5f93f809425700506f72c9732fac
       provisioner: Successfully built dockerpty docopt
       provisioner: Installing collected packages: texttable, docopt, websocket-client, urllib3, python-dotenv, pyrsistent, pycparser, packaging, dockerpty, charset-normalizer, certifi, requests, jsonschema, cffi, pynacl, docker, paramiko, docker-compose
       provisioner: Successfully installed certifi-2022.9.24 cffi-1.15.1 charset-normalizer-2.1.1 docker-6.0.0 docker-compose-1.29.2 dockerpty-0.4.1 docopt-0.6.2 jsonschema-3.2.0 packaging-21.3 paramiko-2.11.0 pycparser-2.21 pynacl-1.5.0 pyrsistent-0.18.1 python-dotenv-0.21.0 requests-2.28.1 texttable-1.6.4 urllib3-1.26.12 websocket-client-0.59.0
       provisioner: WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv
       provisioner: + install_kubectl
       provisioner: + curl -LO https://dl.k8s.io/v1.25.2/bin/linux/amd64/kubectl
       provisioner:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
       provisioner:                                  Dload  Upload   Total   Spent    Left  Speed
   100   138  100   138    0     0    317      0 --:--:-- --:--:-- --:--:--   317
   100 42.9M  100 42.9M    0     0  27.0M      0  0:00:01  0:00:01 --:--:-- 67.1M
       provisioner: + chmod +x ./kubectl
       provisioner: + mv ./kubectl /usr/local/bin/kubectl
       provisioner: + setup_layer2_network 192.168.56.4
       provisioner: + local host_ip=192.168.56.4
       provisioner: + grep -q 192.168.56.4
       provisioner: + ip addr show dev eth1
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
       provisioner: + grep -q 'DISK_DEVICE="/dev/sda"' /sandbox/compose/.env
       provisioner: + echo 'DISK_DEVICE="/dev/sda"'
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
       provisioner: Creating compose_fetch-and-convert-ubuntu-img_1 ...
       provisioner: Creating compose_k3s_1                          ...
       provisioner: Creating compose_manifest-update_1              ...
       provisioner: Creating compose_fetch-osie_1                   ...
       provisioner: Creating compose_manifest-update_1              ... done
       provisioner: Creating compose_fetch-osie_1                   ... done
       provisioner: Creating compose_k3s_1                          ... done
       provisioner: Creating compose_fetch-and-convert-ubuntu-img_1 ... done
       provisioner: Creating compose_web-assets-server_1            ...
       provisioner: Creating compose_web-assets-server_1            ... done
       provisioner: Creating compose_tink-crds-apply_1              ...
       provisioner: Creating compose_tink-crds-apply_1              ... done
       provisioner: Creating compose_boots_1                        ...
       provisioner: Creating compose_manifest-apply_1               ...
       provisioner: Creating compose_tink-server_1                  ...
       provisioner: Creating compose_hegel_1                        ...
       provisioner: Creating compose_tink-controller_1              ...
       provisioner: Creating compose_boots_1                        ... done
       provisioner: Creating compose_manifest-apply_1               ... done
       provisioner: Creating compose_tink-controller_1              ... done
       provisioner: Creating compose_hegel_1                        ... done
       provisioner: Creating compose_tink-server_1                  ... done
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
       provisioner: + echo 'alias dc=docker-compose'
       provisioner: all done!
       provisioner: + echo 'all done!'
   ```

   </details>

3. Start the machine to be provisioned

   ```bash
   vagrant up machine1
   # This will start a VM to pxe boot. A GUI window of this machines console will be opened.
   # The `vagrant up machine1` command will exit quickly and show the following error message. This is expected.
   # Once the command line control is returned to you, you can move on to the next step.
   ```

   <details>
   <summary>expected output</summary>

   ```bash
   Bringing machine 'machine1' up with 'virtualbox' provider...
   ==> machine1: Importing base box 'jtyr/pxe'...
   ==> machine1: Matching MAC address for NAT networking...
   ==> machine1: Checking if box 'jtyr/pxe' version '2' is up to date...
   ==> machine1: Setting the name of the VM: vagrant_machine1_1626365105119_9800
   ==> machine1: Fixed port collision for 22 => 2222. Now on port 2200.
   ==> machine1: Clearing any previously set network interfaces...
   ==> machine1: Preparing network interfaces based on configuration...
       machine1: Adapter 1: hostonly
   ==> machine1: Forwarding ports...
       machine1: 22 (guest) => 2200 (host) (adapter 1)
       machine1: VirtualBox adapter #1 not configured as "NAT". Skipping port
       machine1: forwards on this adapter.
   ==> machine1: Running 'pre-boot' VM customizations...
   ==> machine1: Booting VM...
   ==> machine1: Waiting for machine to boot. This may take a few minutes...
       machine1: SSH address: 127.0.0.1:22
       machine1: SSH username: vagrant
       machine1: SSH auth method: private key
       machine1: Warning: Authentication failure. Retrying...
   Timed out while waiting for the machine to boot. This means that
   Vagrant was unable to communicate with the guest machine within
   the configured ("config.vm.boot_timeout" value) time period.

   If you look above, you should be able to see the error(s) that
   Vagrant had when attempting to connect to the machine. These errors
   are usually good hints as to what may be wrong.

   If you're using a custom box, make sure that networking is properly
   working and you're able to connect to the machine. It is a common
   problem that networking isn't setup properly in these boxes.
   Verify that authentication configurations are also setup properly,
   as well.

   If the box appears to be booting properly, you may want to increase
   the timeout ("config.vm.boot_timeout") value.

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
   <summary>Expected output</summary>

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
