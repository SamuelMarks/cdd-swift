@echo off
if not exist "bin" mkdir bin
echo Building WASM binary for Swift...
swift build --swift-sdk 6.0.3-RELEASE-wasm32-unknown-wasi -c release

if exist .build\wasm32-unknown-wasielease\cdd-swift.wasm (
    copy .build\wasm32-unknown-wasielease\cdd-swift.wasm bin\cdd-swift.wasm
) else if exist .build\wasm32-unknown-wasielease\cdd-swift (
    copy .build\wasm32-unknown-wasielease\cdd-swift bin\cdd-swift.wasm
) else (
    echo Could not find the built WASM binary.
    exit /b 1
)
