#!/usr/bin/env bash

set -euxo pipefail

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	DEBIAN_FRONTEND=noninteractive apt install -y apt-transport-https ca-certificates curl gnupg-agent gnupg2 software-properties-common docker-ce docker-ce-cli containerd.io
}

install_docker_compose() {
	curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
}

update_apt() {
	$APT update
	DEBIAN_FRONTEND=noninteractive $APT --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
}

restart_docker_service() {
	service docker restart
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
	local layer2_interface="$1"
	#local ip_addr="$2"
	ifenslave -d bond0 "${layer2_interface}"
	#ip addr add ${ip_addr}/24 dev "${layer2_interface}"
	ip addr add 192.168.56.4/24 dev "${layer2_interface}"
	ip link set dev "${layer2_interface}" up
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
	#local provisioner_ip="$1"

	install_docker
	install_docker_compose
	restart_docker_service
	mkdir -p /root/sandbox/compose
	local layer2_interface
	layer2_interface="$(get_second_interface_from_bond0)"
	setup_layer2_network "${layer2_interface}" #"${provisioner_ip}"
	make_host_gw_server "${layer2_interface}" "bond0"
}

main #"$1"
