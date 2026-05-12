// Schema for the optional registry-mirror feature. Self-contained CUE package
// so the entire feature can be removed by deleting cue/mirror/, the sibling
// *_extension.cue files in cue/values and cue/state, the cue/kind/ package,
// tasks/Taskfile-mirror.yaml, the `mirror:` include, the `task: mirror:...`
// lines in tasks/Taskfile-create.yaml, and the `registryMirror:` block in
// config.yaml.
//
// HTTPS only. The mirror host must present a publicly-trusted CA cert. There
// are no insecure knobs (no skip_verify, no custom CA).
package mirror

// Public spec consumed by the values and state packages via additive
// extension files. enabled=false makes every consumer a no-op.
//
// When enabled=true, both `host` and `upstreams` must be non-empty (and
// every upstream entry must itself be non-empty). The conditional block
// below tightens the otherwise-defaulted fields so an empty host or
// empty upstreams list fails `cue vet`/`cue export` with a line-numbered
// error before any task runs, instead of silently rendering broken
// `https:///...` URLs and an empty certs.d tree.
#Spec: {
	enabled: bool | *false
	host:    string | *""
	upstreams: [...string] | *[]

	if enabled == true {
		host: string & !=""
		upstreams: [string & !="", ...string & !=""]
	}
}
