#!/usr/bin/env bash

source ./current_versions.sh

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/hegel \
	-image docker://${TINKERBELL_TINK_HEGEL_IMAGE} \
	-program hegel

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/boots \
	-image docker://${TINKERBELL_TINK_BOOTS_IMAGE} \
	-program boots

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink-worker \
	-image docker://${TINKERBELL_TINK_WORKER_IMAGE} \
	-program tink-worker

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink-server \
	-image docker://${TINKERBELL_TINK_SERVER_IMAGE} \
	-program tink-server

go run cmd/getbinariesfromquay/main.go \
	-binary-to-copy /usr/bin/tink \
	-image docker://${TINKERBELL_TINK_CLI_IMAGE} \
	-program tink
