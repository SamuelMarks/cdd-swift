# Usage

## Core Usage
The `cdd-swift` CLI generates Swift code from an OpenAPI specification, and OpenAPI specifications from Swift source code.

### Getting Help
```bash
cdd-swift --help
```

### OpenAPI to Swift (Bidirectional)
Generate a full Swift REST Client Library:
```bash
cdd-swift from_openapi to_sdk -i openapi.json -o ./MyClientSDK
```

Generate a typed CLI interface for calling an API:
```bash
cdd-swift from_openapi to_sdk_cli -i openapi.json -o ./MyCLI
```

Generate a Vapor Web Server Stub from an OpenAPI Definition:
```bash
cdd-swift from_openapi to_server -i openapi.json -o ./MyServer
```

All `from_openapi` subcommands also support `--input-dir` to pass a directory of JSON specifications to compile multiple files at once.

### Swift to OpenAPI
Generate an OpenAPI specification from existing Swift models:
```bash
cdd-swift to_openapi -f Sources/MyModels.swift -o openapi.json
```

### Generating Documentation
```bash
cdd-swift to_docs_json --no-imports --no-wrapping -i spec.json -o docs.json
```

### Run as JSON-RPC Server
Expose the CLI capabilities over an HTTP JSON RPC Interface:
```bash
cdd-swift serve_json_rpc --listen 0.0.0.0 --port 8082
```
