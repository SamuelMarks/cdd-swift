# ``CDDSwift``

Bidirectional compiler and code generator between **OpenAPI 3.2.0**, **Swagger 2.0**, **Arazzo 1.1.0**, **Model Context Protocol (MCP 1.0.0)**, and **Swift 6.0+** (including **WebAssembly / WASI**).

## Overview

`CDDSwift` parses, emits, and non-destructively synchronizes strongly-typed Swift 6 client SDKs, `ArgumentParser` CLIs, Vapor/Fluent server stubs, XCTest / Swift Testing suites, and Model Context Protocol (MCP) servers and clients directly from specification documents or existing Swift source code using `SwiftSyntax`.

## Topics

### OpenAPI 3.2.0 & Swagger 2.0 Models

- ``OpenAPIDocument``
- ``Schema``
- ``SchemaItem``
- ``Operation``
- ``Parameter``
- ``RequestBody``
- ``Response``
- ``MediaType``
- ``EncodingObject``
- ``SecurityScheme``
- ``OAuthFlows``
- ``OAuthFlow``
- ``Header``
- ``Tag``
- ``Server``
- ``ServerVariable``
- ``Example``
- ``Link``
- ``Discriminator``
- ``XML``
- ``ExternalDocumentation``
- ``Reference``

### OpenAPI Domain Enums & JSON Types

- ``SchemaType``
- ``OpenAPIFormat``
- ``ParameterLocation``
- ``ParameterStyle``
- ``CollectionFormat``
- ``SecuritySchemeType``
- ``HTTPStatusCode``
- ``ContentType``
- ``HTTPMethod``
- ``XMLNodeType``
- ``JSONValue``
- ``AnyCodable``
- ``CDDError``
- ``CDDVersion``

### Arazzo 1.1.0 Workflows

- ``ArazzoSpecification``
- ``ArazzoWorkflow``
- ``ArazzoStep``
- ``ArazzoCriterion``
- ``ArazzoSuccessAction``
- ``ArazzoFailureAction``
- ``ArazzoSourceDescription``
- ``ArazzoEmitter``
- ``ArazzoExpressionEvaluator``
- ``ArazzoSdkEmitter``
- ``ArazzoCliEmitter``
- ``ArazzoTestEmitter``
- ``ArazzoServerEmitter``
- ``ArazzoCodeMerger``
- ``SwiftASTArazzoParser``
- ``ArazzoDocumentBuilder``

### Model Context Protocol (MCP 1.0.0)

- ``MCPClientSession``
- ``MCPServerSession``
- ``DefaultMCPServerRouter``
- ``MCPStdioTransport``
- ``MCPSSETransport``
- ``Tool``
- ``Resource``
- ``Prompt``
