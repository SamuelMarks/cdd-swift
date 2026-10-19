# Usage

## CLI Usage

The `cdd-swift` CLI compiles [OpenAPI 3.2.0](https://spec.openapis.org/oas/v3.2.0.html), [Swagger 2.0](https://spec.openapis.org/oas/v2.0.html), and [Arazzo 1.1.0](https://spec.openapis.org/arazzo/v1.1.0.html) specifications to and from Swift source code.

### Getting Help & Version

```bash
cdd-swift --help
cdd-swift --version
```

### OpenAPI / Swagger 2.0 to Swift (`from_openapi`)

Generate an idiomatic Swift Client SDK (`to_sdk`), ArgumentParser Client CLI (`to_sdk_cli`), or Vapor/Fluent Server (`to_server`):

```bash
# Generate a Client SDK (default subcommand) with contract tests and mocks
cdd-swift from_openapi to_sdk -i spec.json -o ./MySDK --tests

# Generate an ArgumentParser CLI
cdd-swift from_openapi to_sdk_cli -i spec.json -o ./MyCLI --tests

# Generate a Vapor 4 + Fluent ORM Server stub (supports --ephemeral, --seed, --start-auth-server)
cdd-swift from_openapi to_server -i spec.json -o ./MyServer --tests

# Batch-generate from a directory of OpenAPI specifications with MCP adapters
cdd-swift from_openapi to_sdk --input-dir ./specs -o ./MySDK --tests --mcp

# Emit raw Swift source files without Package.swift or GitHub Actions scaffolding
cdd-swift from_openapi to_sdk -i spec.json -o ./Sources --no-installable-package --no-github-actions
```

### Swift to OpenAPI 3.2.0 (`to_openapi` & `generate_openapi`)

Extract an authoritative OpenAPI 3.2.0 specification from existing Swift `Codable` models, Vapor routes, client methods, CLI commands, mocks, and docstrings:

```bash
# Parse a Swift file or directory into an OpenAPI 3.2.0 JSON document
cdd-swift to_openapi -i Sources/Models.swift -o openapi.json

# Generate a starter OpenAPI 3.2.0 specification using OpenAPIDocumentBuilder
cdd-swift generate_openapi -o example-openapi.json
```

### Lossless In-Place Synchronization (`sync` & `merge_swift`)

Synchronize Swift source code and OpenAPI specifications without overwriting custom logic, formatting, or comments:

```bash
# Synchronize Swift source code truth into an OpenAPI specification
cdd-swift sync --truth class -i Sources/Models.swift -o openapi.json

# Merge newly generated Swift declarations from an OpenAPI spec into an existing Swift file via SwiftSyntax
cdd-swift merge_swift -i openapi.json -o Sources/ExistingFile.swift
```

### Arazzo 1.1.0 Workflow Compilation (`from_arazzo`, `to_arazzo`, `generate_arazzo`, `sync_arazzo`)

Compile multi-step [Arazzo 1.1.0](https://spec.openapis.org/arazzo/v1.1.0.html) workflows to and from Swift:

```bash
# Generate a Swift Workflow Client SDK (WorkflowsClient)
cdd-swift from_arazzo to_sdk -i workflow.arazzo.json -o ./WorkflowSDK

# Generate a Swift ArgumentParser CLI Workflow Runner (WorkflowCLI)
cdd-swift from_arazzo to_sdk_cli -i workflow.arazzo.json -o ./WorkflowCLI

# Generate XCTest and Swift Testing (@Suite, @Test) integration suites
cdd-swift from_arazzo to_test -i workflow.arazzo.json -o ./WorkflowTests

# Generate server-side synthetic healthcheck probe orchestrators (ServerWorkflowOrchestrator)
cdd-swift from_arazzo to_server -i workflow.arazzo.json -o ./WorkflowServer

# Reverse-parse Swift workflow orchestrators into Arazzo 1.1.0 JSON or YAML
cdd-swift to_arazzo -i ./WorkflowSDK/Sources/GeneratedArazzoWorkflows/WorkflowsClient.swift -o extracted.arazzo.json --format json
cdd-swift to_arazzo -i ./WorkflowSDK/Sources/GeneratedArazzoWorkflows/WorkflowsClient.swift -o extracted.arazzo.yaml --format yaml

# Bidirectionally synchronize Swift workflow classes and Arazzo 1.1.0 JSON
cdd-swift sync_arazzo -i ./WorkflowsClient.swift -o ./workflow.arazzo.json --truth swift
cdd-swift sync_arazzo -i ./WorkflowsClient.swift -o ./workflow.arazzo.json --truth arazzo

# Generate a starter Arazzo 1.1.0 workflow specification
cdd-swift generate_arazzo -o example.arazzo.json
```

### Generate Documentation JSON (`to_docs_json`)

Generate documentation-optimized JSON containing executable Swift request snippets for every operation in an OpenAPI specification:

```bash
cdd-swift to_docs_json -i spec.json -o docs.json
cdd-swift to_docs_json --no-imports --no-wrapping -i spec.json -o docs.json
```

### Model Context Protocol (`mcp`) & JSON-RPC 2.0 Server (`serve_json_rpc`)

```bash
# Start the Model Context Protocol (MCP) server over stdio
cdd-swift mcp

# Expose the CLI over an HTTP JSON-RPC 2.0 interface
cdd-swift serve_json_rpc --listen 0.0.0.0 --port 8082
```

### Environment Variables

Any CLI flag can also be supplied via its `CDD_<FLAG_NAME>` environment variable (for example, `CDD_INPUT`, `CDD_INPUT_DIR`, `CDD_OUTPUT`, `CDD_TESTS=true`, `CDD_MCP=true`, `CDD_NO_GITHUB_ACTIONS=true`, `CDD_NO_INSTALLABLE_PACKAGE=true`, `CDD_NO_IMPORTS=true`, `CDD_NO_WRAPPING=true`, `CDD_PORT`, `CDD_LISTEN`, `CDD_TRUTH`).

---

## Programmatic SDK Usage (`CDDSwift`)

Import `CDDSwift` into any Swift 6+ package or executable to drive OpenAPI and Arazzo compilation in memory:

```swift
import CDDSwift
import Foundation

// Parse OpenAPI 3.2.0 or Swagger 2.0 JSON
let doc = try OpenAPIParser.parse(json: openapiJsonString)

// Generate Swift SDK, CLI, Vapor/Fluent Server, and Docs JSON
let sdkFiles = OpenAPIToSwiftGenerator.generateFiles(from: doc, tests: true)
let cliCode = emitCliCode(document: doc)
let serverFiles = emitServerFiles(document: doc, testsMocks: true)
let docsJson = DocsJsonGenerator.generate(from: doc, includeImports: true, includeWrapping: true)

// Losslessly merge generated Swift code into an existing file
let mergedCode = SwiftCodeMerger.merge(generatedCode: OpenAPIToSwiftGenerator.generate(from: doc), into: existingSwiftSource)

// Reverse-parse Swift source code back into an OpenAPIDocument
let parsedDoc = try SwiftASTParser().parseDocument(from: mergedCode)

// Parse, emit, and merge Arazzo 1.1.0 workflows
let arazzoSpec = try ArazzoEmitter.parse(json: arazzoJsonString)
let workflowSdk = ArazzoSdkEmitter.emitWorkflowClient(from: arazzoSpec)
let workflowCli = ArazzoCliEmitter.emitWorkflowCLI(from: arazzoSpec)
let workflowTests = ArazzoTestEmitter.emitTestSuite(from: arazzoSpec)
let workflowProbes = ArazzoServerEmitter.emitServerOrchestrator(from: arazzoSpec)
let roundtrippedSpec = try SwiftASTArazzoParser().parseSpecification(from: workflowSdk)
```
