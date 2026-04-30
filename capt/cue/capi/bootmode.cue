// Bootmode discriminator. _mode (in resources.cue) selects netboot vs isoboot;
// this file produces the bootOptions struct embedded in each TMT and the
// extra workflow actions that only iso boot needs (disable cloud-init
// networking + install a static netplan, since iso boot has no DHCP).
//
// The interface is marked `optional: true` so systemd-networkd-wait-online
// does not gate boot on it (a static-only config can otherwise stall boot
// at the 2-minute wait-online default timeout).
package capi

_bootOptions: {
	if _mode == "netboot" {
		bootMode: "netboot"
	}
	if _mode == "isoboot" {
		bootMode: "isoboot"
		isoURL:   "http://\(values.tinkerbell.vip):7080/iso/hook.iso"
	}
}

_isoExtraActions: [
	{
		name:    "disable cloud-init networking"
		image:   "quay.io/tinkerbell/actions/writefile"
		timeout: 90
		environment: {
			CONTENTS:  "network: {config: disabled}"
			DEST_DISK: "{{ formatPartition ( index .Hardware.Disks 0 ) 3 }}"
			DEST_PATH: "/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
			DIRMODE:   "0700"
			FS_TYPE:   "ext4"
			GID:       "0"
			MODE:      "0600"
			UID:       "0"
		}
	},
	{
		name:    "create static netplan"
		image:   "quay.io/tinkerbell/actions/writefile"
		timeout: 90
		environment: {
			CONTENTS: """
				network:
				  version: 2
				  renderer: networkd
				  ethernets:
				    id0:
				      match:
				        macaddress: {{ (index .Hardware.Interfaces 0).DHCP.MAC }}
				      addresses:
				        - {{ (index .Hardware.Interfaces 0).DHCP.IP.Address }}/16
				      nameservers:
				        addresses: [{{ (index .Hardware.Interfaces 0).DHCP.NameServers | join \",\"}}]
				      routes:
				        - to: default
				          via: {{ (index .Hardware.Interfaces 0).DHCP.IP.Gateway }}
				      optional: true

				"""
			DEST_DISK: "{{ formatPartition ( index .Hardware.Disks 0 ) 3 }}"
			DEST_PATH: "/etc/netplan/config.yaml"
			DIRMODE:   "0755"
			FS_TYPE:   "ext4"
			GID:       "0"
			MODE:      "0600"
			UID:       "0"
		}
	},
]

// Empty for netboot, two extra writefile actions for isoboot.
_extraActions: [...]
_extraActions: [
	if _mode == "isoboot" for a in _isoExtraActions {a},
]
