#!/bin/bash

# Generate hardware

set -euo pipefail

function main() {
  # Generate hardware
  declare -r STATE_FILE="$1"
  declare -r OUTPUT_DIR=$(yq eval '.outputDir' "$STATE_FILE")
  declare -r NS=$(yq eval '.namespace' "$STATE_FILE")

  rm -f "$OUTPUT_DIR"/hardware*.yaml

  while IFS=$',' read -r name mac role ip gateway; do
    export NODE_NAME="$name"
    export NODE_MAC="$mac"
    export NODE_ROLE="$role"
    export NODE_IP="$ip"
    export GATEWAY_IP="$gateway"   
    export NAMESPACE="$NS"
    envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" < templates/hardware.tmpl > "$OUTPUT_DIR"/hardware-"$NODE_NAME".yaml
    unset NODE_ROLE
    unset NODE_NAME
    unset NODE_IP
    unset NODE_MAC
    unset GATEWAY_IP
  done < <(yq e '.vm.details.[] | [key, .mac, .role, .ip, .gateway] | @csv' "$STATE_FILE")

}

main "$@"