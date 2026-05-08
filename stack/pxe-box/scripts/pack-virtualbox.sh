#!/usr/bin/env bash
# Pack a raw FAT32 disk image as a Vagrant VirtualBox .box for the given arch.
#
# Usage: pack-virtualbox.sh <amd64|arm64> <input.img> <output.box>
set -euo pipefail

arch=${1:?arch required}; raw=${2:?input img required}; out=${3:?output .box required}
here=$(cd "$(dirname "$0")/.." && pwd)

case "$arch" in
  amd64) ostype=Ubuntu_64;    platform=x86; chipset=ich9;          gfx=VBoxVGA ;;
  arm64) ostype=Ubuntu_arm64; platform=ARM; chipset=ARMv8Virtual;  gfx=QemuRamFB ;;
  *) echo "unknown arch: $arch" >&2; exit 1 ;;
esac

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

echo "==> converting raw -> stream-optimized VMDK"
qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$raw" "$work/box-disk.vmdk"

# size of the original raw (uncompressed virtual size for the OVF)
disk_bytes=$(wc -c < "$raw" | tr -d ' ')

vm_uuid=$(uuidgen | tr 'A-Z' 'a-z')
disk_uuid=$(uuidgen | tr 'A-Z' 'a-z')

echo "==> rendering OVF"
sed \
  -e "s|@@UUID@@|$vm_uuid|g" \
  -e "s|@@DISK_UUID@@|$disk_uuid|g" \
  -e "s|@@DISK_BYTES@@|$disk_bytes|g" \
  -e "s|@@OSTYPE@@|$ostype|g" \
  -e "s|@@PLATFORM@@|$platform|g" \
  -e "s|@@CHIPSET@@|$chipset|g" \
  -e "s|@@GFX@@|$gfx|g" \
  "$here/templates/box.ovf.tmpl" > "$work/box.ovf"

cp "$here/templates/Vagrantfile.vbox" "$work/Vagrantfile"
cat > "$work/metadata.json" <<JSON
{"provider":"virtualbox"}
JSON

echo "==> archiving $out"
tar -C "$work" -czf "$out" box.ovf box-disk.vmdk Vagrantfile metadata.json
echo "==> done: $out"
