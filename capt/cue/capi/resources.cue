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
			services: cidrBlocks: ["172.26.0.0/16"]
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
			preKubeadmCommands: list.Concat([_mirrorPreCmds, [c.kubeVipCmd]])
			if len(_mirrorFiles) > 0 {
				files: _mirrorFiles
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
		if len(_mirrorFiles) > 0 {
			files:               _mirrorFiles
			preKubeadmCommands:  _mirrorPreCmds
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
		templateOverride: yaml.Marshal(_workflow)
	}
}

_tmtCp: #tmt & {
	_name: c.tmtCpName
	_role: "control-plane"
}

_tmtWorker: #tmt & {
	_name: c.tmtWorkerName
	_role: "worker"
}
