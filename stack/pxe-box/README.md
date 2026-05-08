# pxe-box

Builds a tiny "iPXE on disk" Vagrant box — the cross-arch / cross-provider
replacement for [`jtyr/pxe`][jtyr]. Each artifact is a ~64 MB virtual disk
whose only contents are an EFI system partition with iPXE as the default
loader (`\EFI\BOOT\BOOTX64.EFI` on amd64, `\EFI\BOOT\BOOTAA64.EFI` on arm64).
At boot the firmware launches iPXE, which DHCPs and chains to whatever
PXE/HTTP infrastructure is on the network — for the playground that's Smee.

Targets produced:

| provider   | amd64 | arm64 |
| ---------- | :---: | :---: |
| virtualbox |  ✅   |  ✅   |
| libvirt    |  ✅   |  ✅   |

Plus a top-level Vagrant Cloud-style `metadata.json` that resolves a single
box name (default `tinkerbell/pxe`) to the right artifact based on the host's
provider and architecture.

## Build

Host requirements (macOS): `brew install dosfstools mtools qemu coreutils gptfdisk`.
Linux distros generally ship these. No VirtualBox installation is required
on the build host — `qemu-img` produces the VDI directly, so a single
`linux/amd64` runner can build every `(provider x architecture)` combination.

```sh
make                                   # build everything into ./out
make ARCHES=arm64 vbox                 # subset
make BASE_URL=https://example.com/pxe metadata
```

Output:

```
out/
├── disk-amd64.img
├── disk-arm64.img
├── pxe-amd64-virtualbox.box
├── pxe-arm64-virtualbox.box
├── pxe-amd64-libvirt.box
├── pxe-arm64-libvirt.box
└── metadata.json
```

## Local-only use (no server)

You don't need to host the boxes anywhere. Build, then `vagrant box add` the
single artifact you need by direct file path. The box name is whatever you
pick at `add` time:

```sh
# 1. Build (only the artifact you need is fine).
make ARCHES=arm64 vbox          # -> out/pxe-arm64-virtualbox.box

# 2. Register it locally under a name of your choice.
vagrant box add --provider virtualbox --architecture arm64 \
    --name tinkerbell/pxe out/pxe-arm64-virtualbox.box

# 3. Reference it like any other box. No box_url, no metadata.json.
#    In a Vagrantfile:
#      config.vm.box = "tinkerbell/pxe"
```

Repeat step 2 for additional `(provider, architecture)` combos as needed —
Vagrant stores them under the same name and picks the right one based on the
provider you use and the host's architecture.

To remove or refresh a locally added box:

```sh
vagrant box list
vagrant box remove tinkerbell/pxe --provider virtualbox --architecture arm64
```

## Publish (optional, multi-user setup)

If you want one Vagrantfile to resolve to the right artifact for any
contributor automatically, upload the four `.box` files and `metadata.json`
to a static host (S3, GCS, GitHub Releases, ghcr.io OCI artifacts, anywhere
with HTTP). The `url` fields in `metadata.json` must resolve to the box
files.

In a `Vagrantfile`:

```ruby
config.vm.box = "tinkerbell/pxe"
config.vm.box_url = "https://your-host/path/metadata.json"
```

Vagrant picks the right `(provider, architecture)` automatically.

## Caveats

- The OVF template in `templates/box.ovf.tmpl` targets VirtualBox 7.1+.
  If a future VBox release rejects it, regenerate by exporting a working
  VM (`VBoxManage export <vm> -o ref.ovf`) and copying the structure back.
- `qemu-img convert -O vdi` produces a sparse VDI from the 64 MB raw; the
  resulting `.box` is a few MB compressed.
- The arm64 box requires a host able to run arm64 VirtualBox VMs (Apple
  Silicon with VirtualBox ≥ 7.1).

[jtyr]: https://app.vagrantup.com/jtyr/boxes/pxe
