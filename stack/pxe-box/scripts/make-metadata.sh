#!/usr/bin/env bash
# Emit a Vagrant Cloud-style top-level metadata.json that maps a single box
# name to all four (provider x architecture) artifacts.
#
# Usage: BASE_URL=https://host/path make-metadata.sh <name> <version>
set -euo pipefail

name=${1:?name required}
version=${2:?version required}
base_url=${BASE_URL:-https://example.invalid/pxe}

cat <<JSON
{
  "name": "$name",
  "versions": [
    {
      "version": "$version",
      "providers": [
        {
          "name": "virtualbox",
          "architecture": "amd64",
          "default_architecture": true,
          "url": "$base_url/$version/pxe-amd64-virtualbox.box"
        },
        {
          "name": "virtualbox",
          "architecture": "arm64",
          "default_architecture": false,
          "url": "$base_url/$version/pxe-arm64-virtualbox.box"
        },
        {
          "name": "libvirt",
          "architecture": "amd64",
          "default_architecture": true,
          "url": "$base_url/$version/pxe-amd64-libvirt.box"
        },
        {
          "name": "libvirt",
          "architecture": "arm64",
          "default_architecture": false,
          "url": "$base_url/$version/pxe-arm64-libvirt.box"
        }
      ]
    }
  ]
}
JSON
