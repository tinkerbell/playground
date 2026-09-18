#!/usr/bin/env bash

# Reading values a playground recorded about itself.
#
# `declare -r x="$(yq ...)"` looks safe under `set -e` but is not: the exit
# status belongs to `declare`, not to the substitution, so a missing state file
# or absent field yields an empty string and the script carries on. Empty values
# are then passed to docker as a container name, or to make as an image tag,
# and the failure surfaces somewhere far from its cause -- or does not surface
# at all, as with a release that finds no container to release.
#
# Meant to be sourced, not run.

# Read a field that must be there. Fails loudly rather than returning empty.
#
# Not for booleans: this rests on `yq -e`, which reports a false value the same
# way it reports a missing one, so a legitimate `false` would be rejected.
function state_field() {
	declare -r file="$1" path="$2"

	declare value
	if ! value="$(yq eval -e "$path" "$file" 2>/dev/null)" || [[ -z $value ]]; then
		echo "state: ${file} has no ${path}" >&2
		return 1
	fi
	printf '%s' "$value"
}
