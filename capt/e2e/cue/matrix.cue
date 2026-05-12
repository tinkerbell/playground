// Test matrix: 3 binary axes → 8 combos.
//
// Axes:
//   1. Cluster topology:  single (co-located) vs external Tinkerbell
//   2. Registry mirrors:  disabled vs enabled (pull-through cache)
//   3. Boot method:       netboot (iPXE) vs isoboot (ISO)
//
// Usage (from the capt/ directory):
//   # List all combo names
//   cue eval ./e2e/cue -e comboNames --out json
//
//   # Render a single combo as config.yaml
//   cue export ./e2e/cue -e 'combos["single-nomirror-netboot"]' --out yaml
//
//   # Render all combos (struct keyed by name)
//   cue export ./e2e/cue -e combos -t mirrorHost=reg.example.com --out yaml
package e2e

import (
	"list"
	"tinkerbell.org/capt-playground/cue/mirror"
)

_mirrorHost: string | *"" @tag(mirrorHost)

// Mirror config used by all mirror-enabled combos.
_mirrorConfig: mirror.#Spec & {
	enabled: true
	host:    _mirrorHost
	upstreams: [
		"ghcr.io",
		"quay.io",
		"registry.k8s.io",
		"gcr.io",
		"docker.io",
	]
}

// Disabled mirror config for non-mirror combos.
_noMirror: mirror.#Spec & {
	enabled: false
}

// Per-combo overrides. Each is merged with `base` to produce a full config.
_overrides: {
	"single-nomirror-netboot": {
		bootMode:           "netboot"
		externalTinkerbell: false
		registryMirror:     _noMirror
	}
	"single-nomirror-isoboot": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		registryMirror:     _noMirror
	}
	"single-mirror-netboot": {
		bootMode:           "netboot"
		externalTinkerbell: false
		registryMirror:     _mirrorConfig
	}
	"single-mirror-isoboot": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		registryMirror:     _mirrorConfig
	}
	"external-nomirror-netboot": {
		bootMode:           "netboot"
		externalTinkerbell: true
		registryMirror:     _noMirror
	}
	"external-nomirror-isoboot": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		registryMirror:     _noMirror
	}
	"external-mirror-netboot": {
		bootMode:           "netboot"
		externalTinkerbell: true
		registryMirror:     _mirrorConfig
	}
	"external-mirror-isoboot": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		registryMirror:     _mirrorConfig
	}
}

// All combos: base merged with per-combo overrides. Each value is a
// complete config ready to be written as config.yaml for capt.
combos: {for name, ovr in _overrides {(name): base & ovr}}

// Sorted list of combo names for scripting.
comboNames: list.SortStrings([for name, _ in _overrides {name}])
