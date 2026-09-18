#!/usr/bin/env bash

set -euo pipefail

# Build and publish the three Tinkerbell artifacts a playground needs.
#
# The repo already knows how to do all of this, so this only supplies the
# variables its targets expect. `IMAGE_NAME*` must not carry a tag where the
# target appends `:$(VERSION)` itself, and `build-push-image*` depend on the
# licence bundle but NOT on compilation, so `cross-compile*` has to be named
# alongside them.
#
# The two images are built differently on purpose:
#
#   tinkerbell - built locally with `image`, because it is loaded straight into
#                kind. Nothing pulls it over a network, so it needs no registry,
#                no address and no containerd configuration. kind's containerd
#                sets no `config_path`, so a certs.d drop-in would not be read
#                anyway.
#   tink-agent - pushed, because CaptainOS fetches it at boot with its own
#                containerd and cannot be handed a file.
#
# The chart is packaged rather than pushed. `helm-publish` runs a bare
# `helm push`, and a plain-HTTP registry needs `--plain-http`, which that target
# has no way to pass and helm has no environment variable for. Packaging is the
# part that matters anyway: `helm package --app-version` is what puts the build's
# version inside the chart, so the image tags follow from it and cannot drift.
#
# Publishing is skipped when the work is already done -- which is the whole
# reason artifacts are tagged by commit. A dirty tree is the exception: its
# contents can change without its version changing, so it is always rebuilt.
#
# Usage: source_publish.sh <state-file> <push-endpoint> [--check]
#   --check exits 0 when there is nothing left to build, so the task can skip
#           itself rather than re-deciding in the script every run

declare -r BUILDER="capt-playground"

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib_state.sh"

function already_published() {
	declare -r endpoint="$1" version="$2" image="$3"

	docker image inspect "${image}:${version}" >/dev/null 2>&1 || return 1

	curl -fsS "http://${endpoint}/v2/tink-agent/tags/list" 2>/dev/null |
		yq -p json -e ".tags // [] | contains([\"${version}\"])" >/dev/null 2>&1
}

# Run make from inside the checkout rather than with `make -C`. The repo's
# Makefile derives TOOLS_DIR from $(PWD), which is the shell's environment
# variable and not make's working directory, so -C would install its tools into
# whatever directory the playground happened to be invoked from and then fail to
# find them.
function run_make() {
	declare -r dir="$1"
	shift

	(cd "$dir" && "$@")
}

function publish_images() {
	declare -r dir="$1" endpoint="$2" version="$3" image="$4"

	run_make "$dir" make image IMAGE_NAME="${image}:${version}" VERSION="$version"

	run_make "$dir" env BUILDX_BUILDER="$BUILDER" make cross-compile-agent build-push-image-agent \
		IMAGE_NAME_AGENT="${endpoint}/tink-agent" VERSION="$version"
}

function package_chart() {
	declare -r dir="$1" version="$2"

	run_make "$dir" make helm-package VERSION="$version"
}

function main() {
	declare -r state_file="$1" endpoint="$2" mode="${3:-}"

	declare dir version dirty chart image
	dir="$(state_field "$state_file" '.source.dir')"
	version="$(state_field "$state_file" '.source.version')"
	chart="$(state_field "$state_file" '.chart.location')"
	image="$(state_field "$state_file" '.source.tinkerbellImage')"
	# Read plainly: `false` is a real answer here, and state_field cannot tell it
	# apart from a missing field.
	dirty="$(yq eval '.source.dirty // false' "$state_file")"

	# A dirty tree is never up to date: its contents can change without its
	# version changing, so there is nothing to compare against.
	declare up_to_date=false
	if [[ $dirty != "true" ]] && [[ -f $chart ]] && already_published "$endpoint" "$version" "$image"; then
		up_to_date=true
	fi

	if [[ $mode == "--check" ]]; then
		[[ $up_to_date == "true" ]]
		return $?
	fi

	if [[ $up_to_date == "true" ]]; then
		echo "source: ${version} already built, nothing to do"
		return 0
	fi

	publish_images "$dir" "$endpoint" "$version" "$image"
	package_chart "$dir" "$version"
}

main "$@"
