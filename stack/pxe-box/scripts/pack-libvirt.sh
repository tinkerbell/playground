#!/usr/bin/env bash
# Pack a raw FAT32 disk image as a Vagrant libvirt .box for the given arch.
#
# Usage: pack-libvirt.sh <amd64|arm64> <input.img> <output.box>
set -euo pipefail

arch=${1:?arch required}
raw=${2:?input img required}
out=${3:?output .box required}
here=$(cd "$(dirname "$0")/.." && pwd)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "==> converting raw -> qcow2"
qemu-img convert -f raw -O qcow2 "$raw" "$work/box.img"

# virtual_size is reported in GB; round up from raw byte size.
disk_bytes=$(wc -c <"$raw" | tr -d ' ')
virtual_size_gb=$(((disk_bytes + 1024 * 1024 * 1024 - 1) / (1024 * 1024 * 1024)))
[[ $virtual_size_gb -lt 1 ]] && virtual_size_gb=1

cp "$here/templates/Vagrantfile.libvirt" "$work/Vagrantfile"
cat >"$work/metadata.json" <<JSON
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": $virtual_size_gb
}
JSON

echo "==> archiving $out"
tar -C "$work" -czf "$out" box.img Vagrantfile metadata.json
echo "==> done: $out"
