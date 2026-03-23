# cdd-swift WASM Support

The `cdd-swift` CLI tool requires the `swiftwasm` toolchain to be cross-compiled natively.



## Building for WASM

Run the provided Make task:
```bash
make build_wasm
```

If installed, this will invoke `swift build --triple wasm32-unknown-wasi` and copy the payload into `bin/cdd-swift.wasm`.
