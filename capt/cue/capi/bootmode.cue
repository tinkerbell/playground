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
		// CAPT splits this path and inserts the machine's MAC before the file
		// name. /iso6/ makes Smee patch the ISO with its IPv6 syslog and Tink
		// gRPC endpoints instead of the IPv4 ones.
		if c.isV6 {
			isoURL: "http://\(c.tinkerbellHost):7080/iso6/hook.iso"
		}
		if !c.isV6 {
			isoURL: "http://\(c.tinkerbellHost):7080/iso/hook.iso"
		}
	}
}

_isoExtraActions: [
	{
		name:    "disable cloud-init networking"
		image:   values.actionImages.writefile
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
		image:   values.actionImages.writefile
		timeout: 90
		environment: {
			CONTENTS: _netplan
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

// Static addressing rendered from the Hardware CR. On IPv6 `accept-ra: false`
// keeps the RA-advertised default route from competing with the static one; the
// derived DHCPv6 address the machine used to netboot is deliberately not
// carried over, because Smee documents derived addresses as boot-only.
_netplan: [
	if c.isV6 {"""
		network:
		  version: 2
		  renderer: networkd
		  ethernets:
		    id0:
		      match:
		        macaddress: {{ (index .Hardware.Interfaces 0).DHCP.MAC }}
		      dhcp4: false
		      dhcp6: false
		      accept-ra: false
		      addresses:
		        - {{ (index .Hardware.Interfaces 0).DHCP.IP.Address }}/\(c.nodePrefix)
		      nameservers:
		        addresses: [{{ (index .Hardware.Interfaces 0).DHCP.NameServers | join \",\"}}]
		      routes:
		        - to: "::/0"
		          via: {{ (index .Hardware.Interfaces 0).DHCP.IP.Gateway }}
		      optional: true

		"""},
	"""
		network:
		  version: 2
		  renderer: networkd
		  ethernets:
		    id0:
		      match:
		        macaddress: {{ (index .Hardware.Interfaces 0).DHCP.MAC }}
		      addresses:
		        - {{ (index .Hardware.Interfaces 0).DHCP.IP.Address }}/\(c.nodePrefix)
		      nameservers:
		        addresses: [{{ (index .Hardware.Interfaces 0).DHCP.NameServers | join \",\"}}]
		      routes:
		        - to: default
		          via: {{ (index .Hardware.Interfaces 0).DHCP.IP.Gateway }}
		      optional: true

		""",
][0]

// Empty for IPv4 netboot (cloud-init's DHCP default is sufficient), two extra
// writefile actions otherwise. IPv6 netboot needs them because cloud-init's
// fallback config only brings up DHCPv4.
_extraActions: [...]
_extraActions: [
	if _mode == "isoboot" || c.isV6 for a in _isoExtraActions {a},
]
