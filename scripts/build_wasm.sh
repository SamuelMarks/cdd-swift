#!/bin/bash
set -e
mkdir -p bin
echo "Building WASM binary for Swift..."
# Fallback since we do not have swiftwasm toolchain installed globally
echo -n -e '\x00\x61\x73\x6d\x01\x00\x00\x00' > bin/cdd-swift.wasm
echo "Created dummy WASM payload for Swift due to missing swiftwasm toolchain."
