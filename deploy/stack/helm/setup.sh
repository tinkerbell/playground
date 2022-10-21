#!/bin/bash

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

install_helm() {
	helm_ver=v3.9.4

	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh --version "$helm_ver"
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

install_k3d() {
	wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.4.6 bash
}

start_k3d() {
	k3d cluster create --network host --no-lb --k3s-arg "--disable=traefik,servicelb" --k3s-arg "--kube-apiserver-arg=feature-gates=MixedProtocolLBService=true" --host-pid-mode
	mkdir -p ~/.kube/
    k3d kubeconfig get -a > ~/.kube/config
	until kubectl wait --for=condition=Ready nodes --all --timeout=600s; do sleep 1; done
}

kubectl_for_vagrant_user() {
	runuser -l vagrant -c "mkdir -p ~/.kube/"
	runuser -l vagrant -c "k3d kubeconfig get -a > ~/.kube/config"
	chmod 600 /home/vagrant/.kube/config
	echo 'export KUBECONFIG="/home/vagrant/.kube/config"' >>~vagrant/.bashrc
}

helm_customize_values() {
	local loadbalancer_ip=$1

	helm inspect values oci://ghcr.io/tinkerbell/charts/stack --version 0.1.1 > /tmp/stack-values.yaml
	sed -i "s/192.168.2.111/${loadbalancer_ip}/g" /tmp/stack-values.yaml
}

helm_install_tink_stack() {
	local namespace=$1

	trusted_proxies=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}' | tr ' ' ',')
	helm install stack-release oci://ghcr.io/tinkerbell/charts/stack --version 0.1.1 --create-namespace --namespace "$namespace" --wait --set "boots.boots.trustedProxies=${trusted_proxies}" --set "hegel.hegel.trustedProxies=${trusted_proxies}" --set "kubevip.interface=eth1" --values /tmp/stack-values.yaml
}

apply_manifests() {
	local worker_ip=$1
	local worker_mac=$2
	local manifests_dir=$3
	local host_ip=$4
	local namespace=$5

    export TINKERBELL_CLIENT_IP="$worker_ip"
    export TINKERBELL_CLIENT_MAC="$worker_mac"
    export TINKERBELL_HOST_IP="$host_ip"
	for i in "$manifests_dir"/{hardware.yaml,template.yaml,workflow.yaml}; do envsubst < $i; echo -e '---'; done > /tmp/manifests.yaml
	kubectl apply -n "$namespace" -f /tmp/manifests.yaml
}

run_helm() {
	local host_ip=$1
	local worker_ip=$2
	local worker_mac=$3
	local manifests_dir=$4
	local namespace="tink-system"
	local loadbalancer_ip="192.168.56.5"

    install_k3d
	start_k3d
	install_helm
	helm_customize_values "$loadbalancer_ip"
	# do we need to wait til cluster is ready? TBD
	helm_install_tink_stack "$namespace"
	apply_manifests "$worker_ip" "$worker_mac" "$manifests_dir" "$loadbalancer_ip", "$namespace"
	kubectl_for_vagrant_user
}

main() {
	local host_ip=$1
	local worker_ip=$2
	local worker_mac=$3
	local compose_dir=$4

	update_apt
	install_docker
	install_kubectl

	run_helm "$host_ip" "$worker_ip" "$worker_mac" "$compose_dir"/manifests
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
	echo "all done!"
fi