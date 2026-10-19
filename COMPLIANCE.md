# Specification Compliance

`cdd-swift` implements bidirectional compilation across **OpenAPI 3.2.0**, **Swagger 2.0**, **Arazzo 1.1.0**, and the **Model Context Protocol (MCP 1.0.0)**.

---

## OpenAPI 3.2.0 & Swagger 2.0 Support Matrix

`cdd-swift` is engineered directly against `3.2.0.md` and automatically upgrades legacy Swagger 2.0 (`swagger: "2.0"`, `host`, `basePath`, `schemes`, `consumes`, `produces`, `definitions`, `parameters`, `responses`, `securityDefinitions`) and OpenAPI 3.0/3.1 documents to the OpenAPI 3.2.0 intermediate representation.

### 1. Core Structural Models (`Sources/CDDSwift/openapi/models.swift`)

- **`OpenAPIDocument`**: Full support for `openapi` (`3.2.0`), `swagger` (`2.0`), `$self`, `info`, `jsonSchemaDialect`, `servers`, `paths`, `webhooks`, `components`, `security`, `tags`, and `externalDocs`.
- **`Info`, `Contact`, `License`**: Supports `summary`, `description`, `termsOfService`, `contact`, and `license` (including OpenAPI 3.1/3.2 `identifier` SPDX expressions).
- **`Server` & `ServerVariable`**: Full support for multi-environment base URLs and enum/default variable substitution.
- **`Components`**: Supports `schemas`, `responses`, `parameters`, `examples`, `requestBodies`, `headers`, `securitySchemes`, `links`, `callbacks`, and `pathItems`.
- **`PathItem` & `Operation`**: Supports standard HTTP methods (`get`, `put`, `post`, `delete`, `options`, `head`, `patch`, `trace`), OpenAPI 3.2.0 `query` (`QUERY` HTTP method), and `additionalOperations`.
- **`Parameter` & `Header`**: Supports `path`, `query`, `header`, and `cookie` locations and RFC 6570 styles (`simple`, `label`, `matrix`, `form`, `spaceDelimited`, `pipeDelimited`, `deepObject`).
- **`MediaType` & `EncodingObject`**: Supports `schema`, `itemSchema` (streaming payloads), `example`, `examples`, `encoding`, `prefixEncoding`, and `itemEncoding`.
- **`SecurityScheme` & `OAuthFlows`**: Supports `apiKey`, `http` (`bearer`, `basic`), `mutualTLS`, `oauth2` (`implicit`, `password`, `clientCredentials`, `authorizationCode`, `deviceAuthorization` from OpenAPI 3.2.0), and `openIdConnect`, plus `deprecated`.
- **`Tag`**: Supports OpenAPI 3.2.0 hierarchical tags (`summary`, `parent`, `kind`).
- **`Example`**: Supports OpenAPI 3.2.0 `dataValue` and `serializedValue` alongside `value` and `externalValue`.
- **`Schema` (JSON Schema Draft 2020-12)**:
  - Structural & polymorphic keywords: `allOf`, `oneOf`, `anyOf`, `not`, `if`/`then`/`else`, `discriminator` (`propertyName`, `mapping`, `defaultMapping`), `prefixItems`, `items`, `additionalProperties`, `unevaluatedItems`, `unevaluatedProperties`, `dependentRequired`, `dependentSchemas`, `propertyNames`, `patternProperties`, `$id`, `$anchor`, `$dynamicAnchor`, `$dynamicRef`, `$defs`, `$vocabulary`, `xml` (`nodeType`).
  - Validation keywords: `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `minLength`, `maxLength`, `pattern`, `minItems`, `maxItems`, `uniqueItems`, `contains`, `minContains`, `maxContains`, `minProperties`, `maxProperties`, mapped to Swift `@propertyWrapper` validators (`ValidationPropertyWrappers.swift`).

---

## Arazzo 1.1.0 Workflow Specification Support Matrix

Implemented in `Sources/CDDSwift/arazzo/`:

- **Document Model (`ArazzoModels.swift`)**: `ArazzoSpecification` (`arazzo: "1.0.1"` / `"1.1.0"`), `ArazzoInfo`, `ArazzoSourceDescription` (`.openapi`, `.arazzo`), `ArazzoWorkflow`, `ArazzoStep`, `ArazzoParameter`, `ArazzoPayloadReplacement`, `ArazzoCriterion` (`simple`, `regex`, `jsonpath`, `xpath`), `ArazzoCriterionExpressionType`, `ArazzoSuccessAction` (`end`, `goto`), `ArazzoFailureAction` (`abort`, `retry`, `goto`, `retryAfter`, `retryLimit`), `ArazzoComponents`, and `ArazzoReusableRef`.
- **Runtime Expression Evaluator (`ArazzoExpression.swift`)**: Full evaluation of `$url`, `$method`, `$statusCode`, `$request.header.<name>`, `$request.query.<name>`, `$request.path.<name>`, `$request.body#<pointer>`, `$response.header.<name>`, `$response.body#<pointer>`, `$inputs.<name>`, `$outputs.<name>`, `$steps.<stepId>.outputs.<name>`, `$sourceDescriptions.<name>.url`, RFC 6901 JSON Pointers, embedded `{expression}` interpolation, and compound boolean criteria.
- **Forward & Reverse Compilation**:
  - `ArazzoSdkEmitter` (`from_arazzo to_sdk`) ⇄ `SwiftASTArazzoParser` (`to_arazzo`)
  - `ArazzoCliEmitter` (`from_arazzo to_sdk_cli`)
  - `ArazzoTestEmitter` (`from_arazzo to_test` — `XCTest` + Swift `Testing`)
  - `ArazzoServerEmitter` (`from_arazzo to_server` — `ServerWorkflowOrchestrator`)
  - `ArazzoCodeMerger` (`sync_arazzo` — lossless `SwiftSyntax` workflow merging)

---

## Model Context Protocol (MCP 1.0.0) Support Matrix

Implemented in `Sources/CDDSwift/mcp/`:

- **JSON-RPC 2.0 Wire Layer (`JSONRPC.swift`)**: Strongly typed request, notification, response, and error envelopes.
- **Transports**: `MCPStdioTransport` (standard input/output for CLI/IDE integration) and `MCPSSETransport` (Server-Sent Events + HTTP POST with `HTTPRequestContext` and `APIToolProxy`).
- **Capabilities & Models**: Tools (`MCPToolModels.swift`), Resources & Resource Templates (`MCPResourceModels.swift`), Prompts, Roots, Sampling, Logging, Pagination, and Cancellation (`MCPMiscModels.swift`, `MCPMessages.swift`).
- **Sessions & Routers**: `MCPServerSession`, `DefaultMCPServerRouter`, and `MCPClientSession`.
