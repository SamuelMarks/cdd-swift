# Developing `cdd-swift`

Welcome to `cdd-swift`!

## Prerequisites & Dependencies

Ensure you have **Swift 6.0+** installed. Cross-platform `Makefile` and `make.bat` scripts are provided:

```bash
make deps
make build
make test
```

Or on Windows:

```cmd
.\make.bat deps
.\make.bat build
.\make.bat test
```

For WebAssembly (WASI) cross-compilation, see [WASM.md](WASM.md).

## Running Tests & Coverage

Run the test suite with LLVM code coverage enabled:

```bash
swift test --enable-code-coverage
```

Verify 100% documentation coverage and 100% test coverage (and update `README.md` badges):

```bash
python3 scripts/find_missing_docs.py
python3 scripts/update_badges.py
```

## Linting & Formatting

This repository enforces strict formatting and linting via `swiftformat` and `swiftlint`:

```bash
swiftformat --lint .
swiftlint lint --strict
```

## Directory Structure

- `Sources/CDDSwift`: Core compiler library and runtime modules:
  - `arazzo/`: Arazzo 1.1.0 models, runtime expression evaluator, JSON/YAML emitter, `SwiftSyntax` parser, lossless code merger, and SDK/CLI/Test/Server emitters.
  - `classes/`: Swift `Codable` struct/enum emitters, `ModelVisitor`, and JSON Schema `@propertyWrapper` validators.
  - `client_sdk/`: `OpenAPIDocumentBuilder`, `OpenAPIToSwiftGenerator`, `SwiftASTParser`, and `SwiftCodeMerger`.
  - `client_sdk_cli/`: `ArgumentParser` CLI emitter and `CliVisitor`.
  - `docstrings/`: `SwiftSyntax` trivia docstring parser and emitter.
  - `functions/`: Webhook and callback emitter and `FunctionVisitor`.
  - `mcp/`: Model Context Protocol (MCP) client/server sessions, routers, stdio/SSE transports, and JSON-RPC 2.0 models.
  - `mocks/`: `MockAPIClient` emitter and `MockVisitor`.
  - `openapi/`: OpenAPI 3.2.0 / Swagger 2.0 AST models, `AnyCodable`, `CDDError`, and `DocsJsonGenerator`.
  - `routes/`: Client HTTP method emitter (RFC 6570) and `RouteVisitor`.
  - `server/`: Vapor 4 + Fluent ORM + Fakery server emitter and `ServerVisitor`.
  - `tests/`: Contract test suite emitter, deterministic dummy JSON generator, and `TestVisitor`.
- `Sources/cdd-swift-cli`: CLI executable entrypoints (`from_openapi`, `to_openapi`, `generate_openapi`, `merge_swift`, `sync`, `from_arazzo`, `to_arazzo`, `generate_arazzo`, `sync_arazzo`, `to_docs_json`, `serve_json_rpc`, `mcp`) and `WASIFileHelpers`.
- `Tests/CDDSwiftTests` & `Tests/CDDSwiftCliTests`: Unit, roundtrip, and CLI test suites.

## Pre-Commit Hooks

Install the pre-commit hooks using `pre-commit install`. Running `pre-commit run --all-files` validates formatting, linting, documentation coverage, test coverage, and specification conformance.
