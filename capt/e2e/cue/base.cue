// Shared test defaults for all matrix combos.
// Imports #ConfigInput from the capt CUE module directly — no schema duplication.
package e2e

import (
	"tinkerbell.org/capt-playground/cue/state"
)

_spares: int | *0 @tag(spares,type=int)

// No default: the runner passes whatever `latest` resolves to, and a pin here
// could only go stale behind it.
_chartVersion: string @tag(chartVersion)

// Build Tinkerbell from a git repo rather than using released artifacts. Absent
// unless the runner asks for it, and then it supplies the chart and both images,
// so versions.chart and chart.location stop applying.
_sourceRepo: string | *"" @tag(sourceRepo)
_sourceRef:  string | *"" @tag(sourceRef)

_sourceRequested: _sourceRepo != "" || _sourceRef != ""

// The runner points this at the combo's artifact directory so parallel or
// successive combos never share generated kubeconfigs and certs.d trees.
_outputDir: string | *"output" @tag(outputDir)

base: state.#ConfigInput & {
	clusterName: "e2e-test"
	outputDir:   _outputDir
	namespace:   "tinkerbell"
	arch:        "amd64"

	if _sourceRequested {
		source: {
			repo: _sourceRepo
			ref:  _sourceRef
		}
	}

	counts: {
		controlPlanes: 1
		workers:       1
		spares:        _spares
	}

	versions: {
		capt:    "v0.7.0"
		kube:    "v1.35.2"
		os:      2404
		kubevip: "1.1.2"

		// A source build overwrites this with the version it produced, and helm
		// ignores --version for the chart it packages, so nothing pulls it.
		if _sourceRequested {
			chart: "source"
		}
		if !_sourceRequested {
			chart: _chartVersion
		}
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
		image: "ghcr.io/jacobweinstock/virtualbmc:latest"
	}

	captainos: kernelVersion: "6.18.16"

	// registryMirror is set per-combo in matrix.cue (enabled or disabled).
	// Not defaulted here to avoid CUE unification conflicts.
}
