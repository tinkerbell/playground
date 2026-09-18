// Test matrix: 4 binary axes → 16 combos.
//
// Combo names read as <topology>-<ipFamily>-<bootMode>-<registry>, one segment
// per axis, always in that order:
//   1. Topology:  colocated (Tinkerbell in the mgmt cluster) vs external
//   2. IP family: ipv4 vs ipv6
//   3. Boot:      netboot (iPXE) vs isoboot (ISO)
//   4. Registry:  direct (straight to upstream) vs mirror (pull-through cache)
//
// Every axis appears in every name, so a name alone says exactly what is
// exercised, and the segments match the Ginkgo labels one-for-one.
//
// Combos are written out rather than generated from the axes, so that adding
// one is a deliberate act and any combo that needs a caveat has somewhere to
// carry it.
//
// Usage (from the capt/ directory):
//   # List all combo names
//   cue eval ./e2e/cue -e comboNames --out json
//
//   # Render a single combo as config.yaml. chartVersion has no default, so it
//   # must be given here; `e2e config <combo>` resolves it for you instead.
//   cue export ./e2e/cue -e 'combos["colocated-ipv4-netboot-direct"]' \
//     -t chartVersion=v0.25.1-6e7d2775 --out yaml
//
//   # Render all combos (struct keyed by name)
//   cue export ./e2e/cue -e combos -t chartVersion=v0.25.1-6e7d2775 \
//     -t mirrorHost=reg.example.com --out yaml
package e2e

import (
	"list"
	"strings"
	"tinkerbell.org/capt-playground/cue/mirror"
)

_mirrorHost: string | *"" @tag(mirrorHost)

// Mirror config used by all mirror-enabled combos, IPv4 and IPv6 alike. The
// IPv6 combos reach an IPv4-only mirror through the playground's NAT64/DNS64
// layer, so they need no separate configuration.
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

// Disabled mirror config: images are pulled straight from upstream.
_direct: mirror.#Spec & {
	enabled: false
}

// Per-combo overrides. Each is merged with `base` to produce a full config.
_overrides: {
	"colocated-ipv4-netboot-direct": {
		bootMode:           "netboot"
		externalTinkerbell: false
		registryMirror:     _direct
	}
	"colocated-ipv4-isoboot-direct": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		registryMirror:     _direct
	}
	"colocated-ipv4-netboot-mirror": {
		bootMode:           "netboot"
		externalTinkerbell: false
		registryMirror:     _mirrorConfig
	}
	"colocated-ipv4-isoboot-mirror": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		registryMirror:     _mirrorConfig
	}
	"external-ipv4-netboot-direct": {
		bootMode:           "netboot"
		externalTinkerbell: true
		registryMirror:     _direct
	}
	"external-ipv4-isoboot-direct": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		registryMirror:     _direct
	}
	"external-ipv4-netboot-mirror": {
		bootMode:           "netboot"
		externalTinkerbell: true
		registryMirror:     _mirrorConfig
	}
	"external-ipv4-isoboot-mirror": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		registryMirror:     _mirrorConfig
	}
	// The -direct IPv6 combos are not a contradiction: ghcr.io publishes no
	// AAAA record at all, but DNS64 synthesises one for every name via
	// translate_all, so NAT64 carries the upstream pulls. The mirror is a
	// bandwidth cache here, not the only path to an IPv4-only registry.
	"colocated-ipv6-netboot-direct": {
		bootMode:           "netboot"
		externalTinkerbell: false
		ipFamily:           "ipv6"
		registryMirror:     _direct
	}
	"colocated-ipv6-isoboot-direct": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		ipFamily:           "ipv6"
		registryMirror:     _direct
	}
	"colocated-ipv6-netboot-mirror": {
		bootMode:           "netboot"
		externalTinkerbell: false
		ipFamily:           "ipv6"
		registryMirror:     _mirrorConfig
	}
	"colocated-ipv6-isoboot-mirror": {
		bootMode:           "isoboot"
		externalTinkerbell: false
		ipFamily:           "ipv6"
		registryMirror:     _mirrorConfig
	}
	"external-ipv6-netboot-direct": {
		bootMode:           "netboot"
		externalTinkerbell: true
		ipFamily:           "ipv6"
		registryMirror:     _direct
	}
	"external-ipv6-isoboot-direct": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		ipFamily:           "ipv6"
		registryMirror:     _direct
	}
	"external-ipv6-netboot-mirror": {
		bootMode:           "netboot"
		externalTinkerbell: true
		ipFamily:           "ipv6"
		registryMirror:     _mirrorConfig
	}
	"external-ipv6-isoboot-mirror": {
		bootMode:           "isoboot"
		externalTinkerbell: true
		ipFamily:           "ipv6"
		registryMirror:     _mirrorConfig
	}
}

// All combos: base merged with per-combo overrides. Each value is a
// complete config ready to be written as config.yaml for capt.
combos: {for name, ovr in _overrides {(name): base & ovr}}

// Sorted list of combo names for scripting.
comboNames: list.SortStrings([for name, _ in _overrides {name}])

// Sorted list of combos that need a registry mirror host supplied.
mirrorCombos: list.SortStrings([for name, ovr in _overrides if ovr.registryMirror.enabled {name}])

// Ginkgo --label-filter per combo. A spec that only applies to one value of an
// axis carries that value as a Ginkgo label (e.g. Label("provisioning",
// "ipv6")); the filter below excludes every axis value this combo does not
// exercise, so unlabelled specs run everywhere and labelled ones run only
// where they apply. The label vocabulary is the combo name's segments.
comboLabels: {
	for name, cfg in combos {
		(name): strings.Join([
			"provisioning",
			if cfg.ipFamily == "ipv6" {"!ipv4"},
			if cfg.ipFamily == "ipv4" {"!ipv6"},
			if cfg.bootMode == "isoboot" {"!netboot"},
			if cfg.bootMode == "netboot" {"!isoboot"},
			if cfg.registryMirror.enabled {"!direct"},
			if !cfg.registryMirror.enabled {"!mirror"},
			if cfg.externalTinkerbell {"!colocated"},
			if !cfg.externalTinkerbell {"!external"},
		], " && ")
	}
}

// Axis values per combo, so `run.sh list` can show what each one exercises
// rather than making the reader decode the name. The single-element-list
// comprehension is CUE's stand-in for a conditional expression.
comboInfo: {
	for name, cfg in combos {
		(name): {
			tinkerbell: [if cfg.externalTinkerbell {"external"}, "colocated"][0]
			family: cfg.ipFamily
			boot:   cfg.bootMode
			registry: [if cfg.registryMirror.enabled {"mirror"}, "direct"][0]
		}
	}
}
