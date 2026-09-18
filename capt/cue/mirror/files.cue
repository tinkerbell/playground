// Renders containerd registry-mirror configuration in the modern
// hosts.toml drop-in style — required for containerd v2.x (kindest/node
// v1.35+) which rejects the legacy `[plugins."...".registry.mirrors.<u>]`
// inline form with:
//
//	`mirrors` cannot be set when `config_path` is provided
//
// Single source of truth (`HostsTomlByUpstream`) consumed by:
//   - cue/kind/kind.cue: rendered to host-side files under
//     <outputDir>/certs.d/<u>/hosts.toml and bind-mounted into kind nodes
//     via nodes[].extraMounts -> /etc/containerd/certs.d
//   - cue/capi/resources.cue: emitted as cloud-init `files:` entries on
//     workload nodes at /etc/containerd/certs.d/<u>/hosts.toml
//
// Pipelines:
//   cue export ./cue/mirror yaml: .state -l 'values:' -e hostsTomlByUpstream --out json
//   cue export ./cue/mirror yaml: .state -l 'values:' -e cloudInitFiles      --out json
package mirror

values: {
	registryMirror: #Spec
	...
}

// Upstream fallback endpoint for a given namespace. containerd uses `server`
// when the mirror misses, so it has to be a real registry API.
//
// docker.io is NOT one: https://docker.io/v2/... redirects to
// https://www.docker.com/, which answers 200 text/html, and containerd then
// fails with "unexpected media type text/html" while trying to parse the
// marketing page as a manifest. The v2 API lives on registry-1.docker.io.
// The certs.d directory keeps the docker.io name either way -- that is the
// namespace containerd looks up, not the endpoint it dials.
#serverURL: {
	upstream: string
	out: [
		if upstream == "docker.io" {"https://registry-1.docker.io"},
		"https://\(upstream)",
	][0]
}

// Per-upstream hosts.toml body. Map shape: { "<upstream>": "<toml body>" }.
// Empty when the feature is off or no upstreams are configured.
//
// hosts.toml schema reference:
//   https://github.com/containerd/containerd/blob/main/docs/hosts.md
HostsTomlByUpstream: {
	if values.registryMirror.enabled for u in values.registryMirror.upstreams {
		"\(u)": """
			server = "\((#serverURL & {upstream: u}).out)"

			[host."https://\(values.registryMirror.host)"]
			  capabilities = ["pull", "resolve"]
			"""
	}
}

// Flat list of {path, content} for the host-side certs.d tree consumed by
// tasks/Taskfile-mirror.yaml#render-kind-config. `path` is relative to
// the chosen output directory (e.g. "ghcr.io/hosts.toml"). Empty list
// when the feature is off — the task wipes the directory regardless so
// disabled-state leaves no stale files.
hostCertsdFiles: [
	if values.registryMirror.enabled for u in values.registryMirror.upstreams {
		{
			path:    "\(u)/hosts.toml"
			content: HostsTomlByUpstream[u]
		}
	},
]

// Cloud-init `files:` entries for workload nodes. One file per upstream
// at /etc/containerd/certs.d/<u>/hosts.toml plus a tiny conf.d drop-in
// that sets `config_path` (Ubuntu's containerd default doesn't set it;
// kind's does, so kind nodes don't get this drop-in — they get a host
// bind-mount instead, see cue/kind/kind.cue).
//
// Ubuntu's default containerd config has `imports = ["/etc/containerd/conf.d/*.toml"]`.
cloudInitFiles: [
	if values.registryMirror.enabled for u in values.registryMirror.upstreams {
		{
			path:        "/etc/containerd/certs.d/\(u)/hosts.toml"
			owner:       "root:root"
			permissions: "0644"
			content:     HostsTomlByUpstream[u]
		}
	},
	if values.registryMirror.enabled && len(values.registryMirror.upstreams) > 0 {
		{
			path:        "/etc/containerd/conf.d/registry-config-path.toml"
			owner:       "root:root"
			permissions: "0644"
			content: """
				version = 2
				[plugins."io.containerd.grpc.v1.cri".registry]
				  config_path = "/etc/containerd/certs.d"
				"""
		}
	},
]
