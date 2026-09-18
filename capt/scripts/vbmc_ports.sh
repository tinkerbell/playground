#!/usr/bin/env bash

set -euo pipefail

# Give this playground's VMs BMC ports nothing else in the shared vBMC is using,
# and record them in the state file.
#
# Ports are per container, and the container is shared, so 6231 can only belong
# to one playground on the host. The container's own registry -- `vbmc list` --
# is the record of what is taken, so there is nothing else to keep in sync.
#
# Allocation has to happen here, before the BMC Machine CRs are rendered with
# the ports in them, and not at registration time: `vbmc add` refuses a domain
# that does not exist yet, and the VMs are not built until later.
#
# vbmc will not arbitrate a conflict for us. `vbmc add` accepts a port already
# in use, and `vbmc start` then exits 0 having failed to bind, leaving the entry
# `error` in `vbmc list` and an "Address in use" traceback in the container log.
# virtualbmc.sh checks the listed status for exactly this reason.
#
# Scanning `vbmc list` alone is not enough, either. It only shows domains that
# have been registered, and registration happens much later -- after the VMs
# exist -- so two playgrounds created at the same time would both see an empty
# list and both take the same ports. The starting point is therefore derived
# from the instance id, which two playgrounds never share, and the scan is what
# keeps a derived block from landing on one already registered.
#
# Usage: vbmc_ports.sh <state-file> [--check]
#   --check exits 0 when the state file already holds the ports this would
#           assign, so the task can skip itself

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

declare -r BASE_PORT=6231
declare -r BLOCK=16
declare -r BLOCKS=512

# Where this playground starts looking. Spreading instances across the range by
# id means two concurrent creates do not begin at the same place, which is what
# the `vbmc list` scan cannot tell them.
function base_port_for() {
	declare -r instance_id="$1"

	if [[ -z $instance_id ]]; then
		echo "$BASE_PORT"
		return 0
	fi
	declare -r slot=$((0x${instance_id:0:4} % BLOCKS))
	echo $((BASE_PORT + slot * BLOCK))
}

# Ports already registered, whoever owns them. `vbmc list` renders a table:
# | domain | status | address | port |
function ports_in_use() {
	declare -r container="$1"

	docker exec "$container" vbmc list 2>/dev/null |
		awk -F'|' 'NF >= 5 { gsub(/ /, "", $5); if ($5 ~ /^[0-9]+$/) print $5 }' |
		sort -n
}

# Ports this playground already holds, so a re-run keeps the ports its CRs and
# registrations were built with rather than shuffling them.
#
# An entry in `error` state is not held: vbmc could not bind that port, so
# reusing it would fail the same way and a re-run could never recover. Treating
# it as absent is what sends the caller off to assign a free one, which is the
# recovery virtualbmc.sh tells the user to expect.
function existing_ports_for() {
	declare -r container="$1" state_file="$2"

	declare listing
	listing="$(docker exec "$container" vbmc list 2>/dev/null)" || return 1

	declare name entry status port
	while read -r name; do
		[[ -n $name ]] || continue
		entry="$(awk -F'|' -v want="$name" 'NF >= 5 {
			gsub(/ /, "", $2); gsub(/ /, "", $3); gsub(/ /, "", $5)
			if ($2 == want) print $3, $5
		}' <<<"$listing")"
		read -r status port <<<"$entry"
		[[ -n $port ]] || return 1
		[[ $status != "error" ]] || return 1
		echo "${name},${port}"
	done < <(yq eval '.vm.details | keys | .[]' "$state_file")
}

function main() {
	declare -r state_file="$1"
	declare -r mode="${2:-}"

	declare container instance_id
	container="$(state_field "$state_file" '.virtualBMC.containerName')"
	# The whole port range is derived from this, so an empty one would hand every
	# playground the same base port.
	instance_id="$(state_field "$state_file" '.instance')"

	declare assignments
	if assignments="$(existing_ports_for "$container" "$state_file")" && [[ -n $assignments ]]; then
		[[ $mode == "--check" ]] || echo "reusing the BMC ports already registered for this playground" >&2
	else
		declare taken
		taken="$(ports_in_use "$container")"
		assignments=""
		declare port
		port="$(base_port_for "$instance_id")"
		declare name
		while read -r name; do
			[[ -n $name ]] || continue
			while grep -qx "$port" <<<"$taken"; do
				port=$((port + 1))
			done
			assignments+="${name},${port}"$'\n'
			port=$((port + 1))
		done < <(yq eval '.vm.details | keys | .[]' "$state_file")
	fi

	declare name assigned current
	while IFS=, read -r name assigned; do
		[[ -n $name ]] || continue

		# --check answers the task's `status:`: the state file already holds
		# what this would write, so there is nothing to do.
		if [[ $mode == "--check" ]]; then
			current="$(name="$name" yq eval '.vm.details[strenv(name)].bmc.port // ""' "$state_file")"
			[[ $current == "$assigned" ]] || return 1
			continue
		fi

		# env() parses the value as YAML, so the port lands as an int; strenv()
		# would quote it and the CRs rendered from this expect a number.
		name="$name" port="$assigned" yq eval -i \
			'.vm.details[strenv(name)].bmc.port = env(port)' "$state_file"
	done <<<"$assignments"
}

main "$@"
