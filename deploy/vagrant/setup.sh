#!/usr/bin/env bash

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli
	gpasswd -a vagrant docker
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
}

setup_layer2_network() {
	host_addr=$1
	ip addr show dev eth1 | grep -q "$host_addr" && return 0
	ip addr add "$host_addr/24" dev eth1
	ip link set dev eth1 up
}

setup_compose_env_overrides() {
	local host_addr=$1
	local worker_addr=$2
	if lsblk | grep -q vda; then
		sed -i 's|sda|vda|g' /vagrant/compose/create-tink-records/manifests/template/ubuntu.yaml
	fi
	readarray -t lines <<-EOF
		TINKERBELL_HOST_IP="$host_addr"
		TINKERBELL_CLIENT_IP="$worker_addr"
	EOF
	for line in "${lines[@]}"; do
		grep -q "$line" /vagrant/compose/.env && continue
		echo "$line" >>/vagrant/compose/.env
	done
}

create_tink_helper_script() {
	mkdir -p ~vagrant/.local/bin
	cat >~vagrant/.local/bin/tink <<-'EOF'
		#!/usr/bin/env bash

		exec docker-compose -f /vagrant/compose/docker-compose.yml exec tink-cli tink "$@"
	EOF
	chmod +x ~vagrant/.local/bin/tink
}

tweak_bash_interactive_settings() {
	grep -q 'cd /vagrant/compose' ~vagrant/.bashrc || echo 'cd /vagrant/compose' >>~vagrant/.bashrc
	readarray -t aliases <<-EOF
		dc=docker-compose
	EOF
	for alias in "${aliases[@]}"; do
		grep -q "$alias" ~vagrant/.bash_aliases || echo "alias $alias" >>~vagrant/.bash_aliases
	done
}

main() {
	local host_addr=$1
	local worker_addr=$2

	update_apt
	install_docker
	install_docker_compose

	setup_layer2_network "$host_addr"

	setup_compose_env_overrides "$host_addr" "$worker_addr"
	docker-compose -f /vagrant/compose/docker-compose.yml up -d

	create_tink_helper_script
	tweak_bash_interactive_settings
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
fi
