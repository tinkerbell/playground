#!/bin/bash

host_arch() {
	uname -m
}

normalized_platform() {
	case "$(host_arch)" in
	aarch64 | arm64)
		echo arm64
		;;
	x86_64 | amd64)
		echo amd64
		;;
	*)
		host_arch
		;;
	esac
}

install_docker() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	update_apt
	apt-get install --no-install-recommends containerd.io docker-ce docker-ce-cli
	gpasswd -a vagrant docker
}

install_kubectl() {
	local kubectl_version=$1
	local platform

	platform=$(normalized_platform)

	curl -LO "https://dl.k8s.io/v$kubectl_version/bin/linux/${platform}/kubectl"
	chmod +x ./kubectl
	mv ./kubectl /usr/local/bin/kubectl
}

install_helm() {
	local helm_ver=$1

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
	local k3d_version=$1

	wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG="$k3d_version" bash
}

start_k3d() {
	local k8s_version=$1

	# K3D_FIX_DNS=false is needed because host network mode won't work without it.
	K3D_FIX_DNS=false k3d cluster create --network host --no-lb --k3s-arg "--disable=traefik,servicelb,metrics-server,local-storage" --image rancher/k3s:"v$k8s_version-k3s1"

	mkdir -p ~/.kube/
	k3d kubeconfig get -a >~/.kube/config
	until kubectl wait --for=condition=Ready nodes --all --timeout=600s; do sleep 1; done

	fix_coredns_upstream
}

# With --network host and K3D_FIX_DNS=false, CoreDNS inherits the node's
# /etc/resolv.conf which on Ubuntu points at the systemd-resolved stub at
# 127.0.0.53. That address is unreachable from inside a pod's network namespace,
# so cluster pods get DNS failures (the host and the k3d container itself work
# because they share the host netns).
#
# The k3s-supported "coredns-custom" ConfigMap can NOT be used here:
#   - "*.override" entries are imported INSIDE the bundled ".:53 { ... }" block,
#     but "forward" is a single-instance plugin so it can't be redeclared.
#   - "*.server" entries are imported OUTSIDE the bundled block, intended for
#     additional zones; declaring ". { ... }" there collides with the bundled
#     ".:53" server and CoreDNS aborts with
#       "cannot serve dns://.:53 - it is already defined".
#
# Instead, patch the bundled "coredns" ConfigMap in place: replace
# "forward . /etc/resolv.conf" with the discovered host upstreams and restart
# the Deployment. This is fine for the single-shot vagrant playground because
# k3s is never restarted within a session (the addon manager would otherwise
# re-apply the bundled manifest).
fix_coredns_upstream() {
	local upstreams=""
	if [[ -r /run/systemd/resolve/resolv.conf ]]; then
		upstreams=$(awk '/^nameserver / {print $2}' /run/systemd/resolve/resolv.conf | grep -v '^127\.' | tr '\n' ' ' | sed 's/ $//')
	fi
	if [[ -z $upstreams ]]; then
		upstreams="1.1.1.1"
	fi
	echo "==> Patching bundled CoreDNS Corefile to forward to: $upstreams"

	# Wait (bounded) for the CoreDNS ConfigMap and Deployment to exist. k3s
	# deploys them asynchronously via the addon manager.
	local waited=0
	until kubectl -n kube-system get configmap coredns >/dev/null 2>&1 &&
		kubectl -n kube-system get deployment coredns >/dev/null 2>&1; do
		if ((waited >= 180)); then
			echo "!! CoreDNS did not appear within ${waited}s; dumping diagnostics" >&2
			kubectl get all,cm,helmchart -A >&2 || true
			docker logs k3d-k3s-default-server-0 2>&1 | tail -200 >&2 || true
			return 1
		fi
		sleep 2
		waited=$((waited + 2))
	done

	# Replace the "forward . /etc/resolv.conf" line in the Corefile with the
	# discovered upstreams. Re-apply the ConfigMap preserving the NodeHosts
	# data key (the bundled ConfigMap has both Corefile and NodeHosts).
	local corefile new_corefile nodehosts
	corefile=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')
	nodehosts=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.NodeHosts}')
	new_corefile=$(printf '%s\n' "$corefile" | sed -E "s|forward \. /etc/resolv\.conf|forward . ${upstreams}|")
	if [[ $new_corefile == "$corefile" ]]; then
		echo "!! Could not find 'forward . /etc/resolv.conf' in CoreDNS Corefile; current contents:" >&2
		printf '%s\n' "$corefile" >&2
		return 1
	fi
	kubectl -n kube-system create configmap coredns \
		--from-literal=Corefile="$new_corefile" \
		--from-literal=NodeHosts="$nodehosts" \
		--dry-run=client -o yaml | kubectl apply -f -

	kubectl -n kube-system rollout restart deployment coredns
	kubectl -n kube-system rollout status deployment coredns --timeout=120s
}

kubectl_for_vagrant_user() {
	runuser -l vagrant -c "mkdir -p ~/.kube/"
	runuser -l vagrant -c "k3d kubeconfig get -a > ~/.kube/config"
	chmod 600 /home/vagrant/.kube/config
	echo 'export KUBECONFIG="/home/vagrant/.kube/config"' >>~vagrant/.bashrc
}

helm_install_tink_stack() {
	local namespace="$1"
	local version="$2"
	local interface="$3"
	local loadbalancer_ip="$4"
	local loadbalancer_ip_2="$5"

	trusted_proxies=""
	until [ "$trusted_proxies" != "" ]; do
		trusted_proxies=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}' | tr ' ' ',')
		sleep 5
	done
	helm install tink-stack oci://ghcr.io/tinkerbell/charts/tinkerbell \
		--version "$version" \
		--create-namespace \
		--namespace "$namespace" \
		--wait \
		--set "trustedProxies={${trusted_proxies}}" \
		--set "publicIP=$loadbalancer_ip" \
		--set "artifactsFileServer=http://$loadbalancer_ip_2:7173" \
		--set "deployment.init.sourceInterface=$interface" \
		--set "deployment.envs.ui.enableAutoLogin=true" \
		--set "optional.captainos.enabled=true" \
		--set "optional.captainos.image=ghcr.io/tinkerbell/captain/artifacts:v0.0.0-9ea7a56" \
		--set "deployment.envs.smee.ipxeHttpScriptKernelName=vmlinuz-6.18.16" \
		--set "deployment.envs.smee.ipxeHttpScriptInitrdName=initramfs-6.18.16" \
		--set "optional.kubevip.interface=$interface"
}

apply_manifests() {
	local worker_ip=$1
	local worker_mac=$2
	local manifests_dir=$3
	local host_ip=$4
	local namespace=$5

	disk_device="/dev/sda"
	if lsblk | grep -q vda; then
		disk_device="/dev/vda"
	fi
	export DISK_DEVICE="$disk_device"
	export TINKERBELL_CLIENT_IP="$worker_ip"
	export TINKERBELL_CLIENT_MAC="$worker_mac"
	export TINKERBELL_HOST_IP="$host_ip"
	export TINKERBELL_CLIENT_ARCH="$(host_arch)"               # (x86_64 | aarch64)
	export TINKERBELL_CLIENT_PLATFORM="$(normalized_platform)" # (amd64 | arm64)

	for i in "$manifests_dir"/{hardware.yaml,template.yaml,workflow.yaml,ubuntu-download.yaml}; do
		envsubst '$DISK_DEVICE $TINKERBELL_CLIENT_IP $TINKERBELL_CLIENT_MAC $TINKERBELL_HOST_IP $TINKERBELL_CLIENT_ARCH $TINKERBELL_CLIENT_PLATFORM' <"$i"
		echo -e '---'
	done >/tmp/manifests.yaml
	kubectl apply -n "$namespace" -f /tmp/manifests.yaml
}

run_helm() {
	local host_ip=$1
	local worker_ip=$2
	local worker_mac=$3
	local manifests_dir=$4
	local loadbalancer_ip=$5
	local helm_chart_version=$6
	local loadbalancer_interface=$7
	local k3d_version=$8
	local namespace="tinkerbell"
	local helm_version=$9
	local loadbalancer_ip_2="${10}"

	install_k3d "$k3d_version"
	start_k3d "$kubectl_version"
	kubectl_for_vagrant_user
	install_helm "$helm_version"
	helm_install_tink_stack "$namespace" "$helm_chart_version" "$loadbalancer_interface" "$loadbalancer_ip" "$loadbalancer_ip_2"
	apply_manifests "$worker_ip" "$worker_mac" "$manifests_dir" "$loadbalancer_ip_2" "$namespace"
}

main() {
	local host_ip="$1"
	local worker_ip="$2"
	local worker_mac="$3"
	local manifests_dir="$4"
	local loadbalancer_ip="$5"
	local helm_chart_version="$6"
	local loadbalancer_interface="$7"
	local kubectl_version="$8"
	local k3d_version="$9"
	local helm_version="${10}"
	local loadbalancer_ip_2="${11}"

	update_apt
	install_docker
	# https://github.com/ipxe/ipxe/pull/863
	# Needed after iPXE increased the default TCP window size to 2MB.
	sudo ethtool -K eth1 tx off sg off tso off
	install_kubectl "$kubectl_version"
	run_helm "$host_ip" "$worker_ip" "$worker_mac" "$manifests_dir" "$loadbalancer_ip" "$helm_chart_version" "$loadbalancer_interface" "$k3d_version" "$helm_version" "$loadbalancer_ip_2"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -euxo pipefail

	main "$@"
	echo "all done!"
fi
