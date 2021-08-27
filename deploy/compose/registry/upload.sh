#!/usr/bin/env bash
# This script handles uploading containers from one container registry to another.
# It assumes the target registry requires username and password authentication.

set -xo pipefail

main() {
	local reg_user="$1"
	local reg_pw="$2"
	local reg_url="$3"
	local images_file="$4"
	# this confusing IFS= and the || is to capture the last line of the file if there is no newline at the end
	while IFS= read -r img || [ -n "${img}" ]; do
		# file is expected to have src and dst images delimited by a space
		local src_img
		src_img="$(echo "${img}" | cut -d' ' -f1)"
		local dst_img
		dst_img="$(echo "${img}" | cut -d' ' -f2)"
		skopeo copy --all --dest-tls-verify=false --dest-creds="${reg_user}":"${reg_pw}" docker://"${src_img}" docker://"${reg_url}"/"${dst_img}"
	done <"${images_file}"
}

main "$1" "$2" "$3" "$4"
