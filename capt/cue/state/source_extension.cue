// Additive extension of the state package: accepts an optional `source` block
// in config.yaml naming a Tinkerbell repo and ref to build from, and records
// what that resolved to.
//
// The facts about the checkout are resolved by scripts/source_prepare.sh and
// arrive as tags rather than being derived here, because they are answers only
// git and the repo's own version script can give.
//
// Two fields are deliberately absent: the registry address and the image refs
// built from it. The registry is shared and reached at a different address on
// every playground's network, so it is not known until that network exists.
// tasks/Taskfile-registry.yaml fills them in afterwards, the same way the vBMC's
// address is filled in.
//
// CUE merges sibling files in the same package, so state.cue is not touched.
// Delete this file to remove the field.
package state

#ConfigInput: {
	// null: a key written with no value parses that way, and means absent.
	source?: null | {
		// May be omitted: scripts/source_prepare.sh supplies the default, and
		// what it resolved comes back as the sourceRepo tag. Defaulting here as
		// well would be a second copy of the same decision.
		repo: string | *""
		ref:  string | *""
	}
	...
}

sourceRepo:    string | *"" @tag(sourceRepo)

sourceDir:     string | *"" @tag(sourceDir)
sourceCommit:  string | *"" @tag(sourceCommit)
sourceVersion: string | *"" @tag(sourceVersion)
sourceDirty:   string | *"false" @tag(sourceDirty)

_sourceCfg: [
	if config.source != _|_ if config.source != null {config.source},
	null,
][0]

_sourceEnabled: _sourceCfg != null

// One registry serves every playground on the host, for the same reason one
// vBMC does, so its name is fixed rather than per-instance.
_registryContainer: "capt-registry"

// The Tinkerbell image is loaded into kind rather than pulled, so it needs no
// registry and no address. That keeps an IPv6 playground reasoning about one
// protocol: the only thing that pulls over the network is the machine fetching
// the agent image.
_tinkerbellImage: "capt-playground/tinkerbell"

// What the repo's helm-package target writes, which is what the playground then
// deploys. Packaged rather than used as a directory so the chart carries the
// build's version as its appVersion -- that is what makes the image tags follow
// from the chart instead of having to be set alongside it.
_chartLocation: [
	if _sourceEnabled {"\(sourceDir)/out/helm/tinkerbell-\(sourceVersion).tgz"},
	config.chart.location,
][0]

out: {
	if _sourceEnabled {
		source: {
			// From the tag, not from config: config may legitimately omit it, and
			// this records the repo the build actually used.
			repo: sourceRepo & !=""
			ref:  _sourceCfg.ref
			// Constrained rather than merely typed: these arrive as tags, and an
			// empty one silently yields a chart path like `/out/helm/tinkerbell-.tgz`
			// and an image tagged with nothing. Better to fail the export.
			dir:               sourceDir & !=""
			commit:            sourceCommit & !=""
			version:           sourceVersion & !=""
			dirty:             sourceDirty == "true"
			registryContainer: _registryContainer
			tinkerbellImage:   _tinkerbellImage
		}
	}
}
