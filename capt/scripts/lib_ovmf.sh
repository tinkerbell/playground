#!/usr/bin/env bash

# Firmware selection for VM creation and for sushy-tools.
#
# The flox environment pins OVMF. When it is active the firmware is named
# explicitly so every VM boots that exact build; otherwise libvirt picks the
# firmware itself, since the distro paths vary (Debian /usr/share/OVMF,
# Fedora /usr/share/edk2/ovmf, Arch /usr/share/edk2/x64).
#
# libvirtd runs on the host and resolves <loader>/<nvram> there, which is why
# sushy-tools is handed host paths rather than the firmware being mounted into
# its container: it only writes the strings into the domain XML.
#
# The paths are resolved through to the store because qemu runs as libvirt-qemu,
# which cannot traverse the home directory the flox environment lives under.

function ovmf_code_path() {
	printf '%s' "$(readlink -f "${FLOX_ENV:-}/FV/OVMF_CODE.fd" 2>/dev/null)"
}

function ovmf_vars_path() {
	printf '%s' "$(readlink -f "${FLOX_ENV:-}/FV/OVMF_VARS.fd" 2>/dev/null)"
}

# ovmf_pinned reports whether the pinned firmware is usable.
function ovmf_pinned() {
	[[ -n ${FLOX_ENV:-} && -f "$(ovmf_code_path)" && -f "$(ovmf_vars_path)" ]]
}

# ovmf_boot_arg emits the virt-install --boot value.
function ovmf_boot_arg() {
	if ovmf_pinned; then
		printf 'loader=%s,loader.readonly=yes,loader.type=pflash,loader.secure=no,nvram.template=%s' \
			"$(ovmf_code_path)" "$(ovmf_vars_path)"
		return
	fi
	printf 'uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=yes'
}
