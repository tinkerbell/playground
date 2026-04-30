// Workflow templateOverride. Authored as a structured CUE value, then marshaled
// to YAML by resources.cue and embedded as a string in TMT.spec.template.spec.templateOverride.
//
// CAPT reads templateOverride as text, template-expands `{{ ... }}` Go template
// expressions against per-machine Hardware data, then parses the result as YAML
// to produce the Workflow CR.
package capi

import "list"

_workflow: {
	version:        "0.1"
	name:           "playground-template"
	global_timeout: 6000
	tasks: [{
		name:    "playground-template"
		worker:  "{{.device_1}}"
		volumes: ["/dev:/dev"]
		actions: list.Concat([_commonActionsHead, _extraActions, _commonActionsTail])
	}]
}

_commonActionsHead: [
	{
		name:    "stream image"
		image:   "quay.io/tinkerbell/actions/oci2disk"
		timeout: 1200
		environment: {
			IMG_URL:    c.imgURL
			DEST_DISK:  "{{ index .Hardware.Disks 0 }}"
			COMPRESSED: true
		}
	},
	{
		name:    "add tink cloud-init config"
		image:   "quay.io/tinkerbell/actions/writefile"
		timeout: 90
		environment: {
			DEST_DISK: "{{ formatPartition ( index .Hardware.Disks 0 ) 3 }}"
			FS_TYPE:   "ext4"
			DEST_PATH: "/etc/cloud/cloud.cfg.d/10_tinkerbell.cfg"
			UID:       0
			GID:       0
			MODE:      "0600"
			DIRMODE:   "0700"
			CONTENTS: """
				datasource:
				  Ec2:
				    metadata_urls: [\"\(c.metadataURL)\"]
				    strict_id: false
				system_info:
				  default_user:
				    name: tink
				    groups: [wheel, adm]
				    sudo: [\"ALL=(ALL) NOPASSWD:ALL\"]
				    shell: /bin/bash
				manage_etc_hosts: localhost
				warnings:
				  dsid_missing_source: off

				"""
		}
	},
]

_commonActionsTail: [
	{
		name:    "add tink cloud-init ds-config"
		image:   "quay.io/tinkerbell/actions/writefile"
		timeout: 90
		environment: {
			DEST_DISK: "{{ formatPartition ( index .Hardware.Disks 0 ) 3 }}"
			FS_TYPE:   "ext4"
			DEST_PATH: "/etc/cloud/ds-identify.cfg"
			UID:       0
			GID:       0
			MODE:      "0600"
			DIRMODE:   "0700"
			CONTENTS:  "datasource: Ec2\n"
		}
	},
	{
		name:    "kexec image"
		image:   "ghcr.io/jacobweinstock/waitdaemon:latest"
		timeout: 90
		pid:     "host"
		environment: {
			BLOCK_DEVICE:  "{{ formatPartition ( index .Hardware.Disks 0 ) 1 }}"
			FS_TYPE:       "vfat"
			IMAGE:         "quay.io/tinkerbell/actions/kexec"
			GRUBCFG_PATH:  "/grub/grub.cfg"
			WAIT_SECONDS: 10
		}
		volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
	},
]
