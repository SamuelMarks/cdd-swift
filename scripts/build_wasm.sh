#!/bin/bash
set -e
mkdir -p bin
echo "Building WASM binary for Swift..."
swift build --swift-sdk 6.0.3-RELEASE-wasm32-unknown-wasi -c release

if [ -f .build/wasm32-unknown-wasi/release/cdd-swift.wasm ]; then
    cp .build/wasm32-unknown-wasi/release/cdd-swift.wasm bin/cdd-swift.wasm
elif [ -f .build/wasm32-unknown-wasi/release/cdd-swift ]; then
    cp .build/wasm32-unknown-wasi/release/cdd-swift bin/cdd-swift.wasm
elif [ -f .build/wasm32-unknown-wasi/release/cdd-swift-cli.wasm ]; then
    cp .build/wasm32-unknown-wasi/release/cdd-swift-cli.wasm bin/cdd-swift.wasm
elif [ -f .build/wasm32-unknown-wasi/release/cdd-swift-cli ]; then
    cp .build/wasm32-unknown-wasi/release/cdd-swift-cli bin/cdd-swift.wasm
elif [ -f .build/release/cdd-swift.wasm ]; then
    cp .build/release/cdd-swift.wasm bin/cdd-swift.wasm
elif [ -f .build/release/cdd-swift-cli.wasm ]; then
    cp .build/release/cdd-swift-cli.wasm bin/cdd-swift.wasm
else
    echo "Could not find the built WASM binary."
    exit 1
fi
