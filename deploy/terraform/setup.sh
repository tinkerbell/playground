#!/usr/bin/env bash

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli
}

install_docker_compose() {
	apt-get install --no-install-recommends python3-pip
	pip install docker-compose
}

apt-get() {
	DEBIAN_FRONTEND=noninteractive command apt-get \
		--allow-change-held-packages \
		--allow-downgrades \
		--allow-remove-essential \
		--allow-unauthenticated \
		--option Dpkg::Options::=--force-confdef \
		--option Dpkg::Options::=--force-confold \
		--yes \
		"$@"
}

update_apt() {
	apt-get update
	apt-get upgrade
}

# get_second_interface_from_bond0 returns the second interface of the bond0 interface
get_second_interface_from_bond0() {
	local return_value
	return_value=$(cut -d' ' -f2 /sys/class/net/bond0/bonding/slaves | xargs)
	echo "${return_value}"
}

# setup_layer2_network removes the second interface from bond0 and uses it for the layer2 network
# https://metal.equinix.com/developers/docs/layer2-networking/hybrid-unbonded-mode/
setup_layer2_network() {
	local interface=$1
	local addr=$2

	# I tried getting rid of the following "manual" commands in favor of
	# persisting the network config and then restarting the network but that
	# didn't always work and was hard to recover from without a reboot so we're
	# stuck doing it once imperatively and also persisting the config
	ifenslave -d bond0 "${interface}"
	ip addr add "${addr}/24" dev "${interface}"
	ip link set dev "${interface}" up

	# persist the new network settings
	# gets rid of the auto ${interface} block
	# "/^auto ${interface}/,/^\s*$/ d"
	# gets rid of ${interface} in bond config
	# "s|${interface}||" \
	# gets rid empty lines
	# 's|\s*$||' \
	# gets rid of source lines from previous runs, having this here helps in debugging/developing
	# '/^source / d' \
	# appends a source line to the end of the file that will pick up iface-conf file we generate
	# '$ s|$|\n\nsource /etc/network/interfaces.d/*|' \
	sed -i \
		-e "/^auto ${interface}/,/^\s*$/ d" \
		-e "s|${interface}||" \
		-e 's|\s*$||' \
		-e '/^source / d' \
		-e '$ s|$|\n\nsource /etc/network/interfaces.d/*|' \
		/etc/network/interfaces

	cat >"/etc/network/interfaces.d/${interface}" <<-EOF
		auto ${interface}
		iface ${interface} inet static
		    address ${addr}
	EOF
}

# make_host_gw_server makes the host a gateway server
make_host_gw_server() {
	local incoming_interface="$1"
	local outgoing_interface="$2"
	iptables -t nat -A POSTROUTING -o "${outgoing_interface}" -j MASQUERADE
	iptables -A FORWARD -i "${outgoing_interface}" -o "${incoming_interface}" -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i "${incoming_interface}" -o "${outgoing_interface}" -j ACCEPT
}

main() {
	install_docker
	install_docker_compose

	local layer2_ip=192.168.56.4
	local layer2_interface
	layer2_interface=$(get_second_interface_from_bond0 ${layer2_ip})
	setup_layer2_network "${layer2_interface}" ${layer2_ip}
	make_host_gw_server "${layer2_interface}" bond0

	mkdir -p /root/sandbox/compose
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
fi
