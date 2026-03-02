# WebAssembly (WASM) Support

`cdd-swift` supports being compiled to WebAssembly. This allows for creating a unified CLI runnable anywhere, or for browser-based toolchains.

## Building for WASM

Ensure you have Swift WASM toolchain installed.

```bash
make build_wasm
```

This will produce a `.wasm` binary using `swift build --triple wasm32-unknown-wasi`.

## Integration

The resulting `.wasm` module can be run on platforms using Wasmtime or WASI.
