This directory contains a provisioning mechanism for the Vagrant boxes we ship
as part of Sandbox.

In order to self contain and distribute the required dependencies for Tinkerbell
and Sandbox without having to download all of them at runtime we decided to use
[Packer.io](https://packer.io) to build boxes that you can use when provisioning
Tinkerbell on Vagrant.

Currently the generated boxes are available via [Vagrant
Cloud](https://app.vagrantup.com/tinkerbelloss).

---

## Build

To build the boxes checkout the right directory and run

```terminal
$ packer build --parallel-builds=1 ./template.json
```

`-parallel-builds=1` is required because the template builds images for multiple
providers using the [Vagrant
builder](https://www.packer.io/docs/builders/vagrant) and I didn't manage to get
it to work in parallel yet.

## Deploy to Vagrant Cloud

I didn't find a way to make the Vagrant Cloud post processor to work. But I use
the vagrant cli `vagrant cloud publish` command.
