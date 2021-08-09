# TODO

- [x] automate getting osie download and decompressed/extracted
  - create directories (`state/webroot/workflow` and `state/webroot/misc/osie/current`)
  - automate moving files around (workflow-helper scripts)
- [x] automate getting tink-worker uploaded to internal registry
  - on the provisioner machine need to enable pushing to [local registry](https://docs.docker.com/registry/insecure/), using one of the following:
    1. ~~enable insecure registry in `/etc/docker/daemon.json`~~
    2. ~~add crt to `/etc/docker/certs.d/192.168.50.4/ca.crt` && `sudo update-ca-certificates`~~
    3. use `skopeo` to copy images to the local registry
- [x] automate ca.pem (bundle.pem) making it to `state/webroot/workflow/ca.pem` (used for docker registry)
- [x] automate hardware, template, and workflow creation
- [x] update Vagrantfile with a machine to provision (vagrant up machine1)
- [x] wait for osie and ubuntu download and/or notify user that it's ready
- [x] after `vagrant up machine1` notify user how to show progress `tink workflow events`
- [x] after machine1 is complete notify user how login to the machine
- [ ] reboot action for machine1
- [x] build idempotency in for downloads and extractions
- [x] add idempotency to cert generation (`tls/generate.sh`)
- [x] download focal cloud img and convert to raw and place it in correct location (`state/webroot/focal.img`)
- [x] make virtualbox networking more stable
- [x] create a getting started document that will replace the existing on on tinkerbell.org
- [ ] create a contributor guide to explain how the new sandbox works
  - [ ] machine1 default creds: tink/tink
- [x] document on how to run docker-compose on its own `TINKERBELL_HOST_IP=192.168.65.3 TINKERBELL_CLIENT_IP=192.168.65.43 docker-compose up -d` or update `.env` file
  - [x] test in multipass - works great!
- [x] document prerequisites
  - [ ] docker-compose >= 1.29.2
  - [ ] storage > ?
- [x] make the "TINKERBELL_IP" configurable. `csr.json`, `ubuntu.json`
- [x] make client machine ip configurable. `hardware.json`
