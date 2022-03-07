#!/usr/bin/env sh
# This script is needed because we prefer bash scripts but
# the pre-built tink-worker container image is alpine and does not
# have bash naively installed.

set -x

# install_bash install bash, needed when running this script in an Alpine container, like tink-worker image
install_bash() {
	apk update
	apk add bash
}

# main runs the functions
main() {
	install_bash
	bash "${GLUE_SCRIPT_NAME}" "$@"
}

main "$@"
