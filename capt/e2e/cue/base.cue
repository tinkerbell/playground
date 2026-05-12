// Shared test defaults for all matrix combos.
// Imports #ConfigInput from the capt CUE module directly — no schema duplication.
package e2e

import (
	"tinkerbell.org/capt-playground/cue/state"
)

_spares: int | *0 @tag(spares,type=int)

base: state.#ConfigInput & {
	clusterName: "e2e-test"
	outputDir:   "output"
	namespace:   "tinkerbell"
	arch:        "amd64"

	counts: {
		controlPlanes: 1
		workers:       1
		spares:        _spares
	}

	versions: {
		capt:    "v0.7.0"
		chart:   "v0.23.1-23da0880"
		kube:    "v1.35.2"
		os:      2404
		kubevip: "1.1.2"
	}

	capt: providerRepository: "https://github.com/tinkerbell/cluster-api-provider-tinkerbell/releases"

	chart: {
		location: "oci://ghcr.io/tinkerbell/charts/tinkerbell"
		extraVars: [
			"optional.captainos.enabled=true",
			"optional.captainos.image=ghcr.io/tinkerbell/captain/artifacts:v0.0.0-a4be23c",
			"deployment.envs.ui.enableAutoLogin=true",
		]
	}

	os: registry: "ghcr.io/tinkerbell/cluster-api-provider-tinkerbell/ubuntu"

	vm: {
		baseName:          "node"
		cpusPerVM:         2
		memInMBPerVM:      2048
		diskSizeInGBPerVM: 4
		diskPath:          "/tmp"
	}

	virtualBMC: {
		containerName: "virtualbmc"
		image:         "ghcr.io/jacobweinstock/virtualbmc:latest"
		user:          "root"
		pass:          "calvin"
	}

	captainos: kernelVersion: "6.18.16"

	// registryMirror is set per-combo in matrix.cue (enabled or disabled).
	// Not defaulted here to avoid CUE unification conflicts.
}
