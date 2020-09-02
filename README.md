This repository is a quick way to get the Tinkerbell stack up and running.

Currently it supports:

1. Vagrant with vlib and VirtualBox
2. Terraform on Packet

Tinkerbell is made of different components: osie, boots, tink-server,
tink-worker and so on. Currently they are under heavy development and we are
working around the release process for all the components.

We need a way to serve a version of Tinkerbell that you can use and we know what
is running the hood. Sandbox runs a pinned version for all the components via
commit sha. In this way as a user you won't be effected (ideally) from new code
that will may change a bit how Tinkerbell works.

We are keeping the number of bc break as low as possible but in the current
state they are expected.
