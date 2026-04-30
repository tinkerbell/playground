// BMC Machine CRs (one per VM) and the single shared BMC credentials Secret.
// Replaces templates/bmc-machine.tmpl + templates/bmc-secret.tmpl rendered by
// scripts/generate_bmc.sh + scripts/generate_secret.sh.
package infra

import "encoding/base64"

#bmcMachine: {
	_name: string
	_port: int
	apiVersion: "bmc.tinkerbell.org/v1alpha1"
	kind:       "Machine"
	metadata: {
		name:      _name
		namespace: c.namespace
	}
	spec: connection: {
		authSecretRef: {
			name:      "bmc-creds"
			namespace: c.namespace
		}
		host:        values.virtualBMC.ip
		insecureTLS: true
		port:        _port
		providerOptions: {
			preferredOrder: ["ipmitool"]
			ipmitool: port: _port
			redfish: {
				useBasicAuth: true
				systemName:   _name
			}
		}
	}
}

outBmcMachines: {
	for name, vm in values.vm.details {
		"\(name)": #bmcMachine & {
			_name: name
			_port: vm.bmc.port
		}
	}
}

// All machines share a single Secret; only namespace, user, and password
// vary. base64.Encode happens in CUE so no shell base64 step is needed.
outBmcSecret: {
	apiVersion: "v1"
	kind:       "Secret"
	metadata: {
		name:      "bmc-creds"
		namespace: c.namespace
		labels: {
			"clusterctl.cluster.x-k8s.io/move": ""
			"clusterctl.cluster.x-k8s.io":      ""
		}
	}
	data: {
		password: base64.Encode(null, values.virtualBMC.pass)
		username: base64.Encode(null, values.virtualBMC.user)
	}
	type: "kubernetes.io/basic-auth"
}
