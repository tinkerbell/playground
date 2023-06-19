#!/usr/bin/env bash

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository --yes "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli docker-compose-plugin
	gpasswd -a vagrant docker
	apt-get install docker-compose
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
	update_apt
	install_docker
	install_kubectl

	local compose_dir="/sandbox/stack/compose"
	docker-compose -f "$compose_dir"/docker-compose.yml up -d

	create_tink_helper_script "$compose_dir"
	tweak_bash_interactive_settings "$compose_dir"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
	echo "all done!"
fi
