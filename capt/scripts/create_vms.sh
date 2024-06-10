#!/bin/bash

set -euo pipefail

# Create VMs

function main() {
    declare -r STATE_FILE="$1"
    declare -r OUTPUT_DIR=$(yq eval '.outputDir' "$STATE_FILE")
    declare BRIDGE_NAME="$(yq eval '.kind.bridgeName' "$STATE_FILE")"
    declare CPUS="$(yq eval '.vm.cpusPerVM' "$STATE_FILE")"
    declare MEM="$(yq eval '.vm.memInMBPerVM' "$STATE_FILE")"
    declare DISK_SIZE="$(yq eval '.vm.diskSizeInGBPerVM' "$STATE_FILE")"
    declare DISK_PATH="$(yq eval '.vm.diskPath' "$STATE_FILE")"

    while IFS=$',' read -r name mac; do
        # create the VM
        virt-install \
        --description "CAPT VM" \
        --ram "$MEM" --vcpus "$CPUS" \
        --os-variant "ubuntu20.04" \
        --graphics "vnc" \
        --boot "uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=yes" \
        --noautoconsole \
        --noreboot \
        --import \
        --connect "qemu:///system" \
        --name "$name" \
        --disk "path=$DISK_PATH/$name-disk.img,bus=virtio,size=10,sparse=yes" \
        --network "bridge:$BRIDGE_NAME,mac=$mac"
    done < <(yq e '.vm.details.[] | [key, .mac] | @csv' "$STATE_FILE")
}

main "$@"