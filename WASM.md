# cdd-swift WASM Support

The `cdd-swift` CLI tool requires an open-source Swift toolchain (such as Homebrew Swift on macOS or the official Swift release on Linux) and a matching WebAssembly Swift SDK (`_wasm` or `wasm32-unknown-wasi`) to cross-compile to WebAssembly.

## Prerequisites

### 1. Install Open-Source Swift (macOS)

Apple's bundled Xcode Swift toolchain does not support WebAssembly cross-compilation. On macOS, install the open-source Swift toolchain via Homebrew:

```bash
brew install swift
```

> **Note (macOS Gatekeeper / Code Signing):** If `/opt/homebrew/opt/swift/bin/swift` is killed (`Killed: 9` / exit code 137) due to invalidated Mach-O signatures in the Homebrew bottle, re-sign the toolchain's modified binaries and dynamic libraries:
> ```bash
> find /opt/homebrew/Cellar/swift -type f | while read -r f; do
>   if codesign -vvv "$f" 2>&1 | grep -q "invalid signature"; then
>     codesign -f -s - "$f"
>   fi
> done
> ```

### 2. Install the WebAssembly Swift SDK

Install the WebAssembly Swift SDK matching your installed Swift version (check with `/opt/homebrew/opt/swift/bin/swift --version` or `swift --version`):

**For Swift 6.4.0 (official Swift Wasm SDK):**
```bash
/opt/homebrew/opt/swift/bin/swift sdk install \
  https://download.swift.org/swift-6.4.0-release/wasm-sdk/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d
```

**For Swift 6.0.3 (SwiftWasm release):**
```bash
swift sdk install \
  https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip \
  --checksum 31d3585b06dd92de390bacc18527801480163188cd7473f492956b5e213a8618
```

Verify the SDK is registered:
```bash
/opt/homebrew/opt/swift/bin/swift sdk list
```

## Building for WASM

Run the provided Make task:
```bash
make build_wasm
```

This runs `scripts/build_wasm.py`, which invokes `swift build --swift-sdk <wasm-sdk> -c release` and copies the compiled binary to `bin/cdd-swift.wasm`.
