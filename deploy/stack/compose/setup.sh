#!/usr/bin/env bash

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli docker-compose-plugin
	gpasswd -a vagrant docker
}

install_kubectl() {
	curl -LO https://dl.k8s.io/v1.25.2/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	mv ./kubectl /usr/local/bin/kubectl
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
	local host_ip=$1
	ip addr show dev eth1 | grep -q "$host_ip" && return 0
	ip addr add "$host_ip/24" dev eth1
	ip link set dev eth1 up
}

setup_compose_env_overrides() {
	local host_ip=$1
	local worker_ip=$2
	local worker_mac=$3
	local compose_dir=$4
	local disk_device

	disk_device="/dev/sda"
	if lsblk | grep -q vda; then
		disk_device="/dev/vda"
		if [[ $compose_dir == *"postgres"* ]]; then
			sed -i 's|sda|vda|g' "$compose_dir"/create-tink-records/manifests/template/ubuntu.yaml
		fi
	fi

	readarray -t lines <<-EOF
		TINKERBELL_HOST_IP="$host_ip"
		TINKERBELL_CLIENT_IP="$worker_ip"
		TINKERBELL_CLIENT_MAC="$worker_mac"
		DISK_DEVICE="$disk_device"
	EOF
	for line in "${lines[@]}"; do
		grep -q "$line" "$compose_dir"/.env && continue
		echo "$line" >>"$compose_dir"/.env
	done
}

create_tink_helper_script() {
	local compose_dir=$1

	mkdir -p ~vagrant/.local/bin
	cat >~vagrant/.local/bin/tink <<-____HERE
		#!/usr/bin/env bash

		exec docker compose -f $compose_dir/docker-compose.yml exec tink-cli tink "\$@"
	____HERE
	chmod +x ~vagrant/.local/bin/tink
}

tweak_bash_interactive_settings() {
	local compose_dir=$1

	grep -q "cd $compose_dir" ~vagrant/.bashrc || echo "cd $compose_dir" >>~vagrant/.bashrc
	echo 'export KUBECONFIG='"$compose_dir"'/state/kube/kubeconfig.yaml' >>~vagrant/.bashrc
	readarray -t aliases <<-EOF
		dc="docker compose"
	EOF
	for alias in "${aliases[@]}"; do
		grep -q "$alias" ~vagrant/.bash_aliases || echo "alias $alias" >>~vagrant/.bash_aliases
	done
}

main() {
	local host_ip=$1
	local worker_ip=$2
	local worker_mac=$3
	local compose_dir=$4

	update_apt
	install_docker
	install_kubectl

	# setup_layer2_network "$host_ip"

	setup_compose_env_overrides "$host_ip" "$worker_ip" "$worker_mac" "$compose_dir"
	docker compose --env-file "$compose_dir"/.env -f "$compose_dir"/docker-compose.yml up -d

	create_tink_helper_script "$compose_dir"
	tweak_bash_interactive_settings "$compose_dir"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
	echo "all done!"
fi
