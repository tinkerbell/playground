#!/bin/bash
# abort this script on errors
set -euxo pipefail

setup_docker() (
	# steps from https://docs.docker.com/engine/install/ubuntu/
	sudo apt-get install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg-agent \
		software-properties-common \
		;

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
		sudo apt-key add -

	local repo
	repo=$(
		printf "deb [arch=amd64] https://download.docker.com/linux/ubuntu %s stable" \
			"$(lsb_release -cs)"
	)
	sudo add-apt-repository "$repo"

	sudo apt-get update
	sudo apt-get install -y \
		containerd.io \
		docker-ce \
		docker-ce-cli \
		;
)

setup_docker_compose() (
	# from https://docs.docker.com/compose/install/
	sudo curl -L \
		"https://github.com/docker/compose/releases/download/1.26.0/docker-compose-$(uname -s)-$(uname -m)" \
		-o /usr/local/bin/docker-compose

	sudo chmod +x /usr/local/bin/docker-compose
)

main() (
	export DEBIAN_FRONTEND=noninteractive

	sudo apt-get update
	setup_docker
	setup_docker_compose
	sudo apt-get install -y jq
	sudo usermod -aG docker vagrant
)

main
