cdd-swift
=========
[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![interactive WASM web demo](https://img.shields.io/badge/interactive-WASM_web_demo-blue.svg)](https://offscale.io/wasm_web_demo)
[![CI](https://github.com/SamuelMarks/cdd-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/SamuelMarks/cdd-swift/actions)
[![Test Coverage](https://img.shields.io/badge/test_coverage-100.00%25-brightgreen.svg)](#)
[![Doc Coverage](https://img.shields.io/badge/doc_coverage-97.96%25-brightgreen.svg)](#)

----

OpenAPI ↔ Swift. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The core philosophy of Compiler Driven Development (CDD) is synchronization without compromise. Where traditional generators silo your API boundaries into read-only files, this compiler natively merges changes into your codebase via a robust, [whitespace and comment aware] Abstract Syntax Tree (AST) driven parser & emitter. It bridges the gap between design and implementation, allowing you to seamlessly generate SDKs from a spec or extract a spec from existing code. By keeping your APIs, SDKs, and tests in continuous, automated alignment, it drastically improves both delivery speed and software reliability.

The CLI—at a minimum—has:

- `cdd-swift --help`
- `cdd-swift --version`
- `cdd-swift from_openapi to_sdk_cli -i spec.json`
- `cdd-swift from_openapi to_sdk -i spec.json`
- `cdd-swift from_openapi to_server -i spec.json`
- `cdd-swift to_openapi -f path/to/code`
- `cdd-swift to_docs_json --no-imports --no-wrapping -i spec.json`
- `cdd-swift serve_json_rpc --port 8080 --listen 0.0.0.0`

## Server Scaffolding & Mocking

The `to_server` generator command optionally implements an orthogonal, multi-tiered mock server architecture when the `--tests` flag is provided. This setup utilizes `Vapor` with `Fluent` and `Fakery`.

When running a generated server, you can use orthogonal flags to adjust how the mock behaves:

- `start` (No DB configured): **Stub Mode**. Server runs using traditional scaffolds, endpoints return `501 NotImplemented` or empty bodies depending on generation type.
- `start` (With `DATABASE_URL`): **Production Mode**. Uses actual ORM interactions against a real database connection.
- `start --ephemeral`: **Sandbox Mode**. Uses actual ORM interactions against a fresh, throwaway database (`.sqlite(.memory)`).
- `start --ephemeral --seed`: **Full Mock Mode**. Ephemeral database, automatically populated with a localized fake data graph.

## Contract Sync Tooling

The CLI toolset inherently supports deep, bi-directional synchronization between your code and your OpenAPI definitions.

Use `from_openapi`, `to_openapi`, and `sync --truth <SOURCE>` to maintain absolute harmony between the Server, the OpenAPI spec, the Database, and Test Clients:

- `cdd-swift sync --truth class -i Source/Models.swift -o spec.json`

This guarantees that your models and specifications never drift, making Contract-Driven Development a first-class feature of the deployment loop.

## SDK Example

```swift
import CDD

let config = CDDConfig(inputPath: "spec.json", outputPath: "src/models")
CDDGenerator.generateSDK(config)
print("SDK generation complete.")
```

## Installation

```bash
swift build
```

## Development

You can use standard tooling commands or the included cross-platform Makefiles to fetch dependencies, build, and test:

```bash
swift build
swift test
# or
make deps
make build
make test
# or on Windows
.\make.bat deps
.\make.bat build
.\make.bat test
```

See [PUBLISH.md](PUBLISH.md) for packaging and releasing.

## Features

The `cdd-swift` compiler leverages a unified architecture to support various facets of API and code lifecycle management. For a deep dive into the compiler's design, see [ARCHITECTURE.md](ARCHITECTURE.md).

- **Compilation**:
    - **OpenAPI → `Swift`**: Generate idiomatic native models, network routes, client SDKs, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
    - **`Swift` → OpenAPI**: Statically parse existing `Swift` source code and emit compliant OpenAPI specifications.
- **AST-Driven & Safe**: Employs static analysis instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
- **Model Context Protocol (MCP)**: Run an MCP server that provides tools for interacting with OpenAPI documents and code generation.
- **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

**Uncommon Features:**

`cdd-swift` supports standard CDD features.

## CLI Options

```text
Usage: cdd-swift [OPTIONS] <COMMAND>
```

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
