.PHONY: install_base install_deps build_docs build build_wasm build_docker run_docker test run help all

DOCS_DIR ?= docs

default: help

install_base:
	@echo "Installing base dependencies..."
	@echo "Install Swift from swift.org or via package manager."

install_deps:
	swift package resolve

build_docs:
	@echo "Building docs to $(DOCS_DIR)..."
	swift package --allow-writing-to-directory $(DOCS_DIR) generate-documentation --target CDDSwift --output-path $(DOCS_DIR)

build:
	@echo "Building CLI binary..."
	swift build -c release

build_wasm:
	@echo "Building WASM binary..."
	swift build --triple wasm32-unknown-wasi -c release

build_docker:
	docker build -t cdd-swift -f alpine.Dockerfile .
	docker build -t cdd-swift-debian -f debian.Dockerfile .

run_docker: build_docker
	docker run --rm -p 8082:8082 cdd-swift

test:
	@echo "Running tests..."
	swift test

run: build
	@echo "Running CLI..."
	.build/release/cdd-swift $(filter-out $@,$(MAKECMDGOALS))

help:
	@echo "Available tasks:"
	@echo "  install_base  : install language runtime"
	@echo "  install_deps  : install dependencies"
	@echo "  build_docs    : build the API docs (override with DOCS_DIR=docs)"
	@echo "  build         : build the CLI binary"
	@echo "  build_wasm    : build the WASM binary"
	@echo "  build_docker  : build docker images"
	@echo "  run_docker    : run docker image"
	@echo "  test          : run tests locally"
	@echo "  run           : build and run the CLI (e.g., make run --version)"
	@echo "  help / all    : show this help text"

all: help

%:
	@:
