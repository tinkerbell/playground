#!/bin/bash

set -euo pipefail

# This script creates the BMC machine yaml files needed for the CAPT playground.

function main() {
	declare -r STATE_FILE="$1"
	declare -r OUTPUT_DIR=$(yq eval '.outputDir' "$STATE_FILE")

	rm -f "$OUTPUT_DIR"/bmc-machine*.yaml

	namespace=$(yq eval '.namespace' "$STATE_FILE")
	bmc_ip=$(yq eval '.virtualBMC.ip' "$STATE_FILE")

	while IFS=$',' read -r name port; do
		export NODE_NAME="$name"
		export BMC_IP="$bmc_ip"
		export BMC_PORT="$port"
		export NAMESPACE="$namespace"
		envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" <templates/bmc-machine.tmpl >"$OUTPUT_DIR"/bmc-machine-"$NODE_NAME".yaml
		unset NODE_NAME
		unset BMC_IP
		unset BMC_PORT
		unset NAMESPACE
	done < <(yq e '.vm.details.[] | [key, .bmc.port] | @csv' "$STATE_FILE")
}

main "$@"
