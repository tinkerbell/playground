#!/usr/bin/env bash
# This script is designed to download a cloud image file (.img) and then convert it to a .raw.gz file.
# This is purpose built so non-raw cloud image files can be used with the "image2disk" action.
# See https://artifacthub.io/packages/tbaction/tinkerbell-community/image2disk.

set -euxo pipefail

image_url=$1
file=$2/${image_url##*/}
file=${file%.*}.raw.gz

if ! which pigz qemu-img &>/dev/null; then
	apk add --update pigz qemu-img
fi

if ! [[ -f $file ]]; then
	wget "$image_url" -O image.img
	qemu-img convert -O raw image.img image.raw
	pigz <image.raw >"$file"
	rm -f image.img image.raw
fi
