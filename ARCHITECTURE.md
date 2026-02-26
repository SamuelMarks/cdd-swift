# Architecture

`CDDSwift` is designed to be a fast, zero-dependency (other than SwiftSyntax and ArgumentParser) bidirectional bridge between Swift code and OpenAPI 3.2.0 specifications.

## Core Components

### 1. Data Models (`OpenAPIModels.swift`)
The heart of the library is a robust set of `Codable` structs mapping 1:1 with the OpenAPI 3.2.0 Specification. This includes everything from `OpenAPIDocument` and `PathItem` down to complex JSON Schema definitions like `Schema`, `Discriminator`, `XML`, and OAuth flows. We utilize Swift's `Codable` synthesis combined with custom `CodingKeys` to perfectly map the JSON structure.

### 2. AST Parsing (`SwiftASTParser.swift`)
To support generating an OpenAPI document *from* an existing Swift codebase, we use `SwiftSyntax` to walk the Abstract Syntax Tree of Swift files. 
- It looks for structs that conform to `Codable`, `Encodable`, or `Decodable`.
- It maps standard Swift types (`String`, `Int`, `Double`, `Bool`, `Date`, `UUID`, Arrays, Dictionaries, Tuples) to their OpenAPI JSON Schema equivalents (including `additionalProperties` and `prefixItems`).

### 3. Swift Generation (`OpenAPIToSwiftGenerator.swift`)
Translates an `OpenAPIDocument` struct into valid Swift source code.
- **Models**: Generates `Codable` structs and Enums. It flattens `allOf` properties, handles `$dynamicRef`, and handles `anyOf`/`oneOf` through enum-based polymorphism.
- **API Client**: Generates a `URLSession`-based async/await API Client. It constructs query items, handles path parameters, auth headers, form URL encoding, and JSON bodies.
- **Webhooks & Callbacks**: Generates Swift `protocol` definitions for any out-of-band events defined in the spec so that the developer can implement them.

### 4. OpenAPI Generation (`SwiftToOpenAPIGenerator.swift`)
A fluent builder pattern (`OpenAPIDocumentBuilder`) to easily construct an OpenAPI Document in Swift memory and serialize it back to pretty-printed JSON.

### 5. Safe Merging (`SwiftCodeMerger.swift`)
A utility designed to non-destructively inject generated code into hand-written Swift files. It relies on standard marker comments:
```swift
// MARK: - CDDSwift Auto-Generated Start
...
// MARK: - CDDSwift Auto-Generated End
```
This allows developers to keep their custom extensions and network overrides in the same file as the generated models without them being overwritten on the next generation cycle.

## Flow Diagrams

**Codebase -> OpenAPI**
`Swift Source` -> `SwiftSyntax (AST)` -> `SwiftASTParser` -> `OpenAPI Schema Models` -> `OpenAPIDocumentBuilder` -> `JSONEncoder` -> `openapi.json`

**OpenAPI -> Codebase**
`openapi.json` -> `JSONDecoder` -> `OpenAPIDocument` -> `OpenAPIToSwiftGenerator` -> `Swift Source String` -> `SwiftCodeMerger` -> `Final Swift File`
