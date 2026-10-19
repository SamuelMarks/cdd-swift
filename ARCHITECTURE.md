# cdd-swift Architecture

<!-- BADGES_START -->
[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI](https://github.com/SamuelMarks/cdd-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/SamuelMarks/cdd-swift/actions)
[![Test Coverage](https://img.shields.io/badge/test_coverage-100.00%25-brightgreen.svg)](#)
[![Doc Coverage](https://img.shields.io/badge/doc_coverage-100.00%25-brightgreen.svg)](#)
<!-- BADGES_END -->

`cdd-swift` is a native Swift 6 compiler for **Compiler Driven Development (CDD)**, providing lossless, bidirectional compilation between Swift source code and **OpenAPI 3.2.0**, **Swagger 2.0**, **Arazzo 1.1.0**, and **Model Context Protocol (MCP)** specifications.

---

## High-Level System Architecture

```
+-------------------------------------------------------------------------+
|                        cdd-swift-cli / CDDSwift                         |
|  from_openapi | to_openapi | merge_swift | sync | to_docs_json          |
|  from_arazzo  | to_arazzo  | sync_arazzo | generate_openapi/arazzo      |
|  mcp (stdio/SSE)           | serve_json_rpc (HTTP JSON-RPC 2.0)         |
+------------------------------------+------------------------------------+
                                     |
                 +-------------------+-------------------+
                 |                                       |
                 v                                       v
+---------------------------------+     +---------------------------------+
|  Specification Parsers/Emitters |     |  SwiftSyntax CST/AST Pipeline   |
|  - OpenAPIParser                |     |  - SwiftASTParser (7 Visitors)  |
|  - OpenAPIDocumentBuilder       |     |  - SwiftASTArazzoParser         |
|  - ArazzoEmitter (JSON & YAML)  |     |  - SwiftCodeMerger (Rewriter)   |
|  - ArazzoDocumentBuilder        |     |  - ArazzoCodeMerger (Rewriter)  |
+----------------+----------------+     +----------------+----------------+
                 |                                       |
                 +-------------------+-------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                  Intermediate Representation (IR)                       |
|  - OpenAPIDocument (OpenAPI 3.2.0 + Swagger 2.0 upgrade models)         |
|  - ArazzoSpecification & ArazzoExecutionContext                         |
|  - MCP Tool / Resource / Session Models                                 |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                       Target Code Emitters                              |
|  - classes/        Codable structs, polymorphic enums, @propertyWrapper |
|  - routes/         URLSession async/await client methods (RFC 6570)     |
|  - client_sdk/     SDK package generator & SwiftCodeMerger              |
|  - client_sdk_cli/ ArgumentParser CLI generator                         |
|  - server/         Vapor 4 + Fluent ORM + Fakery + IdP server generator |
|  - mocks/ & tests/ MockAPIClient, XCTest, XCTVapor & Swift Testing      |
|  - arazzo/         WorkflowsClient, WorkflowCLI, Probes & Tests         |
|  - openapi/        DocsJsonGenerator (to_docs_json)                     |
+-------------------------------------------------------------------------+
```

---

## Module Breakdown (`Sources/`)

### 1. `Sources/CDDSwift/` (Core Compiler & Runtime Library)

- **`openapi/`**:
  - `models.swift`: Strongly typed `Codable` & `Sendable` representations of OpenAPI 3.2.0 and Swagger 2.0 documents, JSON Schema Draft 2020-12 keywords, security schemes, webhooks, and callbacks.
  - `any_codable.swift`: Type-erased `AnyCodable` container supporting arbitrary JSON primitives, arrays, and nested objects.
  - `DocsJsonGenerator.swift` & `DocsJsonModels.swift`: Generates structured documentation JSON with executable Swift code snippets (`to_docs_json`).
  - `CDDError.swift`: Unified, strongly typed error domain (`CDDError`) covering file I/O, parsing, schema validation, and Arazzo expression evaluation.
- **`classes/`**:
  - `ClassesEmit.swift` & `ClassesParse.swift`: Emits and reverse-parses `Codable` structs, `CaseIterable` string enums, polymorphic `oneOf`/`anyOf` discriminated union enums, and cyclic `$ref` indirect boxes.
  - `ValidationPropertyWrappers.swift`: Native Swift `@propertyWrapper` validators (`@Minimum`, `@Maximum`, `@ExclusiveMinimum`, `@ExclusiveMaximum`, `@MultipleOf`, `@MinLength`, `@MaxLength`, `@Pattern`, `@MinItems`, `@MaxItems`, `@UniqueItems`).
- **`routes/` & `functions/` & `docstrings/`**:
  - `RoutesEmit.swift` & `RoutesParse.swift`: Emits `URLSession` `async throws` methods with full RFC 6570 path/query/header/cookie parameter serialization and extracts `PathItem` definitions from existing Swift client methods.
  - `FunctionsEmit.swift` & `FunctionsParse.swift`: Emits and extracts webhook and callback handlers (`onEvent`).
  - `DocstringsEmit.swift` & `DocstringsParse.swift`: Preserves and parses `///` and `/** ... */` documentation trivia attached to `SwiftSyntax` nodes.
- **`client_sdk/` & `client_sdk_cli/`**:
  - `ClientSdkEmit.swift` & `ClientSdkParse.swift`: `OpenAPIDocumentBuilder`, `OpenAPIToSwiftGenerator`, `SwiftASTParser` (coordinating `ModelVisitor`, `RouteVisitor`, `ServerVisitor`, `CliVisitor`, `MockVisitor`, `TestVisitor`, and `FunctionVisitor`), and `SwiftCodeMerger` (`SyntaxRewriter`).
  - `ClientSdkCliEmit.swift` & `ClientSdkCliParse.swift`: Generates and reverse-parses `ArgumentParser` CLI commands for every API operation.
- **`server/`**:
  - `ServerEmit.swift` & `ServerParse.swift`: Generates and reverse-parses Vapor 4 route collections, Fluent ORM `@Model` classes, `AsyncMigration` schemas, `Stub<Schema>DAO` / `Concrete<Schema>DAO` layers, `DatabaseSeeder` (`Fakery`), mock Identity Provider (`/auth/*`), and webhook trigger endpoints (`/_mock/trigger-webhook/:name`).
- **`mocks/` & `tests/`**:
  - `MocksEmit.swift` & `MocksParse.swift`: Emits and parses `MockAPIClient` classes.
  - `TestsEmit.swift` & `TestsParse.swift`: Generates deterministic dummy JSON payloads (`DummyJSONContext`, cycle-safe `$ref` resolution) and `XCTestCase` contract tests.
- **`arazzo/`**:
  - `ArazzoModels.swift`, `ArazzoEmit.swift`, `ArazzoExpression.swift`, `ArazzoParse.swift`, `ArazzoCodeMerger.swift`, `ArazzoSdkEmit.swift`, `ArazzoCliEmit.swift`, `ArazzoTestEmit.swift`, `ArazzoServerEmit.swift`: Complete Arazzo 1.1.0 parser, JSON/YAML serializer, runtime expression evaluator, `SwiftSyntax` reverse-parser, CST code merger, and SDK/CLI/Test/Server emitters.
- **`mcp/`**:
  - `JSONRPC.swift`, `MCPMessages.swift`, `MCPToolModels.swift`, `MCPResourceModels.swift`, `MCPMiscModels.swift`, `MCPStdioTransport.swift`, `client/MCPClientSession.swift`, `server/MCPServerSession.swift`, `server/DefaultMCPServerRouter.swift`, `server/MCPSSETransport.swift`, `server/HTTPBridge.swift`: Full Model Context Protocol client and server runtime over `stdio` and Server-Sent Events (SSE).

### 2. `Sources/cdd-swift-cli/` (Command-Line Interface & WASI Layer)

- `CDDSwiftCLI.swift`, `FromOpenAPI.swift`, `FromArazzo.swift`, `ToArazzo.swift`, `GenerateArazzo.swift`, `SyncArazzo.swift`, `ToDocsJson.swift`, `MCPServe.swift`, `ServeJsonRpc.swift`, and `WASIFileHelpers.swift`: Implements the `ArgumentParser` CLI, `CDD_*` environment variable forwarding, JSON-RPC 2.0 HTTP server (`Swifter`), and WASI-compatible POSIX file system helpers.

---

## Design Principles

1. **Lossless Trivia Preservation**: `SwiftSyntax` (`viewMode: .sourceAccurate`) retains all `leadingTrivia` and `trailingTrivia` on every token, ensuring `SwiftCodeMerger` and `ArazzoCodeMerger` update declarations in-place without destroying formatting or comments.
2. **Zero Runtime Reflection for Extraction**: `to_openapi` and `to_arazzo` statically analyze `.swift` files using `SwiftParser` without compiling or executing untrusted target code.
3. **100% Test & Documentation Coverage**: Every public symbol in `CDDSwift` and `cdd-swift-cli` is documented with DocC comments and verified by unit and end-to-end roundtrip tests.
