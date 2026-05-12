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
		extraVars?: [...string]
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
		containerName: string & !=""
		image:         string & !=""
		user:          string & !=""
		pass:          string & !=""
	}
	captainos?: {
		kernelVersion: string & !=""
	}
}

config: #ConfigInput

cwd:        string | *""             @tag(cwd)
sshPubKey:  string | *""             @tag(sshPubKey)
_gatewayIP: string | *""             @tag(gatewayIP)
_bridge:    string | *""             @tag(bridgeName)

_outputDir: [
	if path.IsAbs(config.outputDir, path.Unix) {config.outputDir},
	if cwd != "" {path.Join([cwd, config.outputDir], path.Unix)},
	config.outputDir,
][0]

_totalNodes: config.counts.controlPlanes + config.counts.workers + config.counts.spares

_osVersion: strings.Replace("\(config.versions.os)", ".", "", -1)

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
	"\(_gwParts[0]).\(_gwParts[1]).10.20",
][0]
_baseLastOctet: 20

#offsetIP: {
	_offset: int
	out: [
		if _gatewayIP == "" {""},
		"\(_gwParts[0]).\(_gwParts[1]).10.\(_baseLastOctet+_offset)",
	][0]
}

_podCIDR: [
	if _gatewayIP == "" {""},
	"\(_gwParts[0]).100.0.0/16",
][0]

_details: {
	for i in _indexes {
		"\(config.vm.baseName)\(i)": {
			mac:  (#mac & {_input: "\(config.vm.baseName)\(i)"}).out
			bmc: port: 6230 + i
			role: (#role & {_idx: i}).out
			if _gatewayIP != "" {
				ip:      (#offsetIP & {_offset: i}).out
				gateway: _gatewayIP
			}
		}
	}
}

out: {
	clusterName: config.clusterName
	outputDir:   _outputDir
	namespace:   config.namespace
	arch:        config.arch
	bootMode:    config.bootMode
	externalTinkerbell: config.externalTinkerbell
	counts:   config.counts
	versions: config.versions
	capt:     config.capt
	// chart.location is supplied by cue/state/mirror_extension.cue (so the
	// optional registry mirror can rewrite it). Pass through everything else.
	chart: {
		if config.chart.extraVars != _|_ {
			extraVars: config.chart.extraVars
		}
	}
	os: {
		// os.registry is supplied by cue/state/mirror_extension.cue.
		sshKey:  sshPubKey
		version: _osVersion
	}
	vm: {
		baseName:          config.vm.baseName
		cpusPerVM:         config.vm.cpusPerVM
		memInMBPerVM:      config.vm.memInMBPerVM
		diskSizeInGBPerVM: config.vm.diskSizeInGBPerVM
		diskPath:          config.vm.diskPath
		details:           _details
	}
	virtualBMC: {
		containerName: config.virtualBMC.containerName
		// virtualBMC.image is supplied by cue/state/mirror_extension.cue.
		user: config.virtualBMC.user
		pass: config.virtualBMC.pass
	}
	if config.captainos != _|_ {
		captainos: config.captainos
	}
	totalNodes: _totalNodes
	kind: {
		kubeconfig: "\(_outputDir)/kind.kubeconfig"
		if _gatewayIP != "" {
			gatewayIP:  _gatewayIP
			nodeIPBase: _nodeIPBase
		}
		if _bridge != "" {
			bridgeName: _bridge
		}
		// Second KinD cluster used as the Tinkerbell stack target when
		// `externalTinkerbell: true`. Same docker network ("kind") so pods
		// in the management cluster can reach the Tinkerbell API server via
		// the container IP (see scripts/create_external_kubeconfig_secret.sh).
		if config.externalTinkerbell {
			tinkerbell: {
				clusterName: "\(config.clusterName)-tinkerbell"
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
			podCIDR: _podCIDR
		}
	}
}
