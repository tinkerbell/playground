// CAPI/CAPT resources composed for the playground.
//
// Names and references are computed in the shared values package so that
// bumping values.versions.kube changes the TMT names (with version suffix)
// and the references from KCP/MD in lock-step. Drift is impossible by
// construction.
package capi

import (
	"encoding/yaml"
	"list"
	"tinkerbell.org/capt-playground/cue/mirror"
	v "tinkerbell.org/capt-playground/cue/values"
)

// Mirror cloud-init files + preKubeadmCommands. cue/mirror is the single
// source of truth shared with cue/kind. When the mirror is disabled the
// `_mirrorFiles` list is empty and `_mirrorPreCmds` is empty, so the KCP
// and KCT below render identically to the no-mirror case.
_mirrorRender: (mirror & {"values": values}).cloudInitFiles
_mirrorFiles:  _mirrorRender
_mirrorPreCmds: [if len(_mirrorRender) > 0 {"systemctl restart containerd"}]

// kubeadm's preflight fails an IPv6 cluster unless IPv6 forwarding is on, and
// the node image only ships the IPv4 equivalent. A drop-in (rather than a bare
// `sysctl -w`) keeps it set across reboots, which the CNI also relies on.
_ipv6Files: [if c.isV6 {{
	path:        "/etc/sysctl.d/99-k8s-ipv6-forwarding.conf"
	owner:       "root:root"
	permissions: "0644"
	content: """
		net.ipv6.conf.all.forwarding=1
		net.ipv6.conf.default.forwarding=1
		"""
}}]
_ipv6PreCmds: [if c.isV6 {"sysctl --system"}]

// With no --node-ip, kubelet derives the node address from the default-route
// interface. kube-vip adds the control-plane VIP to that same interface, and on
// IPv6 it can win the selection -- leaving the node's InternalIP tied to VIP
// ownership rather than to the node. Pinned here, in a preKubeadmCommand, which
// is the last point at which the real address is unambiguous: the VIP does not
// exist until kubelet starts kube-vip's static pod during kubeadm init. Only
// control planes run kube-vip, so workers need nothing.
_nodeIPCmds: [if c.isV6 {#"mkdir -p /etc/default && printf 'KUBELET_EXTRA_ARGS=--node-ip=%s\n' "$(ip -6 -j addr show dev $(ip -6 -j route list default | jq -r .[0].dev) scope global | jq -r '.[0].addr_info[0].local')" > /etc/default/kubelet"#}]

// Shared by the control-plane (KCP) and worker (KCT) bootstrap configs.
_bootstrapFiles:   list.Concat([_mirrorFiles, _ipv6Files])
_bootstrapPreCmds: list.Concat([_mirrorPreCmds, _ipv6PreCmds])

// Top-level injected by the task pipeline:
//   cue export ./cue/capi yaml: .state -l 'values:' -t mode=<bootMode> -e out --out text
values: v.#Config
_mode:  *"netboot" | "isoboot" @tag(mode)

// Single instantiation of the shared computed locals; reference c.<field>
// from every resource below. Keeps this file's local namespace clean.
c: v.#Computed & {"values": values, mode: _mode}

_cluster: {
	apiVersion: "cluster.x-k8s.io/v1beta2"
	kind:       "Cluster"
	metadata: {
		name:      c.clusterName
		namespace: c.namespace
	}
	spec: {
		clusterNetwork: {
			pods: cidrBlocks: [values.cluster.podCIDR]
			services: cidrBlocks: [c.serviceCIDR]
		}
		controlPlaneEndpoint: {
			host: values.cluster.controlPlane.vip
			port: 6443
		}
		// v1beta2 refs use apiGroup + kind + name (no apiVersion); CAPI looks
		// up the served version from CRD contract labels.
		controlPlaneRef: {
			apiGroup: "controlplane.cluster.x-k8s.io"
			kind:     "KubeadmControlPlane"
			name:     c.kcpName
		}
		infrastructureRef: {
			apiGroup: "infrastructure.cluster.x-k8s.io"
			kind:     "TinkerbellCluster"
			name:     c.tinkClusterName
		}
	}
}

_tinkerbellCluster: {
	apiVersion: "infrastructure.cluster.x-k8s.io/v1beta1"
	kind:       "TinkerbellCluster"
	metadata: {
		name:      c.tinkClusterName
		namespace: c.namespace
	}
	spec: imageLookupBaseRegistry: ""
}

_kcp: {
	apiVersion: "controlplane.cluster.x-k8s.io/v1beta2"
	kind:       "KubeadmControlPlane"
	metadata: {
		name:      c.kcpName
		namespace: c.namespace
	}
	spec: {
		replicas: values.counts.controlPlanes
		version:  values.versions.kube
		machineTemplate: spec: infrastructureRef: {
			apiGroup: "infrastructure.cluster.x-k8s.io"
			kind:     "TinkerbellMachineTemplate"
			name:     c.tmtCpName
		}
		kubeadmConfigSpec: {
			// v1beta2: kubeletExtraArgs is a list of {name,value} objects (was a
			// map[string]string in v1beta1).
			initConfiguration: nodeRegistration: kubeletExtraArgs: [{name: "provider-id", value: "PROVIDER_ID"}]
			joinConfiguration: nodeRegistration: {
				ignorePreflightErrors: ["DirAvailable--etc-kubernetes-manifests"]
				kubeletExtraArgs: [{name: "provider-id", value: "PROVIDER_ID"}]
			}
			// Mirror restart must run before kubeadm so the drop-in is loaded.
			preKubeadmCommands: list.Concat([_bootstrapPreCmds, _nodeIPCmds, [c.kubeVipCmd]])
			if len(_bootstrapFiles) > 0 {
				files: _bootstrapFiles
			}
			users: c.users
		}
	}
}

_md: {
	apiVersion: "cluster.x-k8s.io/v1beta2"
	kind:       "MachineDeployment"
	metadata: {
		name:      c.mdName
		namespace: c.namespace
		labels: {
			"cluster.x-k8s.io/cluster-name": c.clusterName
			pool:                            "worker-a"
		}
	}
	spec: {
		clusterName: c.clusterName
		replicas:    values.counts.workers
		selector: matchLabels: {
			"cluster.x-k8s.io/cluster-name": c.clusterName
			pool:                            "worker-a"
		}
		template: {
			metadata: labels: {
				"cluster.x-k8s.io/cluster-name": c.clusterName
				pool:                            "worker-a"
			}
			spec: {
				clusterName: c.clusterName
				version:     values.versions.kube
				bootstrap: configRef: {
					apiGroup: "bootstrap.cluster.x-k8s.io"
					kind:     "KubeadmConfigTemplate"
					name:     c.kctName
				}
				infrastructureRef: {
					apiGroup: "infrastructure.cluster.x-k8s.io"
					kind:     "TinkerbellMachineTemplate"
					name:     c.tmtWorkerName
				}
			}
		}
	}
}

_kct: {
	apiVersion: "bootstrap.cluster.x-k8s.io/v1beta2"
	kind:       "KubeadmConfigTemplate"
	metadata: {
		name:      c.kctName
		namespace: c.namespace
	}
	spec: template: spec: {
		joinConfiguration: nodeRegistration: kubeletExtraArgs: [{name: "provider-id", value: "PROVIDER_ID"}]
		if len(_bootstrapFiles) > 0 {
			files: _bootstrapFiles
		}
		if len(_bootstrapPreCmds) > 0 {
			preKubeadmCommands: _bootstrapPreCmds
		}
		users: c.users
	}
}

// Helper: a TMT for a given role (control-plane or worker).
#tmt: {
	_name: string
	_role: "control-plane" | "worker"
	apiVersion: "infrastructure.cluster.x-k8s.io/v1beta1"
	kind:       "TinkerbellMachineTemplate"
	metadata: {
		name:      _name
		namespace: c.namespace
	}
	spec: template: spec: {
		bootOptions: _bootOptions
		hardwareAffinity: required: [{
			labelSelector: matchLabels: "tinkerbell.org/role": _role
		}]
		templateOverride: _workflowYAML
	}
}

// Marshal the workflow once at package scope so `cue vet ./cue/capi`
// evaluates it eagerly (rather than only when a TMT is materialised).
// Any structural error in _workflow surfaces during validation, not at
// kubectl-apply time.
_workflowYAML: yaml.Marshal(_workflow)

_tmtCp: #tmt & {
	_name: c.tmtCpName
	_role: "control-plane"
}

_tmtWorker: #tmt & {
	_name: c.tmtWorkerName
	_role: "worker"
}
