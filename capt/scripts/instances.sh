#!/usr/bin/env bash

set -euo pipefail

# List the playgrounds currently on this host.
#
# Several can run at once, so "what is running?" stops being obvious. The
# answer is read back off the docker networks' labels rather than any record
# the playground keeps, which means it is right even for a playground whose
# state file was lost, and never lists one that is already gone.
#
# Usage: instances.sh [--quiet]
#   --quiet prints instance ids only, one per line

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/capt-playground/src"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib_instances.sh"

function main() {
	declare -r quiet="${1:-}"

	declare -a rows=()
	declare network id family subnet6 clusters source
	while read -r network; do
		[[ -n $network ]] || continue

		id="$(docker network inspect "$network" -f "{{index .Labels \"${CAPT_LABEL_ID}\"}}" 2>/dev/null || true)"
		if [[ $quiet == "--quiet" ]]; then
			echo "$id"
			continue
		fi

		family="$(docker network inspect "$network" -f "{{index .Labels \"${CAPT_LABEL_FAMILY}\"}}" 2>/dev/null || true)"
		subnet6="$(docker network inspect "$network" \
			-f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' 2>/dev/null | grep ':' || true)"
		# kind names its clusters after the network here, so a prefix match
		# finds both the management and the Tinkerbell cluster.
		clusters="$(kind get clusters 2>/dev/null | grep -c "^${network}" || true)"
		source="$(repo_label "$(source_dir_of "$network")")"

		rows+=("${id}|${network}|${family}|${subnet6:--}|${clusters}|${source}")
	done < <(capt_networks)

	[[ $quiet != "--quiet" ]] || return 0

	if [[ ${#rows[@]} -eq 0 ]]; then
		echo "No playgrounds running."
		# Still worth saying: the checkouts survive teardown, so with nothing
		# running they are the only thing left on the host to account for.
		source_cache
		return 0
	fi

	{
		echo "INSTANCE|NETWORK|FAMILY|SUBNET6|CLUSTERS|SOURCE"
		printf '%s\n' "${rows[@]}"
	} | column -t -s '|'

	echo
	echo "Shared services:"
	printf '  %-8s %s\n' "vbmc" "$(shared_status capt-vbmc 'up, serving {{len .NetworkSettings.Networks}} playground(s)')"
	printf '  %-8s %s\n' "nat64" "$(shared_status nat64 'up')"
	printf '  %-8s %s\n' "registry" "$(shared_status capt-registry 'up, serving {{len .NetworkSettings.Networks}} playground(s)')"

	source_cache
}

# The source checkouts outlive every playground, so nothing else would ever
# mention them. Listed here because this is where someone looks to find out what
# the playground has left on the host, and marked with the playgrounds using
# them so it is clear which are only taking up disk.
function source_cache() {
	if [[ ! -d $CACHE_DIR ]]; then
		return 0
	fi

	declare -a rows=() unused=()
	declare dir users
	for dir in "$CACHE_DIR"/*/; do
		[[ -d $dir ]] || continue
		users="$(instances_using "$dir")"
		[[ -n $users ]] || {
			users="(unused)"
			unused+=("$(basename "$dir")")
		}
		rows+=("  $(du -sh "$dir" 2>/dev/null | cut -f1)|$(basename "$dir")|$(git -C "$dir" remote get-url origin 2>/dev/null || echo '?')|${users}")
	done

	[[ ${#rows[@]} -gt 0 ]] || return 0

	echo
	echo "Source checkouts ($(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1) in ${CACHE_DIR}, kept across teardowns):"
	{
		# The directory is named for a hash of the repo, so it has to be shown:
		# there is no way to work back to it from the repo alone.
		echo "  SIZE|DIR|REPO|USED BY"
		printf '%s\n' "${rows[@]}"
	} | column -t -s '|'

	if [[ ${#unused[@]} -gt 0 ]]; then
		echo
		echo "  ${#unused[@]} unused; remove with:"
		# The lock file sits beside the checkout rather than inside it, so a
		# removal naming only the directory leaves it behind.
		printf "    rm -rf ${CACHE_DIR}/%s{,.lock}\n" "${unused[@]}"
	fi
}

# Which live playgrounds were built from a given checkout. A checkout is shared,
# so this is a list rather than one answer.
function instances_using() {
	declare -r dir="${1%/}"

	declare network ids=""
	while read -r network; do
		[[ -n $network ]] || continue
		if [[ "$(source_dir_of "$network")" == "$dir" ]]; then
			ids+="${ids:+,}$(docker network inspect "$network" -f "{{index .Labels \"${CAPT_LABEL_ID}\"}}" 2>/dev/null || true)"
		fi
	done < <(capt_networks)
	echo "$ids"
}

function source_dir_of() {
	declare -r network="$1"

	docker network inspect "$network" -f "{{index .Labels \"${CAPT_LABEL_SOURCE}\"}}" 2>/dev/null || true
}

# A repo the width of a table column. Keeps the owner so a fork is still
# distinguishable from upstream.
function repo_label() {
	declare -r dir="${1%/}"

	if [[ -z $dir ]]; then
		echo "-"
		return 0
	fi

	declare repo
	repo="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
	[[ -n $repo ]] || {
		echo "$dir"
		return 0
	}

	repo="${repo%.git}"
	echo "$(basename "$(dirname "$repo")")/$(basename "$repo")"
}

# docker inspect writes a blank line to stdout as well as an error to stderr
# when the container is missing, so the miss has to be handled before the
# format string runs.
function shared_status() {
	declare -r container="$1" format="$2"

	if ! docker inspect "$container" >/dev/null 2>&1; then
		echo "not running"
		return 0
	fi
	docker inspect "$container" -f "$format" 2>/dev/null
}

main "$@"
