// Renders a kind v1alpha4 cluster configuration.
//
// When the registry mirror is enabled, the kind config bind-mounts the
// host-side certs.d tree (rendered to <outputDir>/certs.d/<u>/hosts.toml
// by tasks/Taskfile-mirror.yaml#render-kind-config) into every node at
// /etc/containerd/certs.d. kind's default containerd config already sets
// `config_path = "/etc/containerd/certs.d"`, so no containerdConfigPatches
// are needed — and indeed must not be added: containerd v2 (kindest/node
// v1.35+) refuses any inline `[plugins."...".registry.mirrors.<u>]` block
// when `config_path` is also set, with:
//
//	`mirrors` cannot be set when `config_path` is provided
//
// The same hosts.toml bodies are emitted as cloud-init files on workload
// nodes by cue/mirror/files.cue#cloudInitFiles, so kind and CAPT-VM nodes
// see identical mirror configuration.
//
// Pipeline:
//   cue export ./cue/kind yaml: .state -l 'values:' -e out --out yaml
//
// Output is consumed by tasks/Taskfile-create.yaml#kind-cluster, which
// passes it to `kind create cluster --config`.
package kind

import (
	"tinkerbell.org/capt-playground/cue/mirror"
	v "tinkerbell.org/capt-playground/cue/values"
)

values: v.#Config

// Adapt values into the shape mirror.values expects.
_mirrorValues: {
	registryMirror: mirror.#Spec
	if values.registryMirror != _|_ {
		registryMirror: values.registryMirror
	}
}

_mirrorEnabled: _mirrorValues.registryMirror.enabled &&
	len(_mirrorValues.registryMirror.upstreams) > 0

// Absolute host path to the rendered certs.d tree. Bind-mounted into
// each kind node. Rendered by tasks/Taskfile-mirror.yaml#render-kind-config.
_hostCertsDir: "\(values.outputDir)/certs.d"

out: {
	kind:       "Cluster"
	apiVersion: "kind.x-k8s.io/v1alpha4"
	if _mirrorEnabled {
		nodes: [{
			role: "control-plane"
			extraMounts: [{
				hostPath:      _hostCertsDir
				containerPath: "/etc/containerd/certs.d"
				readOnly:      true
			}]
		}]
	}
}
