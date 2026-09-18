package state

import (
	"crypto/md5"
	"encoding/hex"
	"list"
	"strings"
	"path"
)

#ConfigInput: {
	clusterName: string & !=""
	outputDir:   string & !=""
	namespace:   string & !=""
	arch:        "amd64" | "arm64"
	bootMode:    "netboot" | "isoboot"
	// ipv6 disables DHCPv4 entirely and drives Smee's DHCPv6 server. It requires
	// an RA source on the bridge (tasks/Taskfile-radvd.yaml) because Tinkerbell
	// does not send Router Advertisements.
	ipFamily:    "ipv4" | *"ipv4" | "ipv6"
	externalTinkerbell: bool | *false
	counts: {
		controlPlanes: int & >=1
		workers:       int & >=0
		spares:        int & >=0
	}
	versions: {
		capt:    string & !=""
		chart:   string & !=""
		kube:    =~"^v[0-9]+\\.[0-9]+\\.[0-9]+$"
		os:      string | int
		kubevip: string | number
	}
	capt: providerRepository: string & !=""
	chart: {
		location: string & !=""
		// null: a key written with no value parses that way, and means absent.
		extraVars?: null | [...string]
	}
	os: {
		registry: string & !=""
	}
	vm: {
		baseName:           string & !=""
		cpusPerVM:          int & >0
		memInMBPerVM:       int & >0
		diskSizeInGBPerVM:  int & >0
		diskPath:           string & !=""
	}
	virtualBMC: {
		image: string & !=""
	}
	captainos?: null | {
		kernelVersion: string & !=""
	}
}

config: #ConfigInput

cwd:        string | *""             @tag(cwd)
sshPubKey:  string | *""             @tag(sshPubKey)
_gatewayIP: string | *""             @tag(gatewayIP)
_bridge:    string | *""             @tag(bridgeName)

// Identifies one playground among however many share the host. The caller
// derives it from the state file's path (see Taskfile.yaml#INSTANCE_ID), so it
// is stable for the life of a playground without anything having to store it,
// and distinct for anything driven by a different state file.
//
// Left empty the playground still works, it just takes the unsuffixed names it
// always used -- which is the right default for a host running only one.
instanceID: string | *""             @tag(instanceID)

_suffix: [
	if instanceID != "" {"-\(instanceID)"},
	"",
][0]

// Names of everything the host, rather than a cluster, has to keep distinct:
// docker networks and containers, KinD clusters and libvirt domains all share
// one namespace per machine. Kubernetes objects are not here -- they are
// already scoped by the cluster they live in.
_names: {
	network:     "\(config.clusterName)\(_suffix)"
	kindCluster: "\(config.clusterName)\(_suffix)"
	tinkCluster: "\(config.clusterName)\(_suffix)-tinkerbell"
	radvd:       "radvd\(_suffix)"
	dns64:       "dns64\(_suffix)"
}

// Libvirt domains are host-global, and their names drive the VM MACs and disk
// image filenames, so prefixing here keeps all three distinct at once.
_vmPrefix: [
	if instanceID != "" {"\(instanceID)-\(config.vm.baseName)"},
	config.vm.baseName,
][0]

// IPv6 equivalents of _gatewayIP, sourced from the same `docker network
// inspect kind` call in Taskfile-create.yaml#update-state. _subnet6 is the
// bridge's /64 (e.g. "fc00:f853:ccd:e793::/64"); addresses below are built by
// concatenating host suffixes onto it, which avoids any IPv6 arithmetic in CUE.
_gatewayIP6: string | *""            @tag(gatewayIP6)
_subnet6:    string | *""            @tag(subnet6)

_isV6: config.ipFamily == "ipv6"

// "fc00:f853:ccd:e793::/64" -> "fc00:f853:ccd:e793"
_net6: strings.TrimSuffix(strings.TrimSuffix(_subnet6, "/64"), "::")

_outputDirBase: [
	if path.IsAbs(config.outputDir, path.Unix) {config.outputDir},
	if cwd != "" {path.Join([cwd, config.outputDir], path.Unix)},
	config.outputDir,
][0]

// Instance-scoped so two playgrounds pointed at the same config still keep
// their kubeconfigs, certs and rendered manifests apart.
_outputDir: [
	if instanceID != "" {path.Join([_outputDirBase, instanceID], path.Unix)},
	_outputDirBase,
][0]

_totalNodes: config.counts.controlPlanes + config.counts.workers + config.counts.spares

_osVersion: strings.Replace("\(config.versions.os)", ".", "", -1)

// Upstream refs for every image the workflow actions use. Rewritten through
// the registry mirror by cue/state/mirror_extension.cue, which owns
// `out.actionImages`; cue/capi reads them from there rather than hardcoding
// registry hostnames.
_actionImages: {
	oci2disk:   "quay.io/tinkerbell/actions/oci2disk"
	writefile:  "quay.io/tinkerbell/actions/writefile"
	kexec:      "quay.io/tinkerbell/actions/kexec"
	waitdaemon: "ghcr.io/jacobweinstock/waitdaemon:latest"
}

// Chart default for the agent image. Smee bakes this into the iPXE kernel
// cmdline as `tink_worker_image`, and CaptainOS pulls it with a containerd
// that has no certs.d tree -- so like the action images it has to be rewritten
// here rather than redirected at runtime.
_agentImage: "ghcr.io/tinkerbell/tink-agent"

// Static because one vBMC container serves every playground on the host: it is
// reached over each playground's own docker network, so it needs no per-
// instance name, and one container can hold only one credential pair.
_vbmcContainer: "capt-vbmc"
_vbmcUser:      "root"
_vbmcPass:      "calvin"

_indexes: list.Range(1, _totalNodes+1, 1)

#mac: {
	_input: string
	_sum:   md5.Sum(_input + "\n")
	_hex:   strings.Split(hex.Encode(_sum), "")
	out:    "02:" + strings.Join([
		_hex[0] + _hex[1],
		_hex[2] + _hex[3],
		_hex[4] + _hex[5],
		_hex[6] + _hex[7],
		_hex[8] + _hex[9],
	], ":")
}

#role: {
	_idx: int
	out: [
		if _idx <= config.counts.controlPlanes {"control-plane"},
		if _idx <= config.counts.controlPlanes+config.counts.workers {"worker"},
		"spare",
	][0]
}

_gwParts: strings.Split(_gatewayIP, ".")
_nodeIPBase: [
	if _gatewayIP == "" {""},
	if _isV6 {"\(_net6)::10:0"},
	"\(_gwParts[0]).\(_gwParts[1]).10.20",
][0]
_baseLastOctet: 20

// Host suffixes are laid out under ::10:/112 so they cannot collide with the
// low addresses docker's own IPAM hands out to containers on the same bridge.
#offsetIP: {
	_offset: int
	out: [
		if _gatewayIP == "" {""},
		if _isV6 {"\(_net6)::10:\(_baseLastOctet+_offset)"},
		"\(_gwParts[0]).\(_gwParts[1]).10.\(_baseLastOctet+_offset)",
	][0]
}

_podCIDR: [
	if _gatewayIP == "" {""},
	if _isV6 {"fd00:10:244::/56"},
	"\(_gwParts[0]).100.0.0/16",
][0]

_serviceCIDR: [
	if _isV6 {"fd00:10:96::/112"},
	"172.26.0.0/16",
][0]

// Prefix length served to nodes. Matches the bridge /64 on IPv6 and the
// historical /16 the playground has always used on IPv4.
_nodePrefix: [
	if _isV6 {"64"},
	"16",
][0]

// NAT64/DNS64 translation layer (tasks/Taskfile-nat64.yaml), IPv6 only.
//
// A ULA-based Network-Specific Prefix, not RFC 8215's 64:ff9b:1::/96 and not
// the RFC 6052 well-known 64:ff9b::/96. The well-known prefix may not be used
// to translate RFC1918 destinations, and a self-hosted registry mirror is
// very often on a private LAN address. TAYGA 0.9.2 predates RFC 8215 and
// applies that same prohibition to anything under 64:ff9b:, so the
// nominally-correct local-use prefix is silently rejected too: it answers
// ICMPv6 "unreachable route" and never emits an IPv4 packet. Verified.
_nat64Prefix: "fd00:64::/96"

// Address of the DNS64 resolver on the kind bridge. Offsets 1.._totalNodes
// belong to the machines and _totalNodes+50..+52 to the VIPs, so a fixed high
// offset stays clear of both regardless of cluster size.
_dns64IP: (#offsetIP & {_offset: 200}).out

// On IPv6 the machines are handed the local DNS64 resolver instead of public
// resolvers: without a synthesised AAAA they cannot reach an IPv4-only
// registry at all. Falls back to the public list until the bridge subnet is
// known (first render, before the kind network exists).
_nameServers: [
	if _isV6 && _dns64IP != "" {[_dns64IP]},
	if _isV6 {["2606:4700:4700::1111", "2001:4860:4860::8888"]},
	["8.8.8.8", "1.1.1.1"],
][0]

_details: {
	for i in _indexes {
		"\(_vmPrefix)\(i)": {
			mac:  (#mac & {_input: "\(_vmPrefix)\(i)"}).out
			bmc: port: 6230 + i
			role: (#role & {_idx: i}).out
			if _gatewayIP != "" {
				ip: (#offsetIP & {_offset: i}).out
				gateway: [
					if _isV6 {_gatewayIP6},
					_gatewayIP,
				][0]
			}
		}
	}
}

out: {
	// clusterName stays the CAPI workload cluster's name. It is a Kubernetes
	// object inside a cluster of its own, so it never has to be unique on the
	// host -- `names` covers everything that does.
	clusterName: config.clusterName
	instance:    instanceID
	names:       _names
	outputDir:   _outputDir
	namespace:   config.namespace
	arch:        config.arch
	bootMode:    config.bootMode
	ipFamily:    config.ipFamily
	nodePrefix:  _nodePrefix
	nameServers: _nameServers
	externalTinkerbell: config.externalTinkerbell
	counts:   config.counts
	versions: config.versions
	capt:     config.capt
	// chart.location is supplied by cue/state/mirror_extension.cue (so the
	// optional registry mirror can rewrite it). Pass through everything else.
	chart: {
		if config.chart.extraVars != _|_ if config.chart.extraVars != null {
			extraVars: config.chart.extraVars
		}
	}
	os: {
		// os.registry is supplied by cue/state/mirror_extension.cue.
		sshKey:  sshPubKey
		version: _osVersion
	}
	vm: {
		baseName:          _vmPrefix
		cpusPerVM:         config.vm.cpusPerVM
		memInMBPerVM:      config.vm.memInMBPerVM
		diskSizeInGBPerVM: config.vm.diskSizeInGBPerVM
		diskPath:          config.vm.diskPath
		details:           _details
	}
	virtualBMC: {
		containerName: _vbmcContainer
		// virtualBMC.image is supplied by cue/state/mirror_extension.cue.
		// One vBMC is shared by every playground on the host, so it has one
		// credential pair; these are fixed rather than configurable.
		user: _vbmcUser
		pass: _vbmcPass
	}
	if config.captainos != _|_ if config.captainos != null {
		captainos: config.captainos
	}
	totalNodes: _totalNodes
	if _isV6 {
		nat64: {
			prefix: _nat64Prefix
			if _dns64IP != "" {
				dns64IP: _dns64IP
			}
		}
	}
	kind: {
		kubeconfig: "\(_outputDir)/kind.kubeconfig"
		if _gatewayIP != "" {
			gatewayIP:  _gatewayIP
			nodeIPBase: _nodeIPBase
		}
		if _bridge != "" {
			bridgeName: _bridge
		}
		if _isV6 && _subnet6 != "" {
			gatewayIP6: _gatewayIP6
			subnet6:    _subnet6
		}
		// Second KinD cluster used as the Tinkerbell stack target when
		// `externalTinkerbell: true`. Same docker network as the management
		// cluster (the playground's own, see tasks/Taskfile-network.yaml) so
		// pods in the management cluster can reach the Tinkerbell API server
		// via the container IP (see scripts/create_external_kubeconfig_secret.sh).
		if config.externalTinkerbell {
			tinkerbell: {
				clusterName: _names.tinkCluster
				kubeconfig:  "\(_outputDir)/tinkerbell-kind.kubeconfig"
			}
		}
	}
	if _gatewayIP != "" {
		tinkerbell: {
			vip:       (#offsetIP & {_offset: _totalNodes + 51}).out
			hookosVip: (#offsetIP & {_offset: _totalNodes + 50}).out
		}
		cluster: {
			controlPlane: vip: (#offsetIP & {_offset: _totalNodes + 52}).out
			podCIDR:     _podCIDR
			serviceCIDR: _serviceCIDR
		}
	}
}
