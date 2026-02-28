cdd_swift
=========

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI/CD](https://github.com/offscale/cdd_swift/workflows/CI/badge.svg)](https://github.com/offscale/cdd_swift/actions)

OpenAPI ↔ Swift. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The CLI—at a minimum—has:
- `cdd_swift --help`
- `cdd_swift --version`
- `cdd_swift from_openapi -i spec.json`
- `cdd_swift to_openapi -f path/to/code`
- `cdd_swift to_docs_json --no-imports --no-wrapping -i spec.json`

The goal of this project is to enable rapid application development without tradeoffs. Tradeoffs of Protocol Buffers / Thrift etc. are an untouchable "generated" directory and package, compile-time and/or runtime overhead. Tradeoffs of Java or JavaScript for everything are: overhead in hardware access, offline mode, ML inefficiency, and more. And neither of these alternative approaches are truly integrated into your target system, test frameworks, and bigger abstractions you build in your app. Tradeoffs in CDD are code duplication (but CDD handles the synchronisation for you).

## 🚀 Capabilities

The `cdd_swift` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Swift`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Swift` → OpenAPI**: Statically parse existing `Swift` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

This project requires Swift 5.5+. 

To build the CLI tool from source:
```bash
git clone https://github.com/offscale/cdd_swift.git
cd cdd_swift
swift build -c release
```
The compiled binary will be available at `.build/release/cdd_swift`.

## 🛠 Usage

### Command Line Interface

Generate Swift code from an OpenAPI document:
```bash
.build/release/cdd_swift from_openapi -i openapi.json -o APIClient.swift
```

Parse existing Swift models back into an OpenAPI document:
```bash
.build/release/cdd_swift to_openapi -f APIClient.swift -o openapi.json
```

Generate a docs JSON array from an OpenAPI document:
```bash
.build/release/cdd_swift to_docs_json -i openapi.json > docs.json
```

### Programmatic SDK / Library

You can integrate CDDSwift directly into your Swift applications or scripts:

```swift
import Foundation
import CDDSwift

// Parse OpenAPI to Swift code
let json = try String(contentsOf: URL(fileURLWithPath: "openapi.json"), encoding: .utf8)
let document = try OpenAPIParser.parse(json: json)
let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)

// Parse Swift code to OpenAPI Models
let sourceCode = try String(contentsOf: URL(fileURLWithPath: "Models.swift"), encoding: .utf8)
let parser = SwiftASTParser()
let schemas = try parser.parseModels(from: sourceCode)
```

## Design choices

`cdd_swift` uses `SwiftSyntax` to perform safe, comprehensive static analysis of Swift source code without requiring the code to be compiled or executed. This guarantees that `cdd_swift` can parse and synchronize partially written code during rapid development phases. Unlike basic regex-based scaffolding, it builds a full AST (Abstract Syntax Tree) representation which is converted into our Intermediate Representation (IR).

## 🏗 Supported Conversions for Swift

*(The boxes below reflect the features supported by this specific `cdd_swift` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | [✅] | [✅] |
| `Swift` Models / Structs / Types | [✅] | [✅] |
| `Swift` Server Routes / Endpoints | [✅] | [✅] |
| `Swift` API Clients / SDKs | [ ] | [✅] |
| `Swift` ORM / DB Schemas | [ ] | [ ] |
| `Swift` CLI Argument Parsers | [ ] | [ ] |
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
