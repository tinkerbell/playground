// Wiring sentinel for the optional registry-mirror feature.
//
// The feature is intentionally split across three locations so the whole
// thing can be removed by deleting the cue/mirror/ directory plus the two
// *_extension.cue files. That makes it easy to remove — and equally easy
// to half-remove. This file is a leaf package that imports all three
// pieces; `cue vet ./cue/...` fails loudly the moment one of them
// disappears, instead of silently rendering an empty mirror config.
//
// To remove the feature cleanly, delete (in any order):
//   - cue/mirror/                          (whole package)
//   - cue/values/mirror_extension.cue
//   - cue/state/mirror_extension.cue
//   - cue/wiring/                          (this whole package)
//
// This package is intentionally a leaf — nothing imports it — so adding
// the imports below cannot create an import cycle.
package wiring

import (
	"tinkerbell.org/capt-playground/cue/mirror"
	"tinkerbell.org/capt-playground/cue/state"
	"tinkerbell.org/capt-playground/cue/values"
)

// Each line will fail with a clear "undefined field" error if the
// corresponding piece of the mirror feature is removed without removing
// this wiring file.
_sentinel: {
	// From cue/values/mirror_extension.cue:
	_valuesHasRegistryMirror: values.#Config.registryMirror | *null
	// From cue/state/mirror_extension.cue:
	_stateHasRegistryMirror: state.#ConfigInput.registryMirror | *null
	// From cue/mirror/schema.cue:
	_mirrorSpec: mirror.#Spec
	// From cue/mirror/files.cue:
	_mirrorHostsToml: mirror.HostsTomlByUpstream
	// From cue/mirror/rewrite.cue:
	_mirrorRewrite: mirror.#rewrite
}
