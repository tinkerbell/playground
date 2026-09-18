#!/usr/bin/env bash

set -euo pipefail

# Detach one playground from the shared vBMC, and remove it once nobody is left.
#
# The container is joined to a network per playground (see vbmc_ensure.sh), so
# the count of networks it is attached to is the reference count -- kept by
# docker, not by us, and therefore unable to disagree with reality. Dropping to
# zero means this was the last playground.
#
# Disconnecting also has to happen before the playground's network is removed:
# docker refuses to delete a network that still has endpoints attached.
#
# Usage: vbmc_release.sh <state-file>

declare -r SHARED_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/capt-playground/vbmc"

source "$(dirname "${BASH_SOURCE[0]}")/lib_instances.sh"

function main() {
	declare -r state_file="$1"

	declare container network
	# Read tolerantly and say so, rather than failing: this runs partway through a
	# teardown, and aborting here would leave the steps after it -- including the
	# network removal that releases everything else -- unrun.
	container="$(yq eval '.virtualBMC.containerName // ""' "$state_file" 2>/dev/null || true)"
	network="$(yq eval '.names.network // ""' "$state_file" 2>/dev/null || true)"

	if [[ -z $container || -z $network ]]; then
		echo "vbmc: ${state_file} records no vBMC to release" >&2
		return 0
	fi

	if ! docker inspect "$container" >/dev/null 2>&1; then
		return 0
	fi

	# Drop this playground's VMs first: left registered they would keep their
	# ports reserved against every other playground sharing the container.
	declare name
	while read -r name; do
		[[ -n $name ]] || continue
		docker exec "$container" vbmc delete "$name" >/dev/null 2>&1 || true
	done < <(yq eval '.vm.details | keys | .[]' "$state_file" 2>/dev/null || true)

	docker network disconnect "$network" "$container" >/dev/null 2>&1 || true

	if [[ "$(capt_container_network_count "$container")" -eq 0 ]]; then
		# Racing teardowns both get here; one removes it and the other finds it
		# already gone, which is why the failure is tolerated.
		docker rm -f "$container" >/dev/null 2>&1 || true
		rm -rf "$SHARED_DIR"
	fi
}

main "$@"
