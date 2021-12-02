#!/bin/bash
set -euxo pipefail

TINKERBELL_HOST_IP="$1"

if [ -d /vagrant/compose ]; then
	cd /vagrant/compose
fi

# trust the tinkerbell CA.
docker-compose exec -T registry cat /certs/onprem/ca-crt.pem >/usr/local/share/ca-certificates/tinkerbell.crt
update-ca-certificates
systemctl restart docker

# login into the docker registry.
docker login "$TINKERBELL_HOST_IP" --username admin --password-stdin <<<'Admin1234'
if id -u vagrant >/dev/null 2>&1; then
	su vagrant -c "docker login \"$TINKERBELL_HOST_IP\" --username admin --password-stdin" <<<'Admin1234'
fi

# ensure everything is up after docker restart.
docker-compose up --detach
