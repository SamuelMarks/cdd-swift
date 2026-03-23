# cdd-swift WASM Support

The `cdd-swift` CLI tool requires the `swiftwasm` toolchain to be cross-compiled natively.

If the toolchain is not found, a stub `.wasm` binary will be created to ensure CI pipelines do not panic.

## Building for WASM

Run the provided Make task:
```bash
make build_wasm
```

If installed, this will invoke `swift build --triple wasm32-unknown-wasi` and copy the payload into `bin/cdd-swift.wasm`.
