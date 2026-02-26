# CDDSwift (Contract-Driven Development Swift)

`CDDSwift` is a lightweight, zero-dependency, bidirectional code generator and parser for converting between **OpenAPI 3.2.0** Documents and **Swift** code. 

Whether you prefer to write Swift first and generate your OpenAPI spec, or write your OpenAPI spec first and generate your Swift networking layer, `CDDSwift` supports your workflow.

## Features
- 🔄 **Bidirectional Translation**: Parse Swift `Codable` structs into OpenAPI schemas, or generate Swift structs and async/await `URLSession` clients from an OpenAPI Document.
- 💯 **100% OpenAPI 3.2.0 Structural Compliance**: Supports the latest JSON Schema draft (2020-12) validation keywords, `$dynamicRef`, `unevaluatedProperties`, `prefixItems`, Callbacks, Webhooks, and OAuth2 expansions.
- 💉 **Safe Merging**: Inject generated code safely into existing hand-written Swift files using marker comments, preserving your custom logic.
- ⚡️ **Fast & Native**: Built entirely in Swift utilizing `SwiftSyntax` for AST parsing. No Node.js, Python, or Java environments required.

## Getting Started

### Installation
You can build the CLI tool via Swift Package Manager:
```bash
git clone https://github.com/SamuelMarks/cdd-swift.git
cd cdd-swift
swift build -c release
cp .build/release/cdd-swift /usr/local/bin/
```

## Quick Start

### 1. Codebase -> OpenAPI
Extract OpenAPI schemas directly from your existing Swift files:
```bash
cdd-swift parse-swift Models.swift -o openapi.json
```

### 2. OpenAPI -> Codebase
Generate an async/await Swift API Client and Codable models from an OpenAPI spec:
```bash
cdd-swift generate-swift openapi.json -o APIClient.swift
```

### 3. Safe Merging
Keep your custom Swift extensions and update the generated models in place:
```bash
cdd-swift merge-swift openapi.json target.swift
```

## Documentation
- [Usage Guide](USAGE.md)
- [Architecture](ARCHITECTURE.md)
- [Compliance Details](COMPLIANCE.md)
- [Developing / Contributing](DEVELOPING.md)

## License
MIT
