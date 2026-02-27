cdd-swift
=========

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Swift](https://github.com/SamuelMarks/cdd-swift/actions/workflows/swift.yml/badge.svg)](https://github.com/SamuelMarks/cdd-swift/actions/workflows/swift.yml)

OpenAPI ↔ Swift. Welcome to **cdd-swift**, a code-generation and compilation tool bridging the gap between OpenAPI specifications and native `Swift` source code. 

This toolset allows you to fluidly convert between your language's native constructs (like classes, structs, functions, routing, clients, and ORM models) and OpenAPI specifications, ensuring a single source of truth without sacrificing developer ergonomics.

## 🚀 Capabilities

The `cdd-swift` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Swift`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Swift` → OpenAPI**: Statically parse existing `Swift` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) via SwiftSyntax instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

To use `cdd-swift` as a command-line tool, you can build and run it from source. Ensure you have the [Swift Toolchain](https://www.swift.org/download/) (5.9+) installed.

```bash
git clone https://github.com/offscale/cdd-swift.git
cd cdd-swift
swift build -c release
```

The compiled binary will be located at `.build/release/cdd-swift`. You can run it directly:

```bash
.build/release/cdd-swift --help
```

To use it programmatically as a dependency in your Swift project, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/offscale/cdd-swift.git", branch: "main")
]
```

## 🛠 Usage

### Command Line Interface

```bash
# Generate Swift models from an OpenAPI JSON document
swift run cdd-swift generate-swift path/to/openapi.json -o OutputModels.swift

# Parse existing Swift models and extract them into an OpenAPI JSON document
swift run cdd-swift parse-swift path/to/Models.swift -o generated-openapi.json

# Merge generated Swift code from an OpenAPI definition into an existing Swift file
swift run cdd-swift merge-swift path/to/openapi.json path/to/ExistingFile.swift
```

### Programmatic SDK / Library

```swift
import CDDSwift
import Foundation

// 1. Parse OpenAPI JSON and generate Swift code
let openapiJson = """
{
  "openapi": "3.0.0",
  "info": {"title": "Sample API", "version": "1.0"},
  "components": {
    "schemas": {
      "User": {
        "type": "object",
        "properties": {"id": {"type": "string"}, "name": {"type": "string"}},
        "required": ["id", "name"]
      }
    }
  }
}
"""

do {
    let document = try OpenAPIParser.parse(json: openapiJson)
    let generatedSwiftCode = OpenAPIToSwiftGenerator.generate(from: document)
    print(generatedSwiftCode)
} catch {
    print("Error parsing OpenAPI: \\(error)")
}

// 2. Parse existing Swift source and generate OpenAPI models
let swiftSource = """
struct User: Codable {
    var id: String
    var name: String
}
"""

do {
    let parser = SwiftASTParser()
    let schemas = try parser.parseModels(from: swiftSource)
    
    let builder = OpenAPIDocumentBuilder(title: "Parsed API", version: "1.0")
    for (name, schema) in schemas {
        _ = builder.addSchema(name, schema: schema)
    }
    
    let jsonString = try builder.serialize()
    print(jsonString)
} catch {
    print("Error parsing Swift: \\(error)")
}
```

## 🏗 Supported Conversions for Swift

*(The boxes below reflect the features supported by this specific `cdd-swift` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | [✅] | [✅] |
| `Swift` Models / Structs / Types | [✅] | [✅] |
| `Swift` Server Routes / Endpoints | [✅] | [✅] |
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
