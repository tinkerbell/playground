// URL rewrite helper. Replaces the first matching `<upstream>/` (or
// `oci://<upstream>/`) prefix in `in` with `cfg.host/`. When the mirror is
// disabled, no upstream is configured, or no upstream matches, returns
// `in` unchanged.
//
// Used by cue/state/state.cue to rewrite the small set of image strings
// that are pulled OUTSIDE any containerd (and therefore can't benefit from
// the containerd registry-mirror config baked in by cue/kind and
// cue/capi/resources.cue):
//   - chart.location  (helm OCI client on the host)
//   - os.registry     (crane inside the oci2disk action container)
//   - virtualBMC.image (docker run on the host)
//
// Everything else flows through a containerd that has the mirror baked
// in — do NOT rewrite those, because doing so hides the original upstream
// from the operator and breaks debuggability.
package mirror

import "strings"

#rewrite: {
	in:  string
	cfg: #Spec
	// First-match wins. Each candidate prefix is tried in declaration order;
	// the first one that matches `in` produces the rewritten string. If none
	// match (or cfg.enabled is false), `in` flows through unchanged.
	_candidates: [
		if cfg.enabled for u in cfg.upstreams {
			{prefix: "oci://\(u)/", replacement: "oci://\(cfg.host)/"}
		},
		if cfg.enabled for u in cfg.upstreams {
			{prefix: "\(u)/", replacement: "\(cfg.host)/"}
		},
	]
	_matches: [for c in _candidates if strings.HasPrefix(in, c.prefix) {
		c.replacement + strings.TrimPrefix(in, c.prefix)
	}]
	out: [
		if len(_matches) > 0 {_matches[0]},
		in,
	][0]
}
