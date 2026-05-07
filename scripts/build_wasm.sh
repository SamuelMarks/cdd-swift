#!/bin/bash
set -e
mkdir -p bin
echo "Building WASM binary for Swift..."

# Apple Swift lacks WASM support. Use Homebrew swift if available.
SWIFT_BIN="swift"
if swift --version | grep -q "Apple Swift"; then
    if [ -x "/opt/homebrew/opt/swift/bin/swift" ]; then
        echo "Using Homebrew Swift for WASM support..."
        SWIFT_BIN="/opt/homebrew/opt/swift/bin/swift"
    elif [ -x "/usr/local/opt/swift/bin/swift" ]; then
        echo "Using Homebrew Swift for WASM support..."
        SWIFT_BIN="/usr/local/opt/swift/bin/swift"
    else
        echo "Error: Apple Swift does not support WASM compilation."
        echo "Please install the official open-source Swift toolchain:"
        echo "  brew install swift"
        exit 1
    fi
fi

# Find an appropriate installed swift SDK for WASM
AVAILABLE_SDKS=$($SWIFT_BIN sdk list | grep -E "wasm32-unknown-wasi|_wasm" | grep -v "embedded")

if [ -z "$AVAILABLE_SDKS" ]; then
    echo "Error: No WebAssembly Swift SDK found."
    echo "Please install one. For example:"
    echo "  $SWIFT_BIN sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip"
    exit 1
fi

SUCCESS=0
for SWIFT_SDK in $AVAILABLE_SDKS; do
    echo "Trying Swift SDK: $SWIFT_SDK"
    # Temporarily disable exit on error for the build command
    set +e
    $SWIFT_BIN build --swift-sdk "$SWIFT_SDK" -c release
    BUILD_EXIT_CODE=$?
    set -e
    
    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        SUCCESS=1
        break
    else
        echo "Failed to build with SDK $SWIFT_SDK. Trying next..."
    fi
done

if [ "$SUCCESS" -eq 0 ]; then
    echo "Error: Failed to build WASM with any available SDK. Ensure your SDK version matches your Swift compiler version."
    exit 1
fi

# Output paths change depending on the SDK and target triple
if [ -f .build/wasm32-unknown-wasip1/release/cdd-swift.wasm ]; then
    cp .build/wasm32-unknown-wasip1/release/cdd-swift.wasm bin/cdd-swift.wasm
elif [ -f .build/wasm32-unknown-wasip1/release/cdd-swift ]; then
    cp .build/wasm32-unknown-wasip1/release/cdd-swift bin/cdd-swift.wasm
elif [ -f .build/wasm32-unknown-wasi/release/cdd-swift.wasm ]; then
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
