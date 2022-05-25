
# BEGIN: lint-install ../sandbox
# http://github.com/tinkerbell/lint-install

HELM_VERSION ?= v3.9.0
GOLINT_VERSION ?= v1.42.0
SHELLCHECK_VERSION ?= v0.7.2

OS := $(shell uname)
ARCH := $(shell uname -m)
LOWERCASE_OS  = $(shell echo $(OS) | tr '[:upper:]' '[:lower:]')

HELM_ARCH := $(ARCH)
ifeq ($(ARCH),x86_64)
	HELM_ARCH=amd64
endif

LINT_ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# shellcheck and hadolint lack arm64 native binaries: rely on x86-64 emulation
ifeq ($(OS),Darwin)
	ifeq ($(ARCH),arm64)
		ARCH=x86_64
	endif
endif

GOLINT_CONFIG:=$(LINT_ROOT)/.golangci.yml

.PHONY: helm
helm: out/helm/$(LOWERCASE_OS)-$(HELM_ARCH)
	./out/helm/${LOWERCASE_OS}-${HELM_ARCH}/helm package helm-charts/tinkerbell 

out/helm/$(LOWERCASE_OS)-$(HELM_ARCH):
	mkdir -p out/helm
	echo $(HELM_ARCH)
	curl -sSfL https://get.helm.sh/helm-$(HELM_VERSION)-$(LOWERCASE_OS)-$(HELM_ARCH).tar.gz | tar -C out/helm -xzvf -

lint: out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(ARCH)/shellcheck out/linters/golangci-lint-$(GOLINT_VERSION)-$(ARCH)
	find . -name go.mod | xargs -n1 dirname | xargs -n1 -I{} sh -c "cd {} && $(LINT_ROOT)/out/linters/golangci-lint-$(GOLINT_VERSION)-$(ARCH) run -c $(GOLINT_CONFIG)"
	out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(ARCH)/shellcheck $(shell find . -name "*.sh")

out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(ARCH)/shellcheck:
	mkdir -p out/linters
	curl -sSfL https://github.com/koalaman/shellcheck/releases/download/$(SHELLCHECK_VERSION)/shellcheck-$(SHELLCHECK_VERSION).$(LOWERCASE_OS).$(ARCH).tar.xz | tar -C out/linters -xJf -
	mv out/linters/shellcheck-$(SHELLCHECK_VERSION) out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(ARCH)

out/linters/golangci-lint-$(GOLINT_VERSION)-$(ARCH):
	mkdir -p out/linters
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b out/linters $(GOLINT_VERSION)
	mv out/linters/golangci-lint out/linters/golangci-lint-$(GOLINT_VERSION)-$(ARCH)

# END: lint-install ../sandbox

.PHONY: clean
clean: ## Clean up resources created by make targets
	rm -rf ./out
	rm tinkerbell-*.tgz
