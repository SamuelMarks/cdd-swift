# cdd-swift WASM Support

The `cdd-swift` CLI and compiler library can be compiled to WebAssembly (`wasm32-unknown-wasi`) using an open-source Swift toolchain (such as Swiftly or Homebrew Swift on macOS / official Swift release on Linux) and a matching Swift WebAssembly SDK (`_wasm` or `wasm32-unknown-wasi`).

> **Note:** Xcode's bundled default toolchain on macOS does not support custom Swift SDKs. Ensure `PATH` points to an open-source Swift toolchain when building for WebAssembly.

## Installing the Swift WASM SDK

1. Install an open-source Swift 6.0+ toolchain:
   - **macOS:** `brew install swift` (or via `swiftly`)
   - **Linux:** Download from [swift.org/download](https://www.swift.org/download/) or install via `swiftly`.
2. Install the matching Swift WASM SDK for your `swift --version`:
   ```bash
   swift sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip --checksum <checksum>
   ```
   Verify installation with:
   ```bash
   swift sdk list
   ```

## Building for WASM

Run the provided Make task:

```bash
make build_wasm
```

This executes `scripts/build_wasm.py`, which invokes `swift build --swift-sdk <wasm-sdk> -c release` and copies the compiled WebAssembly binary to `bin/cdd-swift.wasm`.

## Running the WASM Binary

Run `bin/cdd-swift.wasm` using any WASI-compatible WebAssembly runtime such as [`wasmtime`](https://wasmtime.dev/) or [`wasmer`](https://wasmer.io/):

```bash
# Display CLI help
wasmtime bin/cdd-swift.wasm -- --help

# Mount the current working directory and compile OpenAPI / Arazzo specs
wasmtime --dir=. bin/cdd-swift.wasm -- generate_openapi -o spec.json
wasmtime --dir=. bin/cdd-swift.wasm -- from_openapi to_sdk -i spec.json -o ./sdk --tests
wasmtime --dir=. bin/cdd-swift.wasm -- to_openapi -i ./sdk/Sources/GeneratedSDK/models.swift -o roundtrip.json
wasmtime --dir=. bin/cdd-swift.wasm -- generate_arazzo -o workflow.arazzo.json
wasmtime --dir=. bin/cdd-swift.wasm -- from_arazzo to_sdk -i workflow.arazzo.json -o ./workflows
wasmtime --dir=. bin/cdd-swift.wasm -- to_docs_json -i spec.json -o docs.json
```

All file system operations in `cdd-swift` use `WASIFileHelpers` (`Sources/cdd-swift-cli/WASIFileHelpers.swift`), providing portable POSIX file and directory manipulation across WASI sandboxes, browser runtimes, Linux, macOS, and Windows.
