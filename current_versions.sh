#!/usr/bin/env bash

# This file gets used from generate-envrc.sh but it is also used standalone by
# automation that needs to get the version of the programs currently supported
# in sandbox

export OSIE_DOWNLOAD_LINK=https://tinkerbell-oss.s3.amazonaws.com/osie-uploads/osie-v0-n=366,c=1aec189,b=master.tar.gz
export TINKERBELL_TINK_SERVER_IMAGE=quay.io/tinkerbell/tink:sha-0e8e5733
export TINKERBELL_TINK_CLI_IMAGE=quay.io/tinkerbell/tink-cli:sha-0e8e5733
export TINKERBELL_TINK_BOOTS_IMAGE=quay.io/tinkerbell/boots:sha-9625559b
export TINKERBELL_TINK_HEGEL_IMAGE=quay.io/tinkerbell/hegel:sha-c17b512f
export TINKERBELL_TINK_WORKER_IMAGE=quay.io/tinkerbell/tink-worker:sha-0e8e5733
