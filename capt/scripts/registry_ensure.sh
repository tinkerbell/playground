#!/usr/bin/env bash

set -euo pipefail

# Bring up the registry that carries locally built Tinkerbell images, sharing it
# with any other playground on the host.
#
# A registry is unavoidable for the agent image: CaptainOS pulls
# `tink_worker_image` at boot with its own containerd, which cannot be handed a
# file. It is shared for the same reason the vBMC is -- one build serves every
# playground -- and joined to each playground's network as that playground
# appears, which makes the attached-network count the reference count. See
# registry_release.sh.
#
# Two endpoints, deliberately:
#   - pushes go to 127.0.0.1:<port>, which is stable and instance-independent,
#     and which docker and buildkit both treat as insecure without configuration.
#   - pulls use the container's address on each playground's network, because
#     that is the only address the machines and kind nodes can reach.
# Same registry either way, and the repository path is identical, so a manifest
# pushed via one is found via the other. Nothing is retagged.
#
# Images outlive the container: they sit in a named volume, so tearing down
# every playground and starting again still finds the build published and skips
# it. `docker volume rm capt-registry-data` is the way to forget them.
#
# Usage: registry_ensure.sh <state-file> <image> <port>

declare -r BUILDER="capt-playground"
declare -r VOLUME="capt-registry-data"

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

function ensure_container() {
	declare -r container="$1" image="$2" network="$3" port="$4"

	if docker inspect "$container" >/dev/null 2>&1; then
		return 0
	fi

	docker run -d \
		--network "$network" \
		--restart unless-stopped \
		-p "127.0.0.1:${port}:5000" \
		-v "${VOLUME}:/var/lib/registry" \
		--name "$container" \
		"$image" >/dev/null
}

# buildx's default driver runs the build inside its own container, where
# `localhost` is that container rather than the host, so a push to the published
# port dies with "connection refused". Giving the builder the host's network
# namespace is what makes the Makefile's own push targets usable unchanged.
function ensure_builder() {
	if docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
		return 0
	fi

	docker buildx create --name "$BUILDER" --driver docker-container \
		--driver-opt network=host >/dev/null
}

function main() {
	declare -r state_file="$1" image="$2" port="$3"

	declare container network
	container="$(state_field "$state_file" '.source.registryContainer')"
	network="$(state_field "$state_file" '.names.network')"

	ensure_container "$container" "$image" "$network" "$port"
	ensure_builder

	# Already attached when this playground created the container, and when a
	# create is re-run. Joining twice is an error, so ask first.
	if ! docker inspect "$container" -f '{{range $net, $_ := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}' |
		grep -qxF "$network"; then
		docker network connect "$network" "$container"
	fi

	# The registry answers before it is listening, briefly, and the publish that
	# follows is the first thing to touch it.
	declare attempt
	for attempt in $(seq 1 30); do
		if curl -fsS -o /dev/null "http://127.0.0.1:${port}/v2/"; then
			return 0
		fi
		sleep 1
	done

	echo "registry: no response from 127.0.0.1:${port} after 30s" >&2
	return 1
}

main "$@"
