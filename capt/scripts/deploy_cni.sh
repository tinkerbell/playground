#!/bin/bash

set -euo pipefail

# Deploy kube-router as the workload cluster CNI.
#
# The upstream kubeadm-kuberouter.yaml is IPv4-only: it takes no address family
# flags, so on an IPv6-only cluster kube-router fails on startup with "IPv4 was
# enabled, but no IPv4 address was found on the node". Three more settings are
# needed beyond flipping the family, none of which the upstream manifest can
# infer:
#
#   --service-cluster-ip-range  defaults to 10.96.0.0/12, which is rejected
#                               outright once IPv4 is disabled.
#   --router-id                 BGP router IDs are 32-bit and are normally
#                               derived from an IPv4 address; with an IPv6
#                               primary node IP there is nothing to derive one
#                               from, so kube-router refuses to start unless it
#                               is told to generate one.

declare -r MANIFEST="https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml"

function main() {
	declare -r STATE_FILE="$1"
	declare -r KUBECONFIG_PATH="$2"

	declare IP_FAMILY="$(yq eval '.ipFamily // "ipv4"' "$STATE_FILE")"
	declare SERVICE_CIDR="$(yq eval '.cluster.serviceCIDR // ""' "$STATE_FILE")"

	KUBECONFIG="$KUBECONFIG_PATH" kubectl apply -f "$MANIFEST"

	if [[ $IP_FAMILY != "ipv6" ]]; then
		return 0
	fi

	declare -a EXTRA_ARGS=(
		"--enable-ipv4=false"
		"--enable-ipv6=true"
		"--service-cluster-ip-range=${SERVICE_CIDR}"
		"--router-id=generate"
	)

	declare PATCH="["
	for arg in "${EXTRA_ARGS[@]}"; do
		PATCH+="{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"${arg}\"},"
	done
	PATCH="${PATCH%,}]"

	KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system patch ds kube-router --type=json -p="$PATCH"
	KUBECONFIG="$KUBECONFIG_PATH" kubectl -n kube-system rollout status ds kube-router --timeout=180s
}

main "$@"
