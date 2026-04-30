#!/usr/bin/env bash
# Create the external-tinkerbell-kubeconfig secret in the management cluster
# so CAPT can connect to the Tinkerbell cluster.
#
# Usage: create_external_kubeconfig_secret.sh <tink_cluster_name> <mgmt_kubeconfig>

set -euo pipefail

TINK_CLUSTER_NAME="${1}"
MGMT_KUBECONFIG="${2}"

# Get the Tinkerbell KinD cluster's container IP (reachable from pods on the shared Docker "kind" network)
TINK_CONTAINER_IP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "${TINK_CLUSTER_NAME}-control-plane")

# Get the kubeconfig and patch the server URL to use the container IP
TINK_KUBECONFIG=$(kind get kubeconfig --name "${TINK_CLUSTER_NAME}")
TINK_KUBECONFIG=$(echo "$TINK_KUBECONFIG" | sed "s|server: https://.*|server: https://${TINK_CONTAINER_IP}:6443|g")

# Ensure the capt-system namespace exists in the management cluster
KUBECONFIG="${MGMT_KUBECONFIG}" kubectl create namespace capt-system --dry-run=client -o yaml | KUBECONFIG="${MGMT_KUBECONFIG}" kubectl apply -f -

# Create the secret with key "kubeconfig" (matches CAPT's mount path /var/run/secrets/external-tinkerbell/kubeconfig)
KUBECONFIG="${MGMT_KUBECONFIG}" kubectl create secret generic external-tinkerbell-kubeconfig \
	--namespace capt-system \
	--from-literal=kubeconfig="$TINK_KUBECONFIG" \
	--dry-run=client -o yaml | KUBECONFIG="${MGMT_KUBECONFIG}" kubectl apply -f -

# Label the secret so clusterctl move includes it during a CAPI pivot.
KUBECONFIG="${MGMT_KUBECONFIG}" kubectl label secret external-tinkerbell-kubeconfig \
	--namespace capt-system \
	clusterctl.cluster.x-k8s.io/move="" \
	clusterctl.cluster.x-k8s.io="" \
	--overwrite
