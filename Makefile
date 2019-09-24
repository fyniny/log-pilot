# Copyright 2019 The Caicloud Authors.
#
# The old school Makefile, following are required targets. The Makefile is written
# to allow building multiple binaries. You are free to add more targets or change
# existing implementations, as long as the semantics are preserved.
#
#   make              - default to 'build' target
#   make lint         - code analysis
#   make test         - run unit test (or plus integration test)
#   make build        - alias to build-local target
#   make build-local  - build local binary targets
#   make build-linux  - build linux binary targets
#   make container    - build containers
#   $ docker login registry -u username -p xxxxx
#   make push         - push containers
#   make clean        - clean up targets
#
# Not included but recommended targets:
#   make e2e-test
#
# The makefile is also responsible to populate project version information.
#

#
# Tweak the variables based on your project.
#

# This repo's root import path (under GOPATH).
ROOT := github.com/caicloud/log-pilot

# Target binaries. You can build multiple binaries for a single project.
TARGETS ?= log-pilot filebeat-keeper

# Container image prefix and suffix added to targets.
# The final built images are:
#   $[REGISTRY]/$[IMAGE_PREFIX]$[TARGET]$[IMAGE_SUFFIX]:$[VERSION]
# $[REGISTRY] is an item from $[REGISTRIES], $[TARGET] is an item from $[TARGETS].
IMAGE_PREFIX ?= $(strip )
IMAGE_SUFFIX ?= $(strip )

# Container registries.
REGISTRY ?= cargo.dev.caicloud.xyz/release

# Container registry for base images.
BASE_REGISTRY ?= cargo.caicloud.xyz/library

#
# These variables should not need tweaking.
#

# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash

# Project main package location (can be multiple ones).
CMD_DIR := ./cmd

# Project output directory.
OUTPUT_DIR := ./bin

# Build direcotory.
BUILD_DIR := ./build

# Current version of the project.
VERSION ?= $(shell git describe --tags --always --dirty)

# Available cpus for compiling, please refer to https://github.com/caicloud/engineering/issues/8186#issuecomment-518656946 for more information.
CPUS ?= $(shell sh hack/read_cpus_available.sh)

# Track code version with Docker Label.
DOCKER_LABELS ?= git-describe="$(shell date -u +v%Y%m%d)-$(shell git describe --tags --always --dirty)"

# Golang standard bin directory.
GOPATH ?= $(shell go env GOPATH)
BIN_DIR := $(GOPATH)/bin
GOLANGCI_LINT := $(BIN_DIR)/golangci-lint

#
# Define all targets. At least the following commands are required:
#

# All targets.
.PHONY: lint test build container push

build: build-local

# more info about `GOGC` env: https://github.com/golangci/golangci-lint#memory-usage-of-golangci-lint
lint: $(GOLANGCI_LINT)
	@GOGC=5 $(GOLANGCI_LINT) run

$(GOLANGCI_LINT):
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(BIN_DIR) v1.16.0

test:
	@go test -p $(CPUS) $$(go list ./... | grep -v /vendor | grep -v /test) -coverprofile=coverage.out
	@go tool cover -func coverage.out | tail -n 1 | awk '{ print "Total coverage: " $$3 }'

build-local:
	  go build -i -v -o $(OUTPUT_DIR)/$${target} -p $(CPUS)                            \
	  $(CMD_DIR)/$${target};                                                           \

build-linux:
	@docker run --rm                                                                   \
	  -v $(PWD):/go/src/$(ROOT)                                                        \
	  -w /go/src/$(ROOT)                                                               \
	  -e GOOS=linux                                                                    \
	  -e GOARCH=amd64                                                                  \
	  -e GOPATH=/go                                                                    \
	  $(BASE_REGISTRY)/golang:1.12.9-stretch                                           \
	    /bin/bash -c 'for target in $(TARGETS); do                                     \
	       go build -i -v -o $(OUTPUT_DIR)/$${target} -p $(CPUS)                       \
	         $(CMD_DIR)/$${target};                                                        \
	     done'

container: build-linux
	@docker build -t $(REGISTRY)/log-pilot:$(VERSION) -f $(BUILD_DIR)/log-pilot/Dockerfile .
	@docker build -t $(REGISTRY)/filebeat:$(VERSION) -f $(BUILD_DIR)/filebeat/Dockerfile .

push: container
	@docker push $(REGISTRY)/log-pilot:$(VERSION)
	@docker push $(REGISTRY)/filebeat:$(VERSION)

.PHONY: clean
clean:
	@-rm -vrf ${OUTPUT_DIR}
