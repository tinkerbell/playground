#!/usr/bin/env bash

# Live playgrounds, without a registry.
#
# Every playground creates exactly one docker network, first thing, and removes
# it last. Labelling that network therefore records which playgrounds exist and
# what each one needs, in the one place that already has the right lifetime.
# Nothing has to be written down, kept in sync, or reaped: a playground that
# dies uncleanly still holds its network until someone deletes it, and deleting
# it is what releases everything else.
#
# Meant to be sourced, not run.

declare -r CAPT_LABEL_ID="capt.playground.id"
declare -r CAPT_LABEL_FAMILY="capt.playground.ipfamily"
# Empty for a playground using released artifacts. Carried on the network for the
# same reason the others are: it outlives the state file and cannot go stale.
declare -r CAPT_LABEL_SOURCE="capt.playground.source"

# Networks belonging to playgrounds, optionally excluding one instance.
# Excluding self is what makes "is anyone else still using this?" a question
# that can be asked before or after this playground's own network is gone.
function capt_networks() {
	declare -r except_id="${1:-}"

	declare name id
	while read -r name; do
		[[ -n $name ]] || continue
		if [[ -n $except_id ]]; then
			id="$(docker network inspect "$name" -f "{{index .Labels \"${CAPT_LABEL_ID}\"}}" 2>/dev/null || true)"
			[[ $id != "$except_id" ]] || continue
		fi
		echo "$name"
	done < <(docker network ls --filter "label=${CAPT_LABEL_ID}" --format '{{.Name}}')
}

# Networks of playgrounds using the given address family, excluding one
# instance. The IPv6-only helpers -- NAT64, DNS64 -- are shared, so they may
# only be torn down once no other IPv6 playground is left.
function capt_networks_with_family() {
	declare -r family="$1"
	declare -r except_id="${2:-}"

	declare name
	while read -r name; do
		[[ -n $name ]] || continue
		if [[ "$(docker network inspect "$name" -f "{{index .Labels \"${CAPT_LABEL_FAMILY}\"}}" 2>/dev/null || true)" == "$family" ]]; then
			echo "$name"
		fi
	done < <(capt_networks "$except_id")
}

# How many networks a container is attached to. For the shared vBMC this is the
# reference count itself: it is joined to each playground's network on create
# and dropped from it on delete, so reaching zero means nobody is left.
function capt_container_network_count() {
	declare -r container="$1"

	if ! docker inspect "$container" >/dev/null 2>&1; then
		echo 0
		return 0
	fi
	docker inspect "$container" -f '{{len .NetworkSettings.Networks}}' 2>/dev/null || echo 0
}
