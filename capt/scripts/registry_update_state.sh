#!/usr/bin/env bash

set -euo pipefail

# Record where this playground reaches the shared registry, and point the chart
# at what was built.
#
# The registry is one container attached to one network per playground, so its
# address differs per playground and is only knowable once that network exists.
# That is why these fields are patched in here rather than derived in
# cue/state/source_extension.cue with everything else.
#
# Only the machine pulls from it. CaptainOS fetches the agent image at boot with
# its own containerd, which cannot be handed a file, so the address has to be one
# the machine can reach -- in IPv6 mode that is an IPv6 address, bracketed, which
# is what containerd wants in an image reference. The Tinkerbell image never
# comes through here: it is loaded straight into kind.
#
# Usage: registry_update_state.sh <state-file> <registry-port> [--check]

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

function registry_endpoint() {
	declare -r state_file="$1" port="$2"

	declare container network family field address
	container="$(state_field "$state_file" '.source.registryContainer')"
	network="$(state_field "$state_file" '.names.network')"
	family="$(yq eval '.ipFamily // "ipv4"' "$state_file")"

	if [[ $family == "ipv6" ]]; then
		field="GlobalIPv6Address"
	else
		field="IPAddress"
	fi

	# Selected by network name rather than ranged over: the container is joined
	# to one network per playground, and ranging concatenates them all.
	address="$(docker inspect "$container" \
		-f "{{(index .NetworkSettings.Networks \"${network}\").${field}}}")"

	if [[ -z $address ]]; then
		echo "registry: ${container} has no ${field} on ${network}" >&2
		return 1
	fi

	if [[ $family == "ipv6" ]]; then
		printf '[%s]:%s' "$address" "$port"
	else
		printf '%s:%s' "$address" "$port"
	fi
}

function main() {
	declare -r state_file="$1" port="$2" mode="${3:-}"

	declare endpoint version
	endpoint="$(registry_endpoint "$state_file" "$port")"
	version="$(state_field "$state_file" '.source.version')"

	if [[ $mode == "--check" ]]; then
		[[ "$(yq eval '.source.registry // ""' "$state_file")" == "$endpoint" ]]
		return $?
	fi

	# agentImage is what Smee bakes into the kernel cmdline as tink_worker_image,
	# so it has to name an address the machine can reach. versions.chart follows
	# the build for the record: the chart is a file now, and helm ignores
	# --version for those.
	endpoint="$endpoint" version="$version" yq eval -i '
		.source.registry = strenv(endpoint) |
		.source.agentImage = strenv(endpoint) + "/tink-agent" |
		.agentImage = strenv(endpoint) + "/tink-agent" |
		.versions.chart = strenv(version)
	' "$state_file"
}

main "$@"
