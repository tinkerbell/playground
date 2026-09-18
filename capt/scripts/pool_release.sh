#!/usr/bin/env bash

set -euo pipefail

# Remove the shared libvirt storage pool once no playground is left using it.
#
# The pool is a directory pool sushy-tools attaches virtual media from. One is
# enough for every playground on the host, so like the vBMC it is created on
# demand and removed only when the last playground goes. "The last" is answered
# by the labels on the playground docker networks -- see lib_instances.sh --
# with this playground excluded, so the answer does not depend on whether its
# own network has been removed yet.
#
# The name is not ours to choose: sushy-tools hardcodes `default` in its
# libvirt driver, with no config key to override it. That is also libvirt's
# conventional pool name, so on a machine that uses libvirt for anything else
# `default` is somebody's real pool full of somebody's disks. Ownership is
# therefore checked before removing anything: the playground creates its pool
# pointing at a target directory of its own, and a pool pointing anywhere else
# was not created here and is left alone.
#
# Usage: pool_release.sh <state-file> <pool-name> <expected-target-dir>

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r LIBVIRT_URI="qemu:///system"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_instances.sh"

function pool_target() {
	declare -r pool="$1"

	virsh --connect "$LIBVIRT_URI" pool-dumpxml "$pool" 2>/dev/null |
		sed -n 's:.*<path>\(.*\)</path>.*:\1:p' | head -1
}

function main() {
	declare -r state_file="$1" pool="$2" expected_target="$3"

	declare -r instance_id="$(yq eval '.instance // ""' "$state_file")"

	if ! virsh --connect "$LIBVIRT_URI" pool-info "$pool" >/dev/null 2>&1; then
		return 0
	fi

	declare -r target="$(pool_target "$pool")"
	if [[ $target != "$expected_target" ]]; then
		echo "leaving the '${pool}' storage pool alone: it points at ${target:-an unknown path}, not ${expected_target}, so the playground did not create it"
		return 0
	fi

	if [[ -n "$(capt_networks "$instance_id")" ]]; then
		echo "leaving the '${pool}' storage pool: another playground is using it"
		return 0
	fi

	declare vol
	while read -r vol; do
		[[ -n $vol ]] || continue
		virsh --connect "$LIBVIRT_URI" vol-delete --pool "$pool" "$vol" >/dev/null 2>&1 || true
	done < <(virsh --connect "$LIBVIRT_URI" -q vol-list "$pool" 2>/dev/null | awk '{print $1}')

	virsh --connect "$LIBVIRT_URI" pool-destroy "$pool" >/dev/null 2>&1 || true
	virsh --connect "$LIBVIRT_URI" pool-undefine "$pool" >/dev/null 2>&1 || true
}

main "$@"
