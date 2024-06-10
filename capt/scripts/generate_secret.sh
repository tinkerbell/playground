#!/bin/bash

# Generate secret. All machines share the same secret. The only customization is the namespace, user name, and password.

function main() {
	declare -r STATE_FILE="$1"
	declare -r OUTPUT_DIR=$(yq eval '.outputDir' "$STATE_FILE")
	export NAMESPACE=$(yq eval '.namespace' "$STATE_FILE")
	export BMC_USER_BASE64=$(yq eval '.virtualBMC.user' "$STATE_FILE" | tr -d '\n' | base64)
	export BMC_PASS_BASE64=$(yq eval '.virtualBMC.pass' "$STATE_FILE" | tr -d '\n' | base64)

	envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" <templates/bmc-secret.tmpl >"$OUTPUT_DIR"/bmc-secret.yaml
	unset BMC_USER_BASE64
	unset BMC_PASS_BASE64
	unset NAMESPACE
}

main "$@"
