#!/usr/bin/env bash

source ./current_versions.sh

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/hegel \
	-image docker://quay.io/tinkerbell/hegel:sha-c17b512f \
	-program hegel

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/boots \
	-image docker://quay.io/tinkerbell/boots:sha-e81a291c \
	-program boots

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink-worker \
	-image docker://quay.io/tinkerbell/tink-worker:sha-0e8e5733 \
	-program tink-worker

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink-server \
	-image docker://quay.io/tinkerbell/tink:sha-0e8e5733 \
	-program tink-server

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink \
	-image docker://quay.io/tinkerbell/tink-cli:sha-0e8e5733 \
	-program tink
