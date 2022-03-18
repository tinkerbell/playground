#!/usr/bin/env bash
# This script handles the generation of the TLS certificates.
# This generates the files:
# 1. /certs/${FACILITY:-onprem}/ca-crt.pem (CA TLS public certificate)
# 2. /certs/${FACILITY:-onprem}/server-crt.pem (server TLS certificate)
# 3. /certs/${FACILITY:-onprem}/server-key.pem (server TLS private key)
# 4. /certs/${FACILITY:-onprem}/bundle.pem (server TLS certificate; backward compat)
# 5. /workflow/ca.pem (CA TLS public certificate)

set -euxo pipefail

# update_csr will add the sans_ip, as a valid host domain in the csr
update_csr() {
	local sans_ip="$1"
	local csr_file="$2"
	sed "/\"hosts\".*/a \    \"${sans_ip}\"," /app/csr.json >"${csr_file}"
}

# cleanup will remove unneeded files
cleanup() {
	rm -rf ca-key.pem ca.csr ca.pem server.csr server.pem
}

# gen will generate the key and certificate
gen() {
	local ca_crt_destination="$1"
	local server_crt_destination="$2"
	local server_key_destination="$3"
	cfssl gencert -initca /app/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -config /app/ca-config.json -ca ca.pem -ca-key ca-key.pem -profile server /app/csr.json | cfssljson -bare server
	mv ca.pem "${ca_crt_destination}"
	mv server.pem "${server_crt_destination}"
	mv server-key.pem "${server_key_destination}"
}

# main orchestrates the process
main() {
	local sans_ip="$1"
	local csr_file="/certs/${FACILITY:-onprem}/csr.json"
	local ca_crt_workflow_file="/workflow/ca.pem"
	local ca_crt_file="/certs/${FACILITY:-onprem}/ca-crt.pem"
	local server_crt_file="/certs/${FACILITY:-onprem}/server-crt.pem"
	local server_key_file="/certs/${FACILITY:-onprem}/server-key.pem"
	# NB this is required for backward compat.
	# TODO once the other think-* services use server-crt.pem this should
	#      be removed.
	local bundle_crt_file="/certs/${FACILITY:-onprem}/bundle.pem"

	if ! grep -q "${sans_ip}" "${csr_file}"; then
		update_csr "${sans_ip}" "${csr_file}"
	else
		echo "IP ${sans_ip} already in ${csr_file}"
	fi
	if [ ! -f "${ca_crt_file}" ] && [ ! -f "${server_crt_file}" ] && [ ! -f "${server_key_file}" ]; then
		gen "${ca_crt_file}" "${server_crt_file}" "${server_key_file}"
		cp "${server_crt_file}" "${bundle_crt_file}"
	else
		echo "Files [${ca_crt_file}, ${server_crt_file}, ${server_key_file}] already exist"
	fi
	if [ ! -f "${ca_crt_workflow_file}" ]; then
		cp "${ca_crt_file}" "${ca_crt_workflow_file}"
	else
		echo "File ${ca_crt_workflow_file} already exist"
	fi
	cleanup
}

main "$1"
