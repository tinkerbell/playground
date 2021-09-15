#!/usr/bin/env bash
# This script handles downloading, extracting, and copying/moving files in place
# for OSIE and Hook. For more info on OSIE and Hook, see: https://docs.tinkerbell.org/services/osie/

set -xo pipefail

# osie_download from url and save it to directory
# requires a filename so that any subsequent calls can check if the file has been downloaded
osie_download() {
	local url="$1"
	local directory="$2"
	local filename="$3"
	wget "${url}" -O "${directory}"/"${filename}".tar.gz
}

# hook_extract Hook from a tarball and save it to directory
hook_extract() {
	local source_dir="$1"
	local dest_dir="$2"
	local filename="$3"
	tar -zxvf "${source_dir}"/"${filename}".tar.gz -C "${dest_dir}"
}

# osie_extract from tarball and save it to directory
osie_extract() {
	local source_dir="$1"
	local dest_dir="$2"
	local filename="$3"
	tar -zxvf "${source_dir}"/"${filename}".tar.gz -C "${dest_dir}" --strip-components 1
}

# osie_move_helper_scripts moves workflow helper scripts to the workflow directory
osie_move_helper_scripts() {
	local source_dir="$1"
	local dest_dir="$2"
	cp "${source_dir}"/workflow-helper.sh "${source_dir}"/workflow-helper-rc "${dest_dir}"/
}

# hook_rename_files renames the kernel and initrd files from the github downloaded tar
# to the default names that the OSIE installer in Boots is expecting.
# See https://github.com/tinkerbell/boots/blob/78d4f74e6944ae3bd04e1297dc8e354fc93d9320/installers/osie/main.go#L160 and
# https://github.com/tinkerbell/boots/blob/78d4f74e6944ae3bd04e1297dc8e354fc93d9320/installers/osie/main.go#L168
hook_rename_files() {
	local src_kernel="$1"
	local src_initrd="$2"
	local dest_dir="$3"
	mv "${src_kernel}" "${dest_dir}/vmlinuz-x86_64"
	mv "${src_initrd}" "${dest_dir}/initramfs-x86_64"
}

# process_osie_files processes the OSIE files and moves them to the correct location
process_osie_file() {
	local url="$1"
	local filename="$2"
	local extract_dir="$3"
	local source_dir="$4"
	local dest_dir="$5"
	local use_hook="$6"

	if [ ! -f "${extract_dir}"/"${filename}".tar.gz ]; then
		echo "downloading osie..."
		osie_download "${url}" "${extract_dir}" "${filename}"
		if [ "${use_hook}" == "true" ]; then
			echo "extracting hook..."
			hook_extract "${extract_dir}" "${source_dir}" "${filename}"
		else
			echo "extracting osie..."
			osie_extract "${extract_dir}" "${source_dir}" "${filename}"
			osie_move_helper_scripts "${source_dir}" "${dest_dir}"
		fi
	else
		echo "osie already downloaded"
	fi
}

# main runs the functions in order to download, extract, and move helper scripts
main() {
	local urls="$1"
	local extract_dir="$2"
	local source_dir="$3"
	local dest_dir="$4"
	local use_hook="$5"

	# create an array using the urls variable, delimited by commas (IFS=,)
	# store the array in the variable "urls_array"
	IFS=, read -ra urls_array <<<"${urls}"
	for index in "${!urls_array[@]}"; do
		echo "$index: ${urls_array[$index]}"
		local filename
		if [ "${use_hook}" == "true" ]; then
			filename="osie-hook-${index}"
		else
			filename="osie-${index}"
		fi
		process_osie_file "${urls_array[$index]}" "${filename}" "${extract_dir}" "${source_dir}" "${dest_dir}" "${use_hook}"
	done
}

main "$1" "$2" "$3" "$4" "$5"
