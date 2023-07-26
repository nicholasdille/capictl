M                   = $(shell printf "\033[34;1m▶\033[0m")
SHELL              := /bin/bash
GIT_BRANCH         ?= $(shell git branch --show-current)
GIT_COMMIT_SHA      = $(shell git rev-parse HEAD)

OWNER              ?= nicholasdille
PROJECT            ?= clusterctlctl

SUPPORTED_ARCH     := x86_64 aarch64
SUPPORTED_ALT_ARCH := amd64 arm64
ARCH               ?= $(shell uname -m)
ifeq ($(ARCH),x86_64)
ALT_ARCH           := amd64
endif
ifeq ($(ARCH),aarch64)
ALT_ARCH           := arm64
endif
ifndef ALT_ARCH
$(error ERROR: Unable to determine alternative name for architecture ($(ARCH)))
endif

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

GO_SOURCES = $(shell find . -type f -name \*.go)
GO_VERSION = $(shell git describe --tags --abbrev=0 | tr -d v)
GO         = go

.PHONY:
info:
	@echo "GO_VERSION: $(GO_VERSION)"

coverage.out.tmp: $(GO_SOURCES)
	@$(GO) test -v -buildvcs -coverprofile ./coverage.out.tmp ./...

coverage.out: coverage.out.tmp
	@cat ./coverage.out.tmp | grep -v '.pb.go' | grep -v 'mock_' > ./coverage.out

.PHONY:
test: $(GO_SOURCES) ; $(info $(M) Running unit tests...)
	@$(GO) test ./...

.PHONY:
cover: coverage.out
	@echo ""
	@$(GO) tool cover -func ./coverage.out

snapshot: make/go.mk $(GO_SOURCES) ; $(info $(M) Building snapshot of docker-setup with version $(GO_VERSION)...)
	@docker buildx bake binary --set binary.args.version=$(GO_VERSION)-dev

release: ; $(info $(M) Building docker-setup...)
	@helper/usr/local/bin/goreleaser release --clean --snapshot --skip-sbom --skip-publish
	@cp dist/docker-setup_$$(go env GOOS)_$$(go env GOARCH)/docker-setup docker-setup

.PHONY:
deps:
	@$(GO) get -u ./...
	@$(GO) mod tidy

.PHONY:
clean:
	@rm -rf dist
	@rm docker-setup
	@rm coverage.out

,PHONY:
tidy:
	@$(GO) fmt ./...
	@$(GO) mod tidy -v

.PHONY:
audit:
	@$(GO) mod verify
	@$(GO) vet ./...
	@$(GO) run honnef.co/go/tools/cmd/staticcheck@latest -checks=all,-ST1000,-U1000 ./...
	@$(GO) run golang.org/x/vuln/cmd/govulncheck@latest ./...
	@$(GO) test -buildvcs -vet=off ./...

