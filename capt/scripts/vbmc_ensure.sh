#!/usr/bin/env bash

set -euo pipefail

# Bring up the vBMC one playground needs, sharing it with any others.
#
# sushy-tools talks to libvirt, and libvirt is per host, so one container can
# serve every playground's VMs. It is reached over each playground's own docker
# network, so rather than running a copy per playground it is joined to each
# network as that playground appears. Being attached to N networks is also the
# reference count: see vbmc_release.sh.
#
# One container means one set of TLS material and one htpasswd, which is why
# they live beside the container rather than in any playground's output
# directory, and why the credentials are fixed in cue/state.
#
# Usage: vbmc_ensure.sh <state-file>

declare -r ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
declare -r SHARED_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/capt-playground/vbmc"

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

function ensure_credentials() {
	declare -r image="$1" username="$2" password="$3"

	mkdir -p "$SHARED_DIR"

	if [[ ! -f "${SHARED_DIR}/htpasswd" ]]; then
		# Password over stdin (-i) rather than argv (-b) so it does not show up
		# in `ps` or `docker ps --no-trunc` while htpasswd runs.
		printf '%s' "$password" |
			docker run -i --rm --entrypoint htpasswd "$image" -niB "$username" >"${SHARED_DIR}/htpasswd"
	fi

	if [[ ! -f "${SHARED_DIR}/sushy.key" || ! -f "${SHARED_DIR}/sushy.cert" ]]; then
		# -subj and -nodes keep this non-interactive: `-it` fails outright
		# whenever stdin is not a terminal, as in CI and test runners.
		docker run --rm --entrypoint openssl -v "${SHARED_DIR}:/scripts" "$image" \
			req -x509 -newkey rsa:2048 -keyout /scripts/sushy.key -out /scripts/sushy.cert \
			-days 365 -nodes \
			-subj "/C=US/ST=CA/L=Los Angeles/O=Engineering/OU=Engineering/CN=tinkerbell.org"
	fi
}

function ensure_container() {
	declare -r container="$1" image="$2" network="$3"

	if docker inspect "$container" >/dev/null 2>&1; then
		return 0
	fi

	docker run -d --privileged \
		--network "$network" \
		--restart unless-stopped \
		-e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
		-v /var/run/libvirt:/var/run/libvirt \
		-v "${SHARED_DIR}/sushy.key:/etc/sushy/sushy.key" \
		-v "${SHARED_DIR}/sushy.cert:/etc/sushy/sushy.cert" \
		-v "${SHARED_DIR}/htpasswd:/etc/sushy/htpasswd" \
		-v "${ROOT_DIR}/scripts/sushy-tools.conf:/etc/sushy/sushy-emulator.conf" \
		--name "$container" \
		"$image" >/dev/null
}

function main() {
	declare -r state_file="$1"

	declare container image username password network
	container="$(state_field "$state_file" '.virtualBMC.containerName')"
	image="$(state_field "$state_file" '.virtualBMC.image')"
	username="$(state_field "$state_file" '.virtualBMC.user')"
	password="$(state_field "$state_file" '.virtualBMC.pass')"
	network="$(state_field "$state_file" '.names.network')"

	ensure_credentials "$image" "$username" "$password"
	ensure_container "$container" "$image" "$network"

	# Already attached when this playground created the container, and when a
	# create is re-run. Joining twice is an error, so ask first.
	if ! docker inspect "$container" -f '{{range $net, $_ := .NetworkSettings.Networks}}{{$net}}{{"\n"}}{{end}}' |
		grep -qxF "$network"; then
		docker network connect "$network" "$container"
	fi
}

main "$@"
