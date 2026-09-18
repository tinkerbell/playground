#!/usr/bin/env bash
# Create the external-tinkerbell-kubeconfig secret in the management cluster
# so CAPT can connect to the Tinkerbell cluster.
#
# Usage: create_external_kubeconfig_secret.sh <state-file>

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

function tink_apiserver() {
	declare -r state_file="$1" cluster="$2"

	declare network family field address
	network="$(state_field "$state_file" '.names.network')"
	family="$(yq eval '.ipFamily // "ipv4"' "$state_file")"

	# A kind node container holds both an IPv4 and an IPv6 address on a
	# dual-stack network, and an IPv6-only management cluster has no route to
	# the IPv4 one, so the playground's family decides which is read.
	if [[ $family == "ipv6" ]]; then
		field="GlobalIPv6Address"
	else
		field="IPAddress"
	fi

	# Selected by network name rather than ranged over: ranging concatenates
	# every network the container is joined to.
	address="$(docker inspect "${cluster}-control-plane" \
		-f "{{(index .NetworkSettings.Networks \"${network}\").${field}}}")"

	if [[ -z $address ]]; then
		echo "external kubeconfig: ${cluster}-control-plane has no ${field} on ${network}" >&2
		return 1
	fi

	if [[ $family == "ipv6" ]]; then
		printf 'https://[%s]:6443' "$address"
	else
		printf 'https://%s:6443' "$address"
	fi
}

function main() {
	declare -r state_file="$1"

	declare cluster mgmt_kubeconfig server kubeconfig
	cluster="$(state_field "$state_file" '.kind.tinkerbell.clusterName')"
	mgmt_kubeconfig="$(state_field "$state_file" '.kind.kubeconfig')"
	server="$(tink_apiserver "$state_file" "$cluster")"

	# kind's own kubeconfig points at a host-published port that no pod can
	# reach; the address above is the one on the shared playground network.
	kubeconfig="$(kind get kubeconfig --name "$cluster" |
		sed "s|server: https://.*|server: ${server}|g")"

	KUBECONFIG="$mgmt_kubeconfig" kubectl create namespace capt-system --dry-run=client -o yaml |
		KUBECONFIG="$mgmt_kubeconfig" kubectl apply -f -

	# Key "kubeconfig" matches CAPT's mount path
	# /var/run/secrets/external-tinkerbell/kubeconfig.
	KUBECONFIG="$mgmt_kubeconfig" kubectl create secret generic external-tinkerbell-kubeconfig \
		--namespace capt-system \
		--from-literal=kubeconfig="$kubeconfig" \
		--dry-run=client -o yaml |
		KUBECONFIG="$mgmt_kubeconfig" kubectl apply -f -

	# Labelled so `clusterctl move` carries the secret during a CAPI pivot.
	KUBECONFIG="$mgmt_kubeconfig" kubectl label secret external-tinkerbell-kubeconfig \
		--namespace capt-system \
		clusterctl.cluster.x-k8s.io/move="" \
		clusterctl.cluster.x-k8s.io="" \
		--overwrite
}

main "$@"
