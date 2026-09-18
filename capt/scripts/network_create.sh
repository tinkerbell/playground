#!/usr/bin/env bash

set -euo pipefail

# Create the playground's docker network on an IPv6 /64 nobody else is using.
#
# Every address the playground derives -- node IPs, the Tinkerbell VIPs, the
# DNS64 resolver -- is an offset from this subnet, so two playgrounds sharing
# one would hand out the same addresses on different bridges. A fixed subnet
# is therefore only safe while exactly one playground exists.
#
# Allocation needs no registry and no lock. Docker already knows every subnet
# in use and refuses to create a network overlapping one, atomically, so the
# daemon itself is the arbiter: pick the lowest free index, try it, and on
# rejection look again. Two concurrent creates cannot both win, and a crashed
# playground frees its index simply by its network going away.
#
# Index 0 is fd00:cafe::/64, which is what a lone playground has always used.
#
# Usage: network_create.sh <network-name> <instance-id> <ip-family> [source-dir]

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_instances.sh"

# Deliberately not kind's own fc00:f853:ccd:e793::/64, which would collide with
# an existing `kind` network on the same host.
declare -r PREFIX="fd00:cafe"
declare -r MAX_INDEX=255

function subnet_for() {
	declare -r index="$1"
	if [[ $index -eq 0 ]]; then
		echo "${PREFIX}::/64"
	else
		printf '%s:%x::/64\n' "$PREFIX" "$index"
	fi
}

# The address docker would pick for the bridge anyway. Asking for it by name
# is what makes `docker network inspect` report it: engines before 29 echo the
# IPAM config back as it was requested, so an auto-assigned IPv6 gateway is
# reported as "" and everything the playground derives from it comes out empty.
function gateway_for() {
	declare -r subnet="$1"
	echo "${subnet%::/64}::1"
}

# Subnets docker has already handed out, across every network it knows.
function subnets_in_use() {
	declare network
	for network in $(docker network ls --format '{{.Name}}'); do
		docker network inspect "$network" \
			-f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' 2>/dev/null || true
	done
}

function main() {
	declare -r network_name="$1"
	declare -r instance_id="$2"
	declare -r ip_family="$3"
	declare -r source_dir="${4:-}"

	if docker network inspect "$network_name" >/dev/null 2>&1; then
		return 0
	fi

	# The instance id is a hash of the state file's path, so a second network
	# already carrying it means two different playgrounds hashed the same --
	# rare, but it would have them fighting over every derived name. Better to
	# say so than to half-build the second one.
	declare -r holder="$(docker network ls --filter "label=${CAPT_LABEL_ID}=${instance_id}" --format '{{.Name}}' | head -1)"
	if [[ -n $holder ]]; then
		cat >&2 <<-EOF
			instance id ${instance_id} is already held by the network '${holder}',
			but this playground wants to create '${network_name}'.

			Two playgrounds have hashed their state file paths to the same id.
			Move or rename this playground's state file to change its id:

			  task create-playground STATE_FILE=<a different path>
		EOF
		return 1
	fi

	declare -r in_use="$(subnets_in_use)"
	declare index subnet
	for ((index = 0; index <= MAX_INDEX; index++)); do
		subnet="$(subnet_for "$index")"
		if grep -qxF "$subnet" <<<"$in_use"; then
			continue
		fi

		# The flags mirror what kind itself passes, so a playground-created
		# network is indistinguishable from a kind-created one.
		# enable_ip_masquerade is what NATs the bridge out to the host's IPv4
		# uplink; it is how NAT64 reaches IPv4-only upstreams. The IPv4 subnet
		# is left to docker's allocator so it cannot collide either.
		#
		# The labels are how the rest of the playground finds live instances
		# without keeping a registry of its own: which playgrounds exist, and
		# which of them still need the shared IPv6 services.
		if docker network create \
			--driver bridge \
			--ipv6 \
			--subnet "$subnet" \
			--gateway "$(gateway_for "$subnet")" \
			-o com.docker.network.bridge.enable_ip_masquerade=true \
			--label "capt.playground.id=${instance_id}" \
			--label "capt.playground.ipfamily=${ip_family}" \
			--label "capt.playground.source=${source_dir}" \
			"$network_name" >/dev/null 2>&1; then
			echo "allocated ${subnet} to ${network_name}"
			return 0
		fi

		# Either another playground took this subnet between the scan and now,
		# or the create failed for an unrelated reason. Retrying the next index
		# distinguishes them: a real failure exhausts the range and reports.
		if docker network inspect "$network_name" >/dev/null 2>&1; then
			return 0
		fi
	done

	echo "no free ${PREFIX}:*::/64 subnet in ${MAX_INDEX} tries; is something else using them?" >&2
	return 1
}

main "$@"
