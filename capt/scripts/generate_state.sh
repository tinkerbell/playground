#!/bin/bash
# This script generates the state data needed for creating the CAPT playground.

# state file spec
cat <<EOF >/dev/null
---
clusterName: "capt-playground"
outputDir: "/home/tink/repos/tinkerbell/cluster-api-provider-tinkerbell/playground/output"
namespace: "tink"
counts:
  controlPlanes: 1
  workers: 1
  spares: 1
versions:
  capt: 0.5.3
  chart: 0.5.0
  kube: v1.28.8
  os: 22.04
os:
  registry: reg.weinstocklabs.com/tinkerbell/cluster-api-provider-tinkerbell
  distro: ubuntu
  sshKey: ""
  version: "2204"
vm:
  baseName: "node"
  cpusPerVM: 2
  memInMBPerVM: 2048
  diskSizeInGBPerVM: 10
  diskPath: "/tmp"
  details:
    node1:
      mac: 02:7f:92:bd:2d:57
      bmc:
        port: 6231
      role: control-plane
      ip: 172.18.10.21
      gateway: 172.18.0.1
    node2:
      mac: 02:f3:eb:c1:aa:2b
      bmc:
        port: 6232
      role: worker
      ip: 172.18.10.22
      gateway: 172.18.0.1
    node3:
      mac: 02:3c:e6:70:1b:5e
      bmc:
        port: 6233
      role: spare
      ip: 172.18.10.23
      gateway: 172.18.0.1
virtualBMC:
  containerName: "virtualbmc"
  image: ghcr.io/jacobweinstock/virtualbmc
  user: "root"
  pass: "calvin"
  ip: 172.18.0.3
totalNodes: 3
kind:
  kubeconfig: /home/tink/repos/tinkerbell/cluster-api-provider-tinkerbell/playground/output/kind.kubeconfig
  gatewayIP: 172.18.0.1
  nodeIPBase: 172.18.10.20
  bridgeName: br-d086780dac6b
tinkerbell:
  vip: 172.18.10.74
cluster:
  controlPlane:
    vip: 172.18.10.75
  podCIDR: 172.100.0.0/16
EOF

set -euo pipefail

function generate_mac() {
	declare NODE_NAME="$1"

	echo "$NODE_NAME" | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/'
}

function main() {
	# read in the config.yaml file and populate the .state file
	declare CONFIG_FILE="$1"
	declare STATE_FILE="$2"

	# update outputDir to be a fully qualified path
	output_dir=$(yq eval '.outputDir' "$CONFIG_FILE")
	if [[ $output_dir == /* ]]; then
		echo
	else
		current_dir=$(pwd)
		output_dir="$current_dir/$output_dir"
	fi
	config_file=$(realpath "$CONFIG_FILE")
	state_file="$STATE_FILE"

	cp -a "$config_file" "$state_file"
	yq e -i '.outputDir = "'$output_dir'"' "$state_file"

	# totalNodes
	total_nodes=$(($(yq eval '.counts.controlPlanes' "$state_file") + $(yq eval '.counts.workers' "$state_file") + $(yq eval '.counts.spares' "$state_file")))
	yq e -i ".totalNodes = $total_nodes" "$state_file"

	# populate vmNames
	base_name=$(yq eval '.vm.baseName' "$state_file")
	base_ipmi_port=6230
	for i in $(seq 1 $total_nodes); do
		name="$base_name$i"
		mac=$(generate_mac "$name")
		yq e -i ".vm.details.$name.mac = \"$mac\"" "$state_file"
		yq e -i ".vm.details.$name.bmc.port = $((base_ipmi_port + i))" "$state_file"
		# set the node role
		if [[ $i -le $(yq eval '.counts.controlPlanes' "$state_file") ]]; then
			yq e -i ".vm.details.$name.role = \"control-plane\"" "$state_file"
		elif [[ $i -le $(($(yq eval '.counts.controlPlanes' "$state_file") + $(yq eval '.counts.workers' "$state_file"))) ]]; then
			yq e -i ".vm.details.$name.role = \"worker\"" "$state_file"
		else
			yq e -i ".vm.details.$name.role = \"spare\"" "$state_file"
		fi
		unset name
		unset mac
	done

	# populate kind.kubeconfig
	yq e -i '.kind.kubeconfig = "'$output_dir'/kind.kubeconfig"' "$state_file"

	# populate the expected OS version in the raw image name (22.04 -> 2204)
	os_version=$(yq eval '.versions.os' "$state_file")
	os_version=$(echo "$os_version" | tr -d '.')
	yq e -i '.os.version = "'$os_version'"' "$state_file"
}

main "$@"
