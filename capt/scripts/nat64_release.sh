#!/usr/bin/env bash

set -euo pipefail

# Tear down this playground's DNS64, and the shared NAT64 translator once no
# other IPv6 playground is left.
#
# DNS64 is per playground -- it sits on that playground's own network at an
# address derived from its subnet -- so it always goes. NAT64 is shared and
# host-wide, so it may only go when nobody else needs it. "Nobody else" is
# answered by the labels on the docker networks (see lib_instances.sh), with
# this playground excluded: its own network may or may not have been removed
# yet, and the answer must not depend on which.
#
# `docker rm` is not enough for the translator. The TUN device is persistent
# (tayga --mktun) and the masquerade and forward rules live in the host's
# tables; both outlive the container and have to be undone explicitly.
#
# Not gated on ipFamily: switching a playground back to ipv4 and deleting it
# must still clean up what an earlier ipv6 run created. Forwarding sysctls are
# deliberately left on -- docker needs ip_forward regardless.
#
# Usage: nat64_release.sh <state-file> <cleanup-image> <tun-dev> <tayga-pool> <nat64-container>

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_instances.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_docker_net.sh"

function main() {
	declare -r state_file="$1" cleanup_image="$2" tun_dev="$3" tayga_pool="$4" nat64_container="$5"

	declare -r instance_id="$(yq eval '.instance // ""' "$state_file")"
	declare -r dns64_container="$(yq eval '.names.dns64 // ""' "$state_file")"

	if [[ -n $dns64_container ]]; then
		docker rm -f "$dns64_container" >/dev/null 2>&1 || true
	fi

	if [[ -n "$(capt_networks_with_family ipv6 "$instance_id")" ]]; then
		echo "leaving the shared NAT64 translator up: another IPv6 playground is using it"
		return 0
	fi

	docker rm -f "$nat64_container" >/dev/null 2>&1 || true

	docker run --rm --network host --privileged "$cleanup_image" sh \
		-c "${CLEANUP_PKGS} || true;
			${IPT_PICK};
			${IPT6_PICK};
			while \$IPT -t nat -D POSTROUTING -s ${tayga_pool} ! -o ${tun_dev} -j MASQUERADE 2>/dev/null; do :; done;
			for ipt in \$IPT \$IPT6; do
				for dir in -i -o; do
					while \$ipt -D FORWARD \$dir ${tun_dev} -j ACCEPT 2>/dev/null; do :; done;
				done;
			done;
			ip link del ${tun_dev} 2>/dev/null || true" >/dev/null 2>&1 || true
}

main "$@"
