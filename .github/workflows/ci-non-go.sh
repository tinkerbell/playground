#!/usr/bin/env nix-shell
#!nix-shell -i bash ../../shell.nix
# shellcheck shell=bash

set -eux

failed=0

if ! git ls-files '*.md' '*.yaml' '*.yml' | xargs prettier --list-different --write; then
	failed=1
fi

if ! git ls-files '*.json' | xargs -I '{}' sh -c 'jq --sort-keys . {} > {}.t && mv {}.t {}'; then
	failed=1
fi

if ! shfmt -f . | xargs shfmt -s -l -d; then
	failed=1
fi

if ! rufo vagrant/Vagrantfile; then
	failed=1
fi

if ! git diff | (! grep .); then
	failed=1
fi

exit "$failed"
