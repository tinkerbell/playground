#!/usr/bin/env bash
# This script handles downloading, extracting, and copying/moving files in place
# for OSIE and Hook. For more info on OSIE and Hook, see: https://docs.tinkerbell.org/services/osie/

set -xo pipefail

# osie_download from url and save it to directory
osie_download() {
	local url="$1"
	local directory="$2"
	wget "${url}" -O "${directory}"/osie.tar.gz
}

# osie_extract from tarball and save it to directory
osie_extract() {
	local source_dir="$1"
	local dest_dir="$2"
	tar -zxvf "${source_dir}"/osie.tar.gz -C "${dest_dir}" --strip-components 1
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

# main runs the functions in order to download, extract, and move helper scripts
main() {
	local url="$1"
	local extract_dir="$2"
	local source_dir="$3"
	local dest_dir="$4"
	local use_hook="$5"

	if [ ! -f "${extract_dir}"/osie.tar.gz ]; then
		echo "downloading osie..."
		osie_download "${url}" "${extract_dir}"
	else
		echo "osie already downloaded"
	fi

	if [ "${use_hook}" == "true" ]; then
		if [ ! -f "${source_dir}"/hook-x86_64-kernel ] && [ ! -f "${source_dir}"/hook-x86_64-initrd.img ]; then
			echo "extracting hook..."
			osie_extract "${extract_dir}" "${source_dir}"
		else
			echo "hook files already exist, not extracting"
		fi
		hook_rename_files "${source_dir}"/hook-x86_64-kernel "${source_dir}"/hook-x86_64-initrd.img "${source_dir}"
	else
		if [ ! -f "${source_dir}"/workflow-helper.sh ] && [ ! -f "${source_dir}"/workflow-helper-rc ]; then
			echo "extracting osie..."
			osie_extract "${extract_dir}" "${source_dir}"
		else
			echo "osie files already exist, not extracting"
		fi
		osie_move_helper_scripts "${source_dir}" "${dest_dir}"
	fi
}

main "$1" "$2" "$3" "$4" "$5"
