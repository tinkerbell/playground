# Build minimal "PXE" Vagrant boxes (iPXE-on-disk) for
# {virtualbox, libvirt} x {amd64, arm64}, plus a top-level Vagrant Cloud-style
# metadata.json that maps a single box name to all four artifacts.
#
# Usage:
#   make                # build everything into ./out
#   make disks          # just the raw FAT32 + iPXE disk images
#   make vbox libvirt   # provider-specific .box files
#   make metadata       # top-level metadata.json
#   make clean
#
# Required tools (macOS: brew install dosfstools mtools qemu coreutils gptfdisk):
#   curl, dd, sgdisk, mkfs.vfat, mtools (mformat, mmd, mcopy), qemu-img, tar, uuidgen.
# All steps are host-arch agnostic; a single linux/amd64 runner can build
# every (provider x architecture) combination.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

NAME     ?= tinkerbell/pxe
VERSION  ?= 0.1.0
BASE_URL ?= https://example.invalid/pxe
ARCHES   ?= amd64 arm64
OUT      := out

DISKS   := $(addprefix $(OUT)/disk-,$(addsuffix .img,$(ARCHES)))
VBOXES  := $(addprefix $(OUT)/pxe-,$(addsuffix -virtualbox.box,$(ARCHES)))
LVBOXES := $(addprefix $(OUT)/pxe-,$(addsuffix -libvirt.box,$(ARCHES)))

.PHONY: all clean disks vbox libvirt metadata
all: vbox libvirt metadata

clean:
	rm -rf $(OUT)

disks: $(DISKS)

$(OUT)/disk-%.img: scripts/build-disk.sh
	@mkdir -p $(OUT)
	scripts/build-disk.sh $* $@

vbox: $(VBOXES)

$(OUT)/pxe-%-virtualbox.box: $(OUT)/disk-%.img scripts/pack-virtualbox.sh templates/box.ovf.tmpl templates/Vagrantfile.vbox
	scripts/pack-virtualbox.sh $* $< $@

libvirt: $(LVBOXES)

$(OUT)/pxe-%-libvirt.box: $(OUT)/disk-%.img scripts/pack-libvirt.sh templates/Vagrantfile.libvirt
	scripts/pack-libvirt.sh $* $< $@

metadata: $(OUT)/metadata.json

$(OUT)/metadata.json: $(VBOXES) $(LVBOXES) scripts/make-metadata.sh
	BASE_URL=$(BASE_URL) scripts/make-metadata.sh $(NAME) $(VERSION) > $@
