#!/usr/bin/env bash
# This script handles downloading, extracting, and copying/moving files in place
# for OSIE and Hook. For more info on OSIE and Hook, see: https://docs.tinkerbell.org/services/osie/

set -euxo pipefail

# create an array using the urls variable, delimited by commas (IFS=,)
# store the array in the variable "urls"
IFS=, read -ra urls <<<"$1"
destdir=$2

for url in "${urls[@]}"; do
	filename="$destdir/${url##*/}"
	if [[ -f ${filename} ]]; then
		echo "$filename already downloaded"
		continue
	fi

	echo "downloading $url"
	wget "$url" -O "$filename.tmp"
	echo "extracting files..."
	tar -zxvf "$filename.tmp" -C "$destdir"
	mv "$filename.tmp" "$filename"
done
