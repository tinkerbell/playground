#!/bin/bash

set -euo pipefail

# this script updates the state file with the generated hardware data

function main() {
	declare -r STATE_FILE="$1"
	declare CLUSTER_NAME=$(yq eval '.clusterName' "$STATE_FILE")
	declare GATEWAY_IP=$(docker inspect -f '{{ .NetworkSettings.Networks.kind.Gateway }}' "$CLUSTER_NAME"-control-plane)
	declare NODE_IP_BASE=$(awk -F"." '{print $1"."$2".10.20"}' <<<"$GATEWAY_IP")
	declare NODE_BASE=$(yq eval '.vm.baseName' "$STATE_FILE")
	declare IP_LAST_OCTET=$(echo "$NODE_IP_BASE" | cut -d. -f4)

	yq e -i '.kind.gatewayIP = "'$GATEWAY_IP'"' "$STATE_FILE"
	yq e -i '.kind.nodeIPBase = "'$NODE_IP_BASE'"' "$STATE_FILE"

	# set an ip and gateway per node
	idx=1
	while IFS=$',' read -r name; do
		v=$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3}').$((IP_LAST_OCTET + idx))
		((idx++))
		yq e -i ".vm.details.$name.ip = \"$v\"" "$STATE_FILE"
		yq e -i ".vm.details.$name.gateway = \"$GATEWAY_IP\"" "$STATE_FILE"
		unset v
	done < <(yq e '.vm.details.[] | [key] | @csv' "$STATE_FILE")

	# set the Tinkerbell Load Balancer IP (VIP)
	offset=50
	t_lb=$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3}').$((IP_LAST_OCTET + idx + offset))
	yq e -i '.tinkerbell.vip = "'$t_lb'"' "$STATE_FILE"

	# set the Tinkerbell HookOS VIP
	hookos_vip=$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3}').$((IP_LAST_OCTET + idx + offset - 1))
	yq e -i '.tinkerbell.hookosVip = "'$hookos_vip'"' "$STATE_FILE"

	# set the cluster control plane load balancer IP (VIP)
	cp_lb=$(echo "$NODE_IP_BASE" | awk -F"." '{print $1"."$2"."$3}').$((IP_LAST_OCTET + idx + offset + 1))
	yq e -i '.cluster.controlPlane.vip = "'$cp_lb'"' "$STATE_FILE"

	# set the cluster pod cidr
	POD_CIDR=$(awk -F"." '{print $1".100.0.0/16"}' <<<"$GATEWAY_IP")
	yq e -i '.cluster.podCIDR = "'$POD_CIDR'"' "$STATE_FILE"

	# set the KinD bridge name
	network_id=$(docker network inspect -f '{{.Id}}' kind)
	bridge_name="br-${network_id:0:12}"
	yq e -i '.kind.bridgeName = "'$bridge_name'"' "$STATE_FILE"

}

main "$@"
