#!/bin/bash

# abort this script on errors
set -euxo pipefail

whoami

cd /vagrant

make_certs_writable() (
	local certdir="/etc/docker/certs.d/$TINKERBELL_HOST_IP"
	sudo mkdir -p "$certdir"
	sudo chown -R "$USER" "$certdir"
)

secure_certs() (
	local certdir="/etc/docker/certs.d/$TINKERBELL_HOST_IP"
	sudo chown "root" "$certdir"
)

configure_vagrant_user() (
	echo -n "$TINKERBELL_REGISTRY_PASSWORD" |
		sudo -iu vagrant docker login \
			--username="$TINKERBELL_REGISTRY_USERNAME" \
			--password-stdin "$TINKERBELL_HOST_IP"
)

setup_nat() (
	iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
	iptables -A FORWARD -i eth0 -o eth1 -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
)

get_tink_cli() {
	sudo wget -O /usr/local/bin/tink \
	"https://github.com/tinkerbell/sandbox/releases/download/v$TINKERBELL_SANDBOX_VERSION/tink-linux-386"
	sudo chmod 755 /usr/local/bin/tink
	sudo chown "root" /usr/local/bin/tink
}

main() (
	export DEBIAN_FRONTEND=noninteractive

	if [ ! -f ./.env ]; then
		./generate-envrc.sh eth1 >.env
	fi

	# shellcheck disable=SC1091
	. ./.env

	make_certs_writable

	./setup.sh

	get_tink_cli

	setup_nat
	secure_certs
	configure_vagrant_user

)

main
