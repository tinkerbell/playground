#!/usr/bin/env bash

set -euo pipefail

# Read one value the playground needs before, or after, its state file exists.
#
# Taskfile globals are resolved once, when `task` starts. Two of them --
# the output directory and the docker network name -- are needed by the very
# first create, when .state has not been written yet, and by every run after
# that, when it has. Neither can simply read .state, and neither should
# re-derive what cue/state already computes: a second copy of "join the output
# directory to the instance id" is a copy that can drift.
#
# So: read .state when it is there, and ask cue for the same field when it is
# not. One derivation, in cue, either way.
#
# Usage: state_value.sh <config> <state> <instance-id> <field>
#   field is a path into cue/state's `out`, e.g. outputDir, names.network

declare -r ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

function main() {
	declare -r config_file="$1"
	declare -r state_file="$2"
	declare -r instance_id="$3"
	declare -r field="$4"

	if [[ -f $state_file ]]; then
		declare value
		value="$(yq eval ".${field} // \"\"" "$state_file")"
		if [[ -n $value && $value != "null" ]]; then
			echo "$value"
			return 0
		fi
	fi

	# No state yet. cue/state derives every one of these from the config plus
	# the instance id alone, so none of the tags that only exist once the
	# docker network is up are needed here.
	(cd "$ROOT_DIR" && cue export ./cue/state yaml: "$config_file" -l 'config:' \
		-t cwd="$ROOT_DIR" \
		-t instanceID="$instance_id" \
		-e "out.${field}" --out text)
}

main "$@"
