// Additive extension of the state package: accepts an optional
// `registryMirror` block in config.yaml and passes it through to .state so
// downstream consumers (Taskfile-mirror.yaml, the cue/mirror package) can
// read it via yq or cue.
//
// Also rewrites the small set of image strings that are pulled OUTSIDE any
// containerd (helm-on-host, crane-in-action-container, docker-on-host) to
// route through the mirror host. Everything else is left as-is because
// the kind containerd mirror (cue/kind) and the workload-node containerd
// mirror drop-in (cue/capi/resources.cue) handle redirection at runtime.
//
// CUE merges sibling files in the same package, so state.cue is not
// touched. Delete this file to remove the field and the rewrites.
package state

import "tinkerbell.org/capt-playground/cue/mirror"

#ConfigInput: {
	registryMirror?: mirror.#Spec
	...
}

// Effective mirror spec, with a disabled-default when the field is absent
// from config.yaml.
_mirrorCfg: [
	if config.registryMirror != _|_ {config.registryMirror},
	{enabled: false, host: "", upstreams: []},
][0]

out: {
	registryMirror: _mirrorCfg

	// helm OCI client direct HTTPS (no containerd in the pull path).
	chart: location: (mirror.#rewrite & {in: config.chart.location, cfg: _mirrorCfg}).out

	// crane inside the oci2disk action container, direct HTTPS.
	os: registry: (mirror.#rewrite & {in: config.os.registry, cfg: _mirrorCfg}).out

	// `docker run` on the host.
	virtualBMC: image: (mirror.#rewrite & {in: config.virtualBMC.image, cfg: _mirrorCfg}).out
}
