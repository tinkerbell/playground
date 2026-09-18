#!/usr/bin/env bash

set -euo pipefail

# Detach one playground from the shared registry, and remove it once nobody is
# left.
#
# The container is joined to a network per playground (see registry_ensure.sh),
# so the count of networks it is attached to is the reference count -- kept by
# docker rather than by us, and therefore unable to disagree with reality.
#
# Disconnecting has to happen before the playground's network is removed:
# docker refuses to delete a network that still has endpoints attached.
#
# Two things deliberately survive: the image volume, so a later run still finds
# its build published, and the buildx builder, which holds the layer cache that
# makes a rebuild bearable. Both are named, and removing them is a deliberate
# act rather than a side effect of tearing down a playground.
#
# Usage: registry_release.sh <state-file>

source "$(dirname "${BASH_SOURCE[0]}")/lib_instances.sh"

function main() {
	declare -r state_file="$1"

	# Read tolerantly: this runs partway through a teardown, and aborting here
	# would leave the steps after it unrun. An absent registry is also the normal
	# case -- the playground was not built from source.
	declare container network
	container="$(yq eval '.source.registryContainer // ""' "$state_file" 2>/dev/null || true)"
	network="$(yq eval '.names.network // ""' "$state_file" 2>/dev/null || true)"

	if [[ -z $container || -z $network ]]; then
		return 0
	fi

	if [[ -z $container ]] || ! docker inspect "$container" >/dev/null 2>&1; then
		return 0
	fi

	docker network disconnect "$network" "$container" >/dev/null 2>&1 || true

	if [[ "$(capt_container_network_count "$container")" -eq 0 ]]; then
		# Racing teardowns both get here; one removes it and the other finds it
		# already gone, which is why the failure is tolerated.
		docker rm -f "$container" >/dev/null 2>&1 || true
	fi
}

main "$@"
