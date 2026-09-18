// Additive extension of the state package: accepts an optional
// `registryMirror` block in config.yaml and passes it through to .state so
// downstream consumers (Taskfile-mirror.yaml, the cue/mirror package) can
// read it via yq or cue.
//
// Also rewrites the image strings that are pulled OUTSIDE any containerd that
// carries the mirror config. Everything else is left as-is because the kind
// containerd mirror (cue/kind) and the workload-node containerd mirror
// drop-in (cue/capi/resources.cue) handle redirection at runtime.
//
// CUE merges sibling files in the same package, so state.cue is not
// touched. Delete this file to remove the field and the rewrites.
package state

import "tinkerbell.org/capt-playground/cue/mirror"

#ConfigInput: {
	// null: a key written with no value parses that way, and means absent.
	registryMirror?: null | mirror.#Spec
	...
}

// Effective mirror spec, with a disabled-default when the field is absent
// from config.yaml.
_mirrorCfg: [
	if config.registryMirror != _|_ if config.registryMirror != null {config.registryMirror},
	{enabled: false, host: "", upstreams: []},
][0]

out: {
	registryMirror: _mirrorCfg

	// helm OCI client direct HTTPS (no containerd in the pull path).
	// _chartLocation, not config, so a chart built from source is what flows
	// through here; a filesystem path matches no upstream prefix and is left
	// alone.
	chart: location: (mirror.#rewrite & {in: _chartLocation, cfg: _mirrorCfg}).out

	// crane inside the oci2disk action container, direct HTTPS.
	os: registry: (mirror.#rewrite & {in: config.os.registry, cfg: _mirrorCfg}).out

	// `docker run` on the host.
	virtualBMC: image: (mirror.#rewrite & {in: config.virtualBMC.image, cfg: _mirrorCfg}).out

	// Workflow action images, pulled by tink-agent's containerd inside
	// CaptainOS. That containerd gets no certs.d tree, so unlike the
	// cluster-node pulls these cannot be redirected at runtime and have to be
	// rewritten here. Without this an IPv6-only machine has to reach
	// quay.io/ghcr.io itself, which only works via NAT64.
	actionImages: {
		for name, ref in _actionImages {
			(name): (mirror.#rewrite & {in: ref, cfg: _mirrorCfg}).out
		}
	}

	// Same reasoning as actionImages: pulled by CaptainOS, which has no
	// certs.d, so the containerd mirror cannot redirect it.
	agentImage: (mirror.#rewrite & {in: _agentImage, cfg: _mirrorCfg}).out
}
