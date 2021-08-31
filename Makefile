
# BEGIN: lint-install ../sandbox
# http://github.com/tinkerbell/lint-install

GOLINT_VERSION ?= v1.42.0

SHELLCHECK_VERSION ?= v0.7.2
LINT_OS := $(shell uname)
LINT_ARCH := $(shell uname -m)
LINT_ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# shellcheck and hadolint lack arm64 native binaries: rely on x86-64 emulation
ifeq ($(LINT_OS),Darwin)
	ifeq ($(LINT_ARCH),arm64)
		LINT_ARCH=x86_64
	endif
endif

LINT_LOWER_OS  = $(shell echo $(LINT_OS) | tr '[:upper:]' '[:lower:]')
GOLINT_CONFIG:=$(LINT_ROOT)/.golangci.yml

lint: out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(LINT_ARCH)/shellcheck out/linters/golangci-lint-$(GOLINT_VERSION)-$(LINT_ARCH)
	find . -name go.mod | xargs -n1 dirname | xargs -n1 -I{} sh -c "cd {} && $(LINT_ROOT)/out/linters/golangci-lint-$(GOLINT_VERSION)-$(LINT_ARCH) run -c $(GOLINT_CONFIG)"
	out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(LINT_ARCH)/shellcheck $(shell find . -name "*.sh")

out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(LINT_ARCH)/shellcheck:
	mkdir -p out/linters
	curl -sSfL https://github.com/koalaman/shellcheck/releases/download/$(SHELLCHECK_VERSION)/shellcheck-$(SHELLCHECK_VERSION).$(LINT_LOWER_OS).$(LINT_ARCH).tar.xz | tar -C out/linters -xJf -
	mv out/linters/shellcheck-$(SHELLCHECK_VERSION) out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(LINT_ARCH)

out/linters/golangci-lint-$(GOLINT_VERSION)-$(LINT_ARCH):
	mkdir -p out/linters
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b out/linters $(GOLINT_VERSION)
	mv out/linters/golangci-lint out/linters/golangci-lint-$(GOLINT_VERSION)-$(LINT_ARCH)

# END: lint-install ../sandbox
