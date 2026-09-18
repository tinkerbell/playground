// Additive extension of the values package: declares the optional
// `registryMirror` field on #Config so consumers can read it.
//
// CUE merges sibling files in the same package, so values.cue is not
// touched. Delete this file to remove the field from the schema.
package values

import "tinkerbell.org/capt-playground/cue/mirror"

#Config: {
	registryMirror?: mirror.#Spec
	// Rewritten workflow action image refs. Supplied by
	// cue/state/mirror_extension.cue and read by cue/capi.
	actionImages: [string]: string
	// Rewritten tink-agent image, passed to the chart as deployment.agentImage.
	agentImage: string
	...
}
