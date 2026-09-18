#!/usr/bin/env bash

set -euo pipefail

# Bring up NAT64 for one playground, sharing the translator with any others.
#
# tayga lives in the host network namespace: the TUN device it creates, the
# route to the NAT64 prefix, and the masquerade rule are all host-wide. There
# can only be one, and one is all that is needed -- every playground's bridge
# reaches the same translator, so the prefix stays fixed and nothing about it
# has to be made per-instance.
#
# Everything it does outlives the container (`tayga --mktun` makes the TUN
# device persistent, the masquerade and forward rules land in the host's
# tables), which is why nat64_release.sh has to undo them explicitly rather
# than rely on `docker rm`.
#
# The forward rules matter on a host where docker had to enable IP forwarding
# itself: docker then sets the FORWARD policy to DROP and accepts only traffic
# arriving on one of its own bridges, and the translator's TUN device is not
# one. A host that already had forwarding on when dockerd started keeps an
# ACCEPT policy, so this is invisible there and only bites a clean machine.
#
# The bridge address, by contrast, IS per playground and is repaired on every
# call: docker assigns the IPv6 gateway to the bridge on a freshly created
# network, but a network that has been through a daemon restart can be missing
# it, and without it NAT64 replies to a machine's global address have no route
# home. The add is a no-op when docker already did it.
#
# Usage: nat64_ensure.sh <state-file> <image> <tun-dev> <tayga-ipv4> <tayga-pool> <container>

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_docker_net.sh"

function repair_bridge_address() {
	declare -r image="$1" gateway6="$2" bridge="$3" prefix_len="$4"

	[[ -n $gateway6 && -n $bridge && -n $prefix_len ]] || return 0

	docker run --rm --network host --privileged --entrypoint /bin/sh "$image" \
		-c "${NET_PKGS_IPROUTE}; ip -6 addr add ${gateway6}/${prefix_len} dev ${bridge} 2>/dev/null || true" \
		>/dev/null 2>&1 || true
}

function start_translator() {
	declare -r container="$1" image="$2" tun_dev="$3" tayga_ipv4="$4" tayga_pool="$5" prefix="$6"

	if [[ "$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)" == "running" ]]; then
		return 0
	fi
	docker rm -f "$container" >/dev/null 2>&1 || true

	docker run -d --name "$container" \
		--network host \
		--privileged \
		--device /dev/net/tun \
		--restart unless-stopped \
		--entrypoint /bin/sh \
		"$image" \
		-c "set -e;
			${NET_PKGS};
			${IPT_PICK};
			${IPT6_PICK};
			mkdir -p /var/spool/tayga;
			printf 'tun-device ${tun_dev}\nipv4-addr ${tayga_ipv4}\nprefix ${prefix}\ndynamic-pool ${tayga_pool}\ndata-dir /var/spool/tayga\n' > /etc/tayga.conf;
			tayga --mktun -c /etc/tayga.conf;
			ip link set ${tun_dev} up;
			ip addr add ${tayga_ipv4} dev ${tun_dev};
			ip route add ${tayga_pool} dev ${tun_dev};
			ip -6 route add ${prefix} dev ${tun_dev};
			\$IPT -t nat -C POSTROUTING -s ${tayga_pool} ! -o ${tun_dev} -j MASQUERADE 2>/dev/null ||
			\$IPT -t nat -A POSTROUTING -s ${tayga_pool} ! -o ${tun_dev} -j MASQUERADE;
			for ipt in \$IPT \$IPT6; do
				for dir in -i -o; do
					\$ipt -C FORWARD \$dir ${tun_dev} -j ACCEPT 2>/dev/null ||
					\$ipt -A FORWARD \$dir ${tun_dev} -j ACCEPT;
				done;
			done;
			exec tayga -d -c /etc/tayga.conf --nodetach" >/dev/null
}

function wait_for_route() {
	declare -r container="$1" tun_dev="$2" prefix="$3"

	declare _
	for _ in $(seq 1 30); do
		if ip -6 route show "$prefix" 2>/dev/null | grep -q "$tun_dev"; then
			return 0
		fi
		if [[ "$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)" != "running" ]]; then
			echo "nat64 exited during startup:" >&2
			docker logs --tail 20 "$container" >&2
			return 1
		fi
		sleep 1
	done

	echo "timed out waiting for the ${prefix} route" >&2
	docker logs --tail 20 "$container" >&2
	return 1
}

function main() {
	declare -r state_file="$1" image="$2" tun_dev="$3" tayga_ipv4="$4" tayga_pool="$5" container="$6"

	declare -r prefix="$(yq eval '.nat64.prefix // ""' "$state_file")"
	declare -r bridge="$(yq eval '.kind.bridgeName // ""' "$state_file")"
	declare -r gateway6="$(yq eval '.kind.gatewayIP6 // ""' "$state_file")"
	declare -r subnet6="$(yq eval '.kind.subnet6 // ""' "$state_file")"
	declare -r prefix_len="${subnet6##*/}"

	repair_bridge_address "$image" "$gateway6" "$bridge" "$prefix_len"
	start_translator "$container" "$image" "$tun_dev" "$tayga_ipv4" "$tayga_pool" "$prefix"
	wait_for_route "$container" "$tun_dev" "$prefix"
}

main "$@"
