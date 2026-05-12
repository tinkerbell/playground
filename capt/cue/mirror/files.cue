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

// Per-upstream hosts.toml body. Map shape: { "<upstream>": "<toml body>" }.
// Empty when the feature is off or no upstreams are configured.
//
// hosts.toml schema reference:
//   https://github.com/containerd/containerd/blob/main/docs/hosts.md
HostsTomlByUpstream: {
	if values.registryMirror.enabled for u in values.registryMirror.upstreams {
		"\(u)": """
			server = "https://\(u)"

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
