This repository is a quick way to get the Tinkerbell stack up and running.

Currently it supports:

1. Vagrant with libvirt and VirtualBox
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

## Binary release

As part of a new release for sandbox we want to push binaries to GitHub Release
in this way the community will be able to use them if needed.

We build Docker images across many architectures, each of them in its own
repository: boots, hegel, tink and so on.

Sandbox is just a collection of those services and we follow the same pattern
for getting binaries as well.

There is a go program available in `./cmd/getbinariesfromquay/main.go`. You can
run it with `go run` or build it with `go build`:

```terminal
$ go run cmd/getbinariesfromquay/main.go -h
  -binary-to-copy string
        The location of the binary you want to copy from inside the image. (default "/usr/bin/hegel")
  -image string
        The image you want to download binaries from. It has to be a multi stage image. (default "docker://quay.io/tinkerbell/hegel")
  -out string
        The directory that will be used to store the release binaries (default "./out")
  -program string
        The name of the program you are extracing binaries for. (eg tink-worker, hegel, tink-server, tink, boots) (default "hegel")
```

By default it uses the image running on Quay for Hegel and it gets the binary
`/usr/bin/hegel` from there. The directory `./out` is used to store images and
binaries inside `./out/releases`.

To get the binaries for example for boots you can run:

```terminal
$ go run cmd/getbinariesfromquay/main.go \
    -binary-to-copy /usr/bin/boots \
    -image docker://quay.io/tinkerbell/boots:sha-9625559b \
    -program boots
```

You will find them in `./out/release`
