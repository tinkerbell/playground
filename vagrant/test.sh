#!/bin/bash


one() {
	local host_ip="$1"
	local worker_ip="$2"
	local worker_mac="$3"
	local manifests_dir="$4"
	local loadbalancer_ip="$5"
	local helm_chart_version="$6"
	local loadbalancer_interface="$7"
	local kubectl_version="$8"
	local k3d_version="$9"
	local gateway="${10}"

	echo "$gateway"
}

one 1 2 3 4 5 6 7 8 9 ""
