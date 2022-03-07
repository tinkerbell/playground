#!/usr/bin/env bash

# This script is used to push (hardware) and create (template, workflow) Tink Server data/objects
# This script assumes that the `tink` binary is in the PATH and
# TINKERBELL_CERT_URL and TINKERBELL_GRPC_AUTHORITY environment variables are set
# See https://docs.tinkerbell.org/services/tink-cli/ for more details

set -euxo pipefail

# update_hw_ip_addr the hardware json with a specified IP address
update_hw_ip_addr() {
	local ip_address=$1
	local hw_file=$2
	local tmp
	tmp=$(mktemp "${hw_file}.XXXXXXXX")
	jq -S '.network.interfaces[0].dhcp.ip.address = "'"${ip_address}"'"' "${hw_file}" | tee "${tmp}"
	mv "${tmp}" "${hw_file}"
}

# update_hw_mac_addr the hardware json with a specified MAC address
update_hw_mac_addr() {
	local mac_address=$1
	local hw_file=$2
	local tmp
	tmp=$(mktemp "${hw_file}.XXXXXXXX")
	jq -S '.network.interfaces[0].dhcp.mac = "'"${mac_address}"'"' "${hw_file}" | tee "${tmp}"
	mv "${tmp}" "${hw_file}"
}

# hardware creates a hardware record in tink from the file_loc provided
hardware() {
	tink hardware push --file "$1" 2>/dev/null
}

# update_template_img_ip the template yaml with a specified IP address
update_template_img_ip() {
	local ip_address=$1
	local template_file=$2
	local tmp
	tmp=$(mktemp "${template_file}.XXXXXXXX")
	sed -E '/IMG_URL:/ s|/[^/]+:|/'"${ip_address}"':|' "${template_file}" | tee "${tmp}"
	mv "${tmp}" "${template_file}"
}

# template checks if a template exists in tink and creates one from the file_loc provided if one does not exist
template() {
	if (($(tink template get --no-headers 2>/dev/null | grep -c '^|') > 0)); then
		return
	fi

	tink template create --file "$1" 2>/dev/null
}

# workflow checks if a workflow record exists in tink before creating a new one
workflow() {
	local mac_address=$1

	local template_id
	template_id=$(tink template get --no-headers 2>/dev/null | grep '^|' | awk '{print $2}' | head -n1)

	local workflow_id
	workflow_id=$(tink workflow get --no-headers 2>/dev/null | grep "${template_id}" | awk '{print $2}' | head -n1 || :)
	if [[ -n ${workflow_id:-} ]]; then
		echo "Workflow [${workflow_id}] already exists"
		return
	fi

	tink workflow create --template "${template_id}" --hardware '{"device_1":"'"${mac_address}"'"}' 2>/dev/null
}

# main runs the creation functions in order
hw_file=$1
template_file=$2
ip_address=$3
client_ip_address=$4
client_mac_address=$5

[[ -z ${hw_file} ]] && echo "hw_file arg is empty" >&2 && exit 1
[[ -z ${template_file} ]] && echo "template_file arg is empty" >&2 && exit 1
[[ -z ${ip_address} ]] && echo "ip_address arg is empty" >&2 && exit 1
[[ -z ${client_ip_address} ]] && echo "client_ip_address arg is empty" >&2 && exit 1
[[ -z ${client_mac_address} ]] && echo "client_mac_address arg is empty" >&2 && exit 1

client_mac_address=$(echo "$client_mac_address" | tr 'A-F' 'a-f')

if ! which jq &>/dev/null; then
	apk add jq
fi

update_hw_ip_addr "${client_ip_address}" "${hw_file}"
update_hw_mac_addr "${client_mac_address}" "${hw_file}"
hardware "${hw_file}"
update_template_img_ip "${ip_address}" "${template_file}"
template "${template_file}"
workflow "${client_mac_address}"
