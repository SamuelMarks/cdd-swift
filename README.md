cdd-Swift
============

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Swift CI](https://github.com/SamuelMarks/cdd-swift/actions/workflows/swift.yml/badge.svg)](https://github.com/SamuelMarks/cdd-swift/actions/workflows/swift.yml)
[![Doc Coverage](https://img.shields.io/badge/doc_coverage-100.0%25-success)](https://github.com/offscale/cdd-swift)
[![Test Coverage](https://img.shields.io/badge/test_coverage-100.0%25-success)](https://github.com/offscale/cdd-swift)

OpenAPI ↔ Swift. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The CLI—at a minimum—has:
- `cdd-swift --help`
- `cdd-swift --version`
- `cdd-swift from_openapi -i spec.json`
- `cdd-swift to_openapi -f path/to/code`
- `cdd-swift to_docs_json --no-imports --no-wrapping -i spec.json`

The goal of this project is to enable rapid application development without tradeoffs. Tradeoffs of Protocol Buffers / Thrift etc. are an untouchable "generated" directory and package, compile-time and/or runtime overhead. Tradeoffs of Java or JavaScript for everything are: overhead in hardware access, offline mode, ML inefficiency, and more. And neither of these alterantive approaches are truly integrated into your target system, test frameworks, and bigger abstractions you build in your app. Tradeoffs in CDD are code duplication (but CDD handles the synchronisation for you).

## 🚀 Capabilities

The `cdd-swift` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Swift`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Swift` → OpenAPI**: Statically parse existing `Swift` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

Requires Swift 5.9+.

```bash
git clone https://github.com/offscale/cdd-swift.git
cd cdd-swift
swift build -c release
cp .build/release/cdd-swift /usr/local/bin/
```

## 🛠 Usage

### Command Line Interface

```bash
# Generate Swift SDK from OpenAPI
cdd-swift from_openapi to_sdk -i openapi.json -o ./MyClientSDK

# Generate OpenAPI from existing Swift models
cdd-swift to_openapi -f Sources/MyModels.swift -o openapi.json
```

### Programmatic SDK / Library

```swift
import CDDSwift

let parser = SwiftASTParser()
let document = try parser.parseDocument(from: mySwiftSourceString)
let builder = OpenAPIDocumentBuilder(title: "API", version: "1.0.0")
let json = try builder.serialize()
```

## Design choices

`swift-syntax` is used for robust, source-accurate AST parsing and manipulation. This ensures that whitespace and comments are preserved. `swift-argument-parser` is leveraged for the CLI, providing standard POSIX compliant arguments.

## 🏗 Supported Conversions for Swift

*(The boxes below reflect the features supported by this specific `cdd-swift` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | [✅] | [✅] |
| `Swift` Models / Structs / Types | [✅] | [✅] |
| `Swift` Server Routes / Endpoints | [✅] | [✅] |
| `Swift` API Clients / SDKs | [✅] | [✅] |
| `Swift` ORM / DB Schemas | [ ] | [ ] |
| `Swift` CLI Argument Parsers | [✅] | [✅] |
| `Swift` Docstrings / Comments | [✅] | [✅] |

---

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.

## CLI Help

```
$ .build/release/cdd-swift --help
OVERVIEW: A utility to convert between OpenAPI and Swift.

USAGE: cdd-swift <subcommand>

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  from_openapi            Generate Swift code from an OpenAPI document.
  generate-open-api       Generate an example OpenAPI JSON document from Swift
                          builder.
  to_openapi              Parse a Swift file to extract Codable models and
                          generate OpenAPI JSON.
  merge-swift             Merge generated Swift code from an OpenAPI document
                          into an existing Swift file.
  to_docs_json            Generate a JSON document containing idiomatic Swift
                          code examples for an OpenAPI specification.
  serve_json_rpc          Run a JSON-RPC HTTP server exposing the CLI
                          capabilities.

  See 'cdd-swift help <subcommand>' for detailed help.
```

### `from_openapi`

```
$ .build/release/cdd-swift from_openapi --help
OVERVIEW: Generate a Swift SDK from an OpenAPI document.

USAGE: cdd-swift from_openapi to_sdk [--input <input>] [--input-dir <input-dir>] [--output <output>] [--no-github-actions] [--no-installable-package]

OPTIONS:
  -i, --input <input>     Path to the input OpenAPI JSON file.
  --input-dir <input-dir> Path to a directory containing OpenAPI specifications.
  -o, --output <output>   Path to the output directory. Defaults to current
                          working directory.
  --no-github-actions     Do not generate GitHub Actions workflow.
  --no-installable-package
                          Do not generate installable package scaffolding.
  --version               Show the version.
  -h, --help              Show help information.
```

### `to_openapi`

```
$ .build/release/cdd-swift to_openapi --help
OVERVIEW: Parse a Swift file to extract Codable models and generate OpenAPI
JSON.

USAGE: cdd-swift to_openapi --input <input> [--output-path <output-path>]

OPTIONS:
  -i, --input <input>     Path to the input Swift file.
  -o, --output-path <output-path>
                          Path to the output JSON file. Prints to stdout if not
                          provided.
  --version               Show the version.
  -h, --help              Show help information.
```

### `to_docs_json`

```
$ .build/release/cdd-swift to_docs_json --help
OVERVIEW: Generate a JSON document containing idiomatic Swift code examples for
an OpenAPI specification.

USAGE: cdd-swift to_docs_json --input <input> [--output <output>] [--no-imports] [--no-wrapping]

OPTIONS:
  -i, --input <input>     Path or URL to the input OpenAPI specification.
  -o, --output <output>   Path to the output JSON file. Prints to stdout if not
                          provided.
  --no-imports            If provided, omit the imports field in the code
                          object.
  --no-wrapping           If provided, omit the wrapper_start and wrapper_end
                          fields in the code object.
  --version               Show the version.
  -h, --help              Show help information.
```
