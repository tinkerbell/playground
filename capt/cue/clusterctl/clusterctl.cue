// clusterctl config (replaces templates/clusterctl.tmpl). Rendered by:
//   cue export ./cue/clusterctl yaml: .state -l 'values:' -e out --out yaml
//   > output/clusterctl.yaml
package clusterctl

import v "tinkerbell.org/capt-playground/cue/values"

values: v.#Config

out: {
	providers: [{
		name: "tinkerbell"
		url:  "\(values.capt.providerRepository)/\(values.versions.capt)/infrastructure-components.yaml"
		type: "InfrastructureProvider"
	}]
	images: "infrastructure-tinkerbell": tag: values.versions.capt
}
