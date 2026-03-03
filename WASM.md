# WebAssembly (WASM) Support

`cdd-swift` supports compilation to WebAssembly using SwiftWasm. This enables the CLI to be executed within:
- Unified CDD web interfaces running natively in browsers.
- Universal CLI execution environments without requiring a local Swift or system toolchain.

## Building for WASM

Ensure you have SwiftWasm installed (or use the provided `make build_wasm` command which relies on a local or globally installed SwiftWasm compiler).

```bash
make build_wasm
```

The resulting `.wasm` binary can be found in `.build/wasm32-unknown-wasi/release/cdd-swift-cli`.

## Status
- **Possible**: ✅ Yes
- **Implemented**: ✅ Yes

The WASM build works flawlessly for all stateless conversions (`from_openapi`, `to_openapi`, etc.). File system access depends on the WASI host environment implementation.
