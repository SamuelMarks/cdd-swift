.PHONY: all help install_base install_deps build_docs build test run build_wasm

ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

ifeq (build,$(firstword $(MAKECMDGOALS)))
  BUILD_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(BUILD_ARGS),)
    BIN_DIR := $(firstword $(BUILD_ARGS))
    $(eval $(BIN_DIR):;@:)
  endif
endif

ifeq (build_docs,$(firstword $(MAKECMDGOALS)))
  DOCS_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(DOCS_ARGS),)
    DOCS_DIR := $(firstword $(DOCS_ARGS))
    $(eval $(DOCS_DIR):;@:)
  endif
endif

BIN_DIR ?= .build/release
DOCS_DIR ?= docs

all: help

help:
	@echo "Available tasks:"
	@echo "  install_base : install language runtime (Swift)"
	@echo "  install_deps : install local dependencies (Swift package)"
	@echo "  build_docs [dir] : build the API docs and put them in docs/ (or [dir])"
	@echo "  build [dir]  : build the CLI binary into [dir]"
	@echo "  test         : run tests locally"
	@echo "  run [args]   : run the CLI (e.g., make run --version)"
	@echo "  build_wasm   : build for WASM"

install_base:
	@echo "Please install Swift from swift.org"

install_deps:
	swift package resolve

build_docs:
	mkdir -p $(DOCS_DIR)
	swift package generate-documentation --target cdd-swift-cli --output-path $(DOCS_DIR)

build:
	swift build -c release
	@if [ "$(BIN_DIR)" != ".build/release" ]; then \
		mkdir -p $(BIN_DIR) ; \
		cp .build/release/cdd-swift $(BIN_DIR)/ ; \
	fi

test:
	swift test

run: build
	.build/release/cdd-swift $(RUN_ARGS)

build_wasm:
	swift build --triple wasm32-unknown-wasi -c release

build_docker:
	docker build -t cdd-swift:debian -f debian.Dockerfile .
	docker build -t cdd-swift:alpine -f alpine.Dockerfile .

run_docker: build_docker
	docker run -d -p 8082:8082 --name cdd_swift_test cdd-swift:debian
	sleep 2
	curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc": "2.0", "method": "--version", "id": 1}' http://127.0.0.1:8082/
	docker stop cdd_swift_test
	docker rm cdd_swift_test
	docker rmi cdd-swift:debian cdd-swift:alpine

