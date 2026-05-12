#!/usr/bin/env bash
# Build a 64MB GPT raw disk image with a single EFI System Partition whose
# default UEFI loader is iPXE.
#
# Usage: build-disk.sh <amd64|arm64> <output.img>
#
# Requires: curl, dd, sgdisk (gdisk / gptfdisk), mtools >= 4.0 (mformat,mmd,mcopy
#           with @@offset syntax).
set -euo pipefail

arch=${1:?arch (amd64|arm64) required}
out=${2:?output path required}

case "$arch" in
amd64)
	url="https://boot.ipxe.org/x86_64-efi/snponly.efi"
	loader="BOOTX64.EFI"
	;;
arm64)
	url="https://boot.ipxe.org/arm64-efi/snponly.efi"
	loader="BOOTAA64.EFI"
	;;
*)
	echo "unknown arch: $arch" >&2
	exit 1
	;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading iPXE EFI for $arch"
curl -fsSL -o "$tmp/$loader" "$url"

echo "==> creating 64MB raw image"
dd if=/dev/zero of="$out" bs=1048576 count=64 status=none

echo "==> writing GPT with single ESP (type EF00)"
# Partition starts at sector 2048 (1MB) and runs to end-34 (sgdisk default).
sgdisk --clear \
	--new=1:2048:0 \
	--typecode=1:EF00 \
	--change-name=1:"EFI System Partition" \
	"$out" >/dev/null

# Byte offset of the ESP for mtools.
offset=$((2048 * 512))

echo "==> formatting ESP as FAT32 (offset=$offset)"
# mformat needs a drive letter mapping; supply via -i image@@offset.
# -F = FAT32, -v = label.
mformat -i "$out@@${offset}" -F -v IPXE ::

echo "==> populating \\EFI\\BOOT\\$loader"
mmd -i "$out@@${offset}" ::/EFI ::/EFI/BOOT
mcopy -i "$out@@${offset}" "$tmp/$loader" "::/EFI/BOOT/$loader"

echo "==> done: $out"
