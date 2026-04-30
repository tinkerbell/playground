// Hardware CRs, one per VM in values.vm.details.
//
// outHardware is a map keyed by node name; the Taskfile iterates over the
// keys and runs `cue export -e outHardware.<name> --out yaml` once per node
// so each Hardware CR lands in its own output/hardware-<name>.yaml file.
package infra

#hardware: {
	_name:    string
	_mac:     string
	_role:    "control-plane" | "worker" | "spare"
	_ip:      string
	_gateway: string

	apiVersion: "tinkerbell.org/v1alpha1"
	kind:       "Hardware"
	metadata: {
		labels: {
			"tinkerbell.org/role":          _role
			"node.cluster.x-k8s.io/rack":   "test-\(_role)"
		}
		name:      _name
		namespace: c.namespace
	}
	spec: {
		bmcRef: {
			apiGroup: "bmc.tinkerbell.org"
			kind:     "Machine"
			name:     _name
		}
		disks: [{device: "/dev/vda"}]
		interfaces: [{
			dhcp: {
				arch:     c.dhcpArch
				hostname: _name
				ip: {
					address: _ip
					gateway: _gateway
					netmask: "255.255.0.0"
				}
				lease_time: 4294967294
				mac:        _mac
				uefi:       true
				name_servers: ["8.8.8.8", "1.1.1.1"]
			}
			netboot: {
				allowPXE:      true
				allowWorkflow: true
			}
		}]
		metadata: instance: {
			hostname: _name
			id:       _mac
		}
	}
}

outHardware: {
	for name, vm in values.vm.details {
		"\(name)": #hardware & {
			_name:    name
			_mac:     vm.mac
			_role:    vm.role
			_ip:      vm.ip
			_gateway: vm.gateway
		}
	}
}
