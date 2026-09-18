// Shared input schema (#Config) and shared computed locals (#Computed) used
// by every render subpackage (capi, infra, clusterctl).
//
// Each consumer subpackage declares its own top-level `values: #Config`
// field so that `cue export ... yaml: .state -l 'values:'` can inject the
// .state file. Consumers then instantiate `#Computed & {values: values, mode: _mode}`
// and reference the public (non-underscore) fields exposed below.
//
// Constraints in #Config catch typos before render: a missing field or a
// kube version without a leading `v` will fail `cue vet` with a line-numbered
// error.
package values

import "strings"

// Inner structs are closed to catch field-name typos at vet time. The
// outermost #Config keeps an open `...` so that sibling files (e.g.
// mirror_extension.cue) can additively extend it via the extension
// pattern documented at the top of those files.
#Config: {
	clusterName: string & !=""
	namespace:   string & !=""
	outputDir:   string & !=""
	// instance + names are added by cue/state/state.cue: the identity that
	// keeps concurrent playgrounds apart, and the host-global names derived
	// from it.
	instance?: string
	names?: close({
		network:     string & !=""
		kindCluster: string & !=""
		tinkCluster: string & !=""
		radvd:       string & !=""
		dns64:       string & !=""
	})
	arch:        "amd64" | "arm64"
	bootMode:    "netboot" | "isoboot"
	ipFamily:    "ipv4" | *"ipv4" | "ipv6"
	// Subnet prefix length and resolvers served to nodes; both are family
	// dependent and computed in cue/state.
	nodePrefix?: string & !=""
	nameServers?: [...string]

	// externalTinkerbell + totalNodes are added by cue/state/state.cue.
	externalTinkerbell?: bool
	totalNodes?:         int & >0

	versions: close({
		kube:    =~"^v[0-9]+\\.[0-9]+\\.[0-9]+$"
		os:      string | int
		kubevip: string | number
		capt:    string & !=""
		chart:   string & !=""
	})
	capt: close({
		providerRepository: string & !=""
	})
	chart: close({
		// chart.location is injected by cue/state/mirror_extension.cue;
		// it is always present in .state.
		location: string & !=""
		extraVars?: [...string]
	})
	os: close({
		// os.registry is injected by cue/state/mirror_extension.cue.
		registry: string & !=""
		sshKey:   string & !=""
		version:  string | int
	})
	// tinkerbell + cluster are populated by state.cue once the kind
	// gateway IP is known. Required here because every capi consumer
	// references them unconditionally; cue/values is only vetted via
	// .state generated AFTER the kind cluster is up (Taskfile-create's
	// `render-state` task supplies -t gatewayIP). The partial .state
	// produced by the root generate-state task is never vetted by capi.
	tinkerbell: close({
		vip:       string & !=""
		hookosVip: string & !=""
	})
	cluster: close({
		controlPlane: close({
			vip: string & !=""
		})
		podCIDR?:     string
		serviceCIDR?: string
	})
	counts: close({
		controlPlanes: int & >=1
		workers:       int & >=0
		spares:        int & >=0
	})
	vm: close({
		baseName:          string & !=""
		cpusPerVM:         int & >0
		memInMBPerVM:      int & >0
		diskSizeInGBPerVM: int & >0
		diskPath:          string & !=""
		details: [string]: close({
			mac:      string & !=""
			role:     "control-plane" | "worker" | "spare"
			ip?:      string & !=""
			gateway?: string & !=""
			bmc: close({
				port: int & >0
			})
		})
	})
	virtualBMC: close({
		// containerName + image come from config.yaml; ip is injected by
		// tasks/Taskfile-vbmc.yaml after the vbmc container starts (its
		// IP is only known then). Required here because cue/infra/bmc.cue
		// references it unconditionally; cue/infra is only vetted via a
		// .state regenerated AFTER vbmc:update-state has run.
		containerName: string & !=""
		image:         string & !=""
		ip:            string & !=""
		user:          string & !=""
		pass:          string & !=""
	})
	captainos?: close({
		kernelVersion: string & !=""
	})
	// kind block is populated by state.cue.
	kind?: close({
		kubeconfig:  string & !=""
		gatewayIP?:  string & !=""
		nodeIPBase?: string & !=""
		bridgeName?: string & !=""
		gatewayIP6?: string & !=""
		subnet6?:    string & !=""
		tinkerbell?: close({
			clusterName: string & !=""
			kubeconfig:  string & !=""
		})
	})
	// registryMirror is added by cue/values/mirror_extension.cue.
	...
}

// All values-derived names and snippets shared across subpackages. Public
// (non-underscore) fields so that consumers in other packages can reference
// them after instantiating: `c: values.#Computed & {values: values, mode: _mode}`.
#Computed: {
	values: #Config
	mode:   "netboot" | "isoboot"

	isV6: values.ipFamily == "ipv6"

	// IPv6 literals must be bracketed anywhere they appear in a URL or an
	// address:port pair. Applied to every such use below.
	#hostPort: {
		_addr: string
		out: [
			if isV6 {"[\(_addr)]"},
			_addr,
		][0]
	}

	tinkerbellHost: (#hostPort & {_addr: values.tinkerbell.vip}).out
	hookosHost:     (#hostPort & {_addr: values.tinkerbell.hookosVip}).out

	// Defaults keep the pre-IPv6 behaviour for a .state rendered before
	// cue/state started emitting these fields.
	nameServers: [
		if values.nameServers != _|_ {values.nameServers},
		["8.8.8.8", "1.1.1.1"],
	][0]

	nodePrefix: [
		if values.nodePrefix != _|_ {values.nodePrefix},
		"16",
	][0]

	serviceCIDR: [
		if values.cluster.serviceCIDR != _|_ {values.cluster.serviceCIDR},
		"172.26.0.0/16",
	][0]

	// Replace dots in the kube version so it can suffix CR names without
	// violating DNS subdomain rules. e.g. v1.35.2 -> v1-35-2.
	dashedKubeVersion: strings.Replace(values.versions.kube, ".", "-", -1)

	// Map OCI arch names (amd64/arm64) to the Linux kernel / DHCP arch
	// names used in Hardware CRs and HookOS ISO filenames.
	dhcpArch: {
		if values.arch == "amd64" {"x86_64"}
		if values.arch == "arm64" {"aarch64"}
	}

	// Normalize dotted Ubuntu versions (e.g. 20.04 -> 2004) so image
	// tags match the published CAPT naming scheme.
	normalizedOSVersion: strings.Replace("\(values.os.version)", ".", "", -1)

	clusterName:      values.clusterName
	namespace:        values.namespace
	kcpName:          "\(clusterName)-control-plane"
	mdName:           "\(clusterName)-worker-a"
	kctName:          "\(clusterName)-worker-a"
	tinkClusterName:  clusterName
	tmtCpName:        "\(clusterName)-control-plane-\(dashedKubeVersion)"
	tmtWorkerName:    "\(clusterName)-worker-a-\(dashedKubeVersion)"

	// Shared list of cloud-init users injected into KCP and KCT.
	users: [{
		name: "tink"
		sudo: "ALL=(ALL) NOPASSWD:ALL"
		sshAuthorizedKeys: [values.os.sshKey]
	}]

	imgURL: "\(values.os.registry):\(normalizedOSVersion)-\(values.versions.kube)-\(values.arch).gz"

	metadataURL: "http://\(tinkerbellHost):7080"

	// kube-vip advertises the control-plane VIP with ARP on IPv4 and NDP on
	// IPv6, and the default-route lookup must query the matching family to
	// find the interface to advertise on.
	_defaultRouteDev: [
		if isV6 {"$(ip -6 -j route list default | jq -r .[0].dev)"},
		"$(ip -4 -j route list default | jq -r .[0].dev)",
	][0]

	// kube-vip preKubeadmCommand. Single string (one entry in preKubeadmCommands).
	// k8s v1.29+ uses super-admin.conf; the if/else guards older clusters.
	kubeVipCmd: strings.Join([
		"if [ $(cat /etc/kubernetes-version | awk -F. '{print $2}') -ge 29 ] && [ -f /run/kubeadm/kubeadm.yaml ]; then export KUBE_FILE=/etc/kubernetes/super-admin.conf; else export KUBE_FILE=/etc/kubernetes/admin.conf; fi",
		"mkdir -p /etc/kubernetes/manifests",
		"ctr images pull ghcr.io/kube-vip/kube-vip:v\(values.versions.kubevip)",
		"ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:v\(values.versions.kubevip) vip /kube-vip manifest pod --arp --interface \(_defaultRouteDev) --address \(values.cluster.controlPlane.vip) --controlplane --leaderElection --k8sConfigPath $KUBE_FILE > /etc/kubernetes/manifests/kube-vip.yaml",
	], " && ")
}
