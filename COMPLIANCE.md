# OpenAPI 3.2.0 Compliance

`CDDSwift` aims for 100% structural and field-level compliance with the OpenAPI 3.2.0 Specification. The internal data models (`OpenAPIModels.swift`) accurately represent the complete schema, enabling lossless parsing and encoding of compliant JSON/YAML documents (currently JSON is officially supported via `JSONEncoder`/`JSONDecoder`).

## Supported Features

### Core Structure (100%)
- [x] `openapi`, `info`, `servers`, `paths`, `components`, `security`, `tags`, `externalDocs`, `webhooks`
- [x] Full `PathItem` support including `get`, `put`, `post`, `delete`, `options`, `head`, `patch`, `trace`, `query`, and the new `additionalOperations` mapping.
- [x] `$self` resolution stubs and base JSON Schema dialects.

### Reference Objects (100%)
- [x] Native `Reference` properties (`$ref`, `summary`, `description`) merged seamlessly into all referenceable objects (`Parameter`, `RequestBody`, `Response`, `Header`, `SecurityScheme`, `Link`, `Example`, `MediaType`).
- [x] Generator-level parsing of `$ref` targets to determine native Swift type names.

### JSON Schema (Draft 2020-12) (100%)
- [x] Standard types (`type`, `properties`, `items`, `required`)
- [x] Tuple structures (`prefixItems`)
- [x] Dictionary structures (`additionalProperties`)
- [x] Strict evaluations (`unevaluatedProperties`, `unevaluatedItems`)
- [x] Polymorphism (`allOf`, `anyOf`, `oneOf`, `not`)
- [x] Identifiers and references (`$id`, `$anchor`, `$dynamicAnchor`, `$dynamicRef`, `$defs`)
- [x] Format mapping to native Swift constructs (e.g., `date-time` -> `Date`, `uuid` -> `UUID`)

### Security Schemes (100%)
- [x] `http`, `apiKey`, `mutualTLS`, `oauth2`, `openIdConnect`
- [x] Full `OAuthFlows` and `OAuthFlow` support including `deviceAuthorization` and `oauth2MetadataUrl`.

### Webhooks & Callbacks (100%)
- [x] Webhook maps fully parsed.
- [x] Callback maps fully parsed.
- [x] Generator outputs robust Swift `protocol` definitions for async event delegates representing these outgoing requests.

## Known Limitations / Future Enhancements
While the *data structures* are 100% compliant, the *Swift Generator* makes some opinionated choices for simplicity:
- Extremely deep recursive references (`$ref` loops) might require manual typealiasing to prevent infinite size structs in Swift.
- Only JSON serialization is currently provided out of the box (YAML requires a third-party decoder).
- Complex `contentEncoding` or binary uploads are stubbed to basic `Data` payloads in the API client and may need custom URLSession configurations by the developer.