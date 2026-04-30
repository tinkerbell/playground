// Render entrypoint for the CAPI subpackage. The pipeline runs:
//   cue export ./cue/capi yaml: .state -l 'values:' -t mode=<bootMode> -e out --out text
// `out` is a multi-document YAML string produced by yaml.MarshalStream so each
// resource is separated by `---` and kubectl apply -f can ingest the result.
package capi

import "encoding/yaml"

_resources: [
	_cluster,
	_tinkerbellCluster,
	_kcp,
	_md,
	_kct,
	_tmtCp,
	_tmtWorker,
]

out: yaml.MarshalStream(_resources)
