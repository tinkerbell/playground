#!/bin/bash

set -euo pipefail

# Register and start this playground's VMs in the shared vBMC container.
#
# Ports come from the state file, assigned by vbmc_ports.sh before the BMC
# Machine CRs were rendered with them.
#
# The status check at the end is not decoration. `vbmc start` exits 0 even when
# it fails to bind: a port taken by another playground leaves the entry `error`
# in `vbmc list` with an "Address in use" traceback in the container log, and
# nothing else would notice.

function vbmc_status_of() {
	declare -r container="$1" want="$2"

	docker exec "$container" vbmc list 2>/dev/null |
		awk -F'|' -v want="$want" 'NF >= 5 { gsub(/ /, "", $2); gsub(/ /, "", $3); if ($2 == want) print $3 }'
}

function vbmc_port_of() {
	declare -r container="$1" want="$2"

	docker exec "$container" vbmc list 2>/dev/null |
		awk -F'|' -v want="$want" 'NF >= 5 { gsub(/ /, "", $2); gsub(/ /, "", $5); if ($2 == want) print $5 }'
}

function main() {
	declare -r STATE_FILE="$1"

	declare -r username=$(yq eval '.virtualBMC.user' "$STATE_FILE")
	declare -r password=$(yq eval '.virtualBMC.pass' "$STATE_FILE")
	declare -r container_name=$(yq eval '.virtualBMC.containerName' "$STATE_FILE")

	declare name port status registered
	while IFS=$',' read -r name port; do
		status="$(vbmc_status_of "$container_name" "$name")"
		registered="$(vbmc_port_of "$container_name" "$name")"

		# An entry that failed to bind keeps the port it failed on, so a re-run
		# carrying a freshly assigned one has to replace the registration rather
		# than keep it. Without this the retry the error below promises is not
		# one: the same conflicted port would be started again.
		if [[ -n $status ]] && { [[ $status == "error" ]] || [[ $registered != "$port" ]]; }; then
			docker exec "$container_name" vbmc stop "$name" >/dev/null 2>&1 || true
			docker exec "$container_name" vbmc delete "$name"
			status=""
		fi

		# The container is shared and outlives any one playground, so a re-run
		# can find its own entries already there; adding twice is an error.
		if [[ -z $status ]]; then
			docker exec "$container_name" vbmc add --username "$username" --password "$password" --port "$port" "$name"
		fi
		docker exec "$container_name" vbmc start "$name"
	done < <(yq e '.vm.details.[] | [key, .bmc.port] | @csv' "$STATE_FILE")

	declare failed=0 status
	while IFS=$',' read -r name port; do
		status="$(vbmc_status_of "$container_name" "$name")"
		if [[ $status != "running" ]]; then
			echo "vbmc for ${name} is '${status:-missing}' on port ${port}, not running" >&2
			failed=1
		fi
	done < <(yq e '.vm.details.[] | [key, .bmc.port] | @csv' "$STATE_FILE")

	if [[ $failed -ne 0 ]]; then
		cat >&2 <<-EOF

			The shared vBMC could not serve every VM. The usual cause is another
			playground holding one of these ports: they are assigned from what was
			free when this playground was created, and a playground started in
			between can take one.

			Re-running 'task create-playground' reassigns the ports and re-renders
			the BMC Machine CRs that carry them. Container log:

			  docker logs ${container_name}
		EOF
		return 1
	fi
}

main "$@"
