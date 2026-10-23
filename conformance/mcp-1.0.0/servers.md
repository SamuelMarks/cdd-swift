# Model Context Protocol (MCP) Server Generator Conformance Table

This table tracks the completeness of language Server generator integration with the Model Context Protocol (MCP). It is divided into three sections:
1. **Architectural Integration Layers**: Tracks the exposure of MCP across the CLI, SDK, and Server boundaries.
2. **Semantic & Conceptual Features**: Tracks protocol mechanics, transports, and behavioral requirements.
3. **Schema & Object Conformance**: An exhaustive property-by-property map derived directly from the official MCP JSON Schema (2024-11-05).

### Legend & Tracking Guide
*   **To**: Language -> MCP (Generating MCP Server payloads and handling requests from strongly typed code)
*   **From**: MCP -> Language (Generating MCP Client code, parsing responses, and invoking remote methods)
*   **Presence `[To, From]`**: The object/feature is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object/feature is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the Client architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

## 1. Architectural Integration Layers

This section tracks how the Model Context Protocol is exposed across both the **Generated Artifacts** (the output SDKs/APIs) and the **Generator Tooling** itself (the bidirectional `cdd` compiler/engine).

### 1A. Target/Generated Artifacts
Implementing MCP across the generated output ensures maximum flexibility for the end-user's AI architectures:

*   **CLI Integration (Local Desktop via `stdio`)**: Enables local AI assistants (Claude Desktop, Cursor, Windsurf) to spawn the generated CLI as a subprocess and natively interact with the API locally.
*   **SDK Integration (Programmatic / In-Memory)**: Provides native adapters (e.g., `client.mcp.get_tools()`) so developers can seamlessly attach the generated SDK to frameworks like LangChain, LlamaIndex, or raw LLM clients without network overhead.
*   **Server Integration (Remote AI Gateway via `sse`)**: Generates an AI Gateway endpoint (e.g., `/mcp/sse`), allowing remote, multi-tenant AI agents and web clients to securely consume the API as LLM tools over HTTP.

| Generated Boundary | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **CLI Integration (Local Desktop)** | | | | |
| CLI `mcp` Subcommand | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Generates a command (e.g., app mcp) to start the server |
| `stdio` Transport Bindings | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Wires stdin/stdout to the generated CLI logic |
| **SDK Integration (Programmatic)** | | | | |
| Native MCP Tool Adapter | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | E.g., client.mcp.get_tools() mapping SDK methods |
| Native MCP Resource Adapter | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Exposes internal state/docs as MCP resources |
| LLM Execution Router | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Native execution via client.mcp.execute_tool(name, args) |
| **Server Integration (Remote / SSE)** | | | | |
| SSE Endpoint Generation | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Wires MCP endpoints (e.g. /mcp/sse, /mcp/message) |
| HTTP Request/Auth Bridging | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Passes standard API auth into the MCP context |
| Dynamic API-to-Tool Proxy | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolves incoming tool calls to backend route handlers |

### 1B. Generator/Tooling Artifacts (Meta-MCP)
Exposing the `cdd` bidirectional code generator itself to MCP allows AI models to natively orchestrate code generation, schema manipulation, and code-to-schema extraction.

*   **Generator CLI via `stdio`**: Allows local IDEs or AI agents to directly instruct the generator to scaffold, diff, or compile code across languages (e.g., Tool: `cdd_generate(lang="python")`).
*   **Generator SDK / Core**: Exposes the AST and schema parsing engine natively to MCP, allowing AI tools to dynamically query API specs, understand types, and invoke generator internals in memory.

| Generator Boundary | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Generator CLI (`stdio`)** | | | | |
| Code Scaffold / Generate Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can invoke standard generator CLI commands via MCP |
| Schema Inspection Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can query loaded OpenAPI/AsyncAPI schemas |
| Bidirectional Sync Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can trigger code-to-schema extraction natively |
| **Generator SDK / Core** | | | | |
| AST / Type Query Resources | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can read internal AST structures as MCP resources |
| In-Memory Generation Router | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Native bindings to run the generator core directly via MCP |

## 2. Semantic & Conceptual Features

| MCP Feature / Behavior | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Transports** | | | | |
| Standard I/O (stdio) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | stdin/stdout message passing |
| Server-Sent Events (sse) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | HTTP POST + SSE streams |
| Custom Transports | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Pluggable transport interface |
| **JSON-RPC 2.0 Mechanics** | | | | |
| Message Parsing & Serialization | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | JSONRPCMessage enum & Codable JSON-RPC 2.0 wire framing |
| Request ID Mapping/Resolution | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolving async responses to requests |
| Error Code Mapping (Standard) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Codes like -32600, -32603 |
| Notification Handling | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Processing fire-and-forget messages |
| **Connection Lifecycle** | | | | |
| initialize Handshake Sequence | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Capability negotiation & version matching |
| initialized Acknowledgment | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Sent by client after successful initialization |
| Graceful Disconnect / Close | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | MCPTransport.close() & session teardown |
| Liveness (ping) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Periodic connection checks |
| Request Cancellation (cancelled) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Thread/Task abortion mechanics |
| **Behavioral & Security** | | | | |
| Pagination Cursor Management | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Handling nextCursor fetch loops |
| Progress Tracking (progress) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Emitting/handling progress events |
| Human-in-the-loop (Sampling) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Prompting user before LLM generation |
| Human-in-the-loop (Tools) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Security approvals/denials for tool calls |
| Root Boundary Enforcement | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Preventing traversal outside allowed directories |
| URI Protocol Handling | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolving custom URI schemes |

## 3. Schema & Object Conformance

| Schema Definition / Property | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **Annotated** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Annotated` model |
| Annotated (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Annotated.annotations` property |
| Annotated (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Annotated.annotations.audience` property |
| Annotated (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Annotated.annotations.priority` property |
| **BlobResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.BlobResourceContents` model |
| BlobResourceContents (`blob`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.BlobResourceContents.blob` property |
| BlobResourceContents (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.BlobResourceContents.mimeType` property |
| BlobResourceContents (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.BlobResourceContents.uri` property |
| **CallToolRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolRequest` model |
| CallToolRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolRequest.method` property |
| CallToolRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolRequest.params` property |
| CallToolRequest (`params`) (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolRequest.params.arguments` property |
| CallToolRequest (`params`) (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolRequest.params.name` property |
| **CallToolResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolResult` model |
| CallToolResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolResult._meta` property |
| CallToolResult (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolResult.content` property |
| CallToolResult (`isError`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CallToolResult.isError` property |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CancelledNotification` model |
| CancelledNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CancelledNotification.method` property |
| CancelledNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CancelledNotification.params` property |
| CancelledNotification (`params`) (`reason`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CancelledNotification.params.reason` property |
| CancelledNotification (`params`) (`requestId`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CancelledNotification.params.requestId` property |
| **ClientCapabilities** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientCapabilities` model |
| ClientCapabilities (`experimental`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientCapabilities.experimental` property |
| ClientCapabilities (`roots`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientCapabilities.roots` property |
| ClientCapabilities (`roots`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientCapabilities.roots.listChanged` property |
| ClientCapabilities (`sampling`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientCapabilities.sampling` property |
| **ClientNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientNotification` model |
| **ClientRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientRequest` model |
| **ClientResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ClientResult` model |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest` model |
| CompleteRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.method` property |
| CompleteRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.params` property |
| CompleteRequest (`params`) (`argument`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.params.argument` property |
| CompleteRequest (`params`) (`argument`) (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.params.argument.name` property |
| CompleteRequest (`params`) (`argument`) (`value`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.params.argument.value` property |
| CompleteRequest (`params`) (`ref`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteRequest.params.ref` property |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult` model |
| CompleteResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult._meta` property |
| CompleteResult (`completion`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult.completion` property |
| CompleteResult (`completion`) (`hasMore`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult.completion.hasMore` property |
| CompleteResult (`completion`) (`total`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult.completion.total` property |
| CompleteResult (`completion`) (`values`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CompleteResult.completion.values` property |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest` model |
| CreateMessageRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.method` property |
| CreateMessageRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params` property |
| CreateMessageRequest (`params`) (`includeContext`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.includeContext` property |
| CreateMessageRequest (`params`) (`maxTokens`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.maxTokens` property |
| CreateMessageRequest (`params`) (`messages`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.messages` property |
| CreateMessageRequest (`params`) (`metadata`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.metadata` property |
| CreateMessageRequest (`params`) (`modelPreferences`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.modelPreferences` property |
| CreateMessageRequest (`params`) (`stopSequences`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.stopSequences` property |
| CreateMessageRequest (`params`) (`systemPrompt`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.systemPrompt` property |
| CreateMessageRequest (`params`) (`temperature`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageRequest.params.temperature` property |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult` model |
| CreateMessageResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult._meta` property |
| CreateMessageResult (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult.content` property |
| CreateMessageResult (`model`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult.model` property |
| CreateMessageResult (`role`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult.role` property |
| CreateMessageResult (`stopReason`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.CreateMessageResult.stopReason` property |
| **Cursor** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Cursor` model |
| **EmbeddedResource** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource` model |
| EmbeddedResource (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource.annotations` property |
| EmbeddedResource (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource.annotations.audience` property |
| EmbeddedResource (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource.annotations.priority` property |
| EmbeddedResource (`resource`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource.resource` property |
| EmbeddedResource (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmbeddedResource.type` property |
| **EmptyResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.EmptyResult` model |
| **GetPromptRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptRequest` model |
| GetPromptRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptRequest.method` property |
| GetPromptRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptRequest.params` property |
| GetPromptRequest (`params`) (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptRequest.params.arguments` property |
| GetPromptRequest (`params`) (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptRequest.params.name` property |
| **GetPromptResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptResult` model |
| GetPromptResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptResult._meta` property |
| GetPromptResult (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptResult.description` property |
| GetPromptResult (`messages`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.GetPromptResult.messages` property |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent` model |
| ImageContent (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.annotations` property |
| ImageContent (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.annotations.audience` property |
| ImageContent (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.annotations.priority` property |
| ImageContent (`data`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.data` property |
| ImageContent (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.mimeType` property |
| ImageContent (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ImageContent.type` property |
| **Implementation** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Implementation` model |
| Implementation (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Implementation.name` property |
| Implementation (`version`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Implementation.version` property |
| **InitializeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest` model |
| InitializeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest.method` property |
| InitializeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest.params` property |
| InitializeRequest (`params`) (`capabilities`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest.params.capabilities` property |
| InitializeRequest (`params`) (`clientInfo`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest.params.clientInfo` property |
| InitializeRequest (`params`) (`protocolVersion`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeRequest.params.protocolVersion` property |
| **InitializeResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult` model |
| InitializeResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult._meta` property |
| InitializeResult (`capabilities`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult.capabilities` property |
| InitializeResult (`instructions`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult.instructions` property |
| InitializeResult (`protocolVersion`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult.protocolVersion` property |
| InitializeResult (`serverInfo`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializeResult.serverInfo` property |
| **InitializedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializedNotification` model |
| InitializedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializedNotification.method` property |
| InitializedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializedNotification.params` property |
| InitializedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.InitializedNotification.params._meta` property |
| **JSONRPCError** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError` model |
| JSONRPCError (`error`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.error` property |
| JSONRPCError (`error`) (`code`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.error.code` property |
| JSONRPCError (`error`) (`data`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.error.data` property |
| JSONRPCError (`error`) (`message`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.error.message` property |
| JSONRPCError (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.id` property |
| JSONRPCError (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCError.jsonrpc` property |
| **JSONRPCMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCMessage` model |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCNotification` model |
| JSONRPCNotification (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCNotification.jsonrpc` property |
| JSONRPCNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCNotification.method` property |
| JSONRPCNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCNotification.params` property |
| JSONRPCNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCNotification.params._meta` property |
| **JSONRPCRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest` model |
| JSONRPCRequest (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.id` property |
| JSONRPCRequest (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.jsonrpc` property |
| JSONRPCRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.method` property |
| JSONRPCRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.params` property |
| JSONRPCRequest (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.params._meta` property |
| JSONRPCRequest (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCRequest.params._meta.progressToken` property |
| **JSONRPCResponse** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCResponse` model |
| JSONRPCResponse (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCResponse.id` property |
| JSONRPCResponse (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCResponse.jsonrpc` property |
| JSONRPCResponse (`result`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.JSONRPCResponse.result` property |
| **ListPromptsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsRequest` model |
| ListPromptsRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsRequest.method` property |
| ListPromptsRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsRequest.params` property |
| ListPromptsRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsRequest.params.cursor` property |
| **ListPromptsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsResult` model |
| ListPromptsResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsResult._meta` property |
| ListPromptsResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsResult.nextCursor` property |
| ListPromptsResult (`prompts`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListPromptsResult.prompts` property |
| **ListResourceTemplatesRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesRequest` model |
| ListResourceTemplatesRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesRequest.method` property |
| ListResourceTemplatesRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesRequest.params` property |
| ListResourceTemplatesRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesRequest.params.cursor` property |
| **ListResourceTemplatesResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesResult` model |
| ListResourceTemplatesResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesResult._meta` property |
| ListResourceTemplatesResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesResult.nextCursor` property |
| ListResourceTemplatesResult (`resourceTemplates`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourceTemplatesResult.resourceTemplates` property |
| **ListResourcesRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesRequest` model |
| ListResourcesRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesRequest.method` property |
| ListResourcesRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesRequest.params` property |
| ListResourcesRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesRequest.params.cursor` property |
| **ListResourcesResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesResult` model |
| ListResourcesResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesResult._meta` property |
| ListResourcesResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesResult.nextCursor` property |
| ListResourcesResult (`resources`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListResourcesResult.resources` property |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsRequest` model |
| ListRootsRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsRequest.method` property |
| ListRootsRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsRequest.params` property |
| ListRootsRequest (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsRequest.params._meta` property |
| ListRootsRequest (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsRequest.params._meta.progressToken` property |
| **ListRootsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsResult` model |
| ListRootsResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsResult._meta` property |
| ListRootsResult (`roots`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListRootsResult.roots` property |
| **ListToolsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsRequest` model |
| ListToolsRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsRequest.method` property |
| ListToolsRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsRequest.params` property |
| ListToolsRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsRequest.params.cursor` property |
| **ListToolsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsResult` model |
| ListToolsResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsResult._meta` property |
| ListToolsResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsResult.nextCursor` property |
| ListToolsResult (`tools`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ListToolsResult.tools` property |
| **LoggingLevel** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingLevel` model |
| **LoggingMessageNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification` model |
| LoggingMessageNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification.method` property |
| LoggingMessageNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification.params` property |
| LoggingMessageNotification (`params`) (`data`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification.params.data` property |
| LoggingMessageNotification (`params`) (`level`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification.params.level` property |
| LoggingMessageNotification (`params`) (`logger`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.LoggingMessageNotification.params.logger` property |
| **ModelHint** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelHint` model |
| ModelHint (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelHint.name` property |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelPreferences` model |
| ModelPreferences (`costPriority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelPreferences.costPriority` property |
| ModelPreferences (`hints`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelPreferences.hints` property |
| ModelPreferences (`intelligencePriority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelPreferences.intelligencePriority` property |
| ModelPreferences (`speedPriority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ModelPreferences.speedPriority` property |
| **Notification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Notification` model |
| Notification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Notification.method` property |
| Notification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Notification.params` property |
| Notification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Notification.params._meta` property |
| **PaginatedRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedRequest` model |
| PaginatedRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedRequest.method` property |
| PaginatedRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedRequest.params` property |
| PaginatedRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedRequest.params.cursor` property |
| **PaginatedResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedResult` model |
| PaginatedResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedResult._meta` property |
| PaginatedResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PaginatedResult.nextCursor` property |
| **PingRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PingRequest` model |
| PingRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PingRequest.method` property |
| PingRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PingRequest.params` property |
| PingRequest (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PingRequest.params._meta` property |
| PingRequest (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PingRequest.params._meta.progressToken` property |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification` model |
| ProgressNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification.method` property |
| ProgressNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification.params` property |
| ProgressNotification (`params`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification.params.progressToken` property |
| ProgressNotification (`params`) (`progress`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification.params.progress` property |
| ProgressNotification (`params`) (`total`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressNotification.params.total` property |
| **ProgressToken** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ProgressToken` model |
| **Prompt** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Prompt` model |
| Prompt (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Prompt.arguments` property |
| Prompt (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Prompt.description` property |
| Prompt (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Prompt.name` property |
| **PromptArgument** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptArgument` model |
| PromptArgument (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptArgument.description` property |
| PromptArgument (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptArgument.name` property |
| PromptArgument (`required`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptArgument.required` property |
| **PromptListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptListChangedNotification` model |
| PromptListChangedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptListChangedNotification.method` property |
| PromptListChangedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptListChangedNotification.params` property |
| PromptListChangedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptListChangedNotification.params._meta` property |
| **PromptMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptMessage` model |
| PromptMessage (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptMessage.content` property |
| PromptMessage (`role`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptMessage.role` property |
| **PromptReference** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptReference` model |
| PromptReference (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptReference.name` property |
| PromptReference (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.PromptReference.type` property |
| **ReadResourceRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceRequest` model |
| ReadResourceRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceRequest.method` property |
| ReadResourceRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceRequest.params` property |
| ReadResourceRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceRequest.params.uri` property |
| **ReadResourceResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceResult` model |
| ReadResourceResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceResult._meta` property |
| ReadResourceResult (`contents`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ReadResourceResult.contents` property |
| **Request** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Request` model |
| Request (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Request.method` property |
| Request (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Request.params` property |
| Request (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Request.params._meta` property |
| Request (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Request.params._meta.progressToken` property |
| **RequestId** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.RequestId` model |
| **Resource** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource` model |
| Resource (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.annotations` property |
| Resource (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.annotations.audience` property |
| Resource (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.annotations.priority` property |
| Resource (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.description` property |
| Resource (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.mimeType` property |
| Resource (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.name` property |
| Resource (`size`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.size` property |
| Resource (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Resource.uri` property |
| **ResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceContents` model |
| ResourceContents (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceContents.mimeType` property |
| ResourceContents (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceContents.uri` property |
| **ResourceListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceListChangedNotification` model |
| ResourceListChangedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceListChangedNotification.method` property |
| ResourceListChangedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceListChangedNotification.params` property |
| ResourceListChangedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceListChangedNotification.params._meta` property |
| **ResourceReference** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceReference` model |
| ResourceReference (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceReference.type` property |
| ResourceReference (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceReference.uri` property |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate` model |
| ResourceTemplate (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.annotations` property |
| ResourceTemplate (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.annotations.audience` property |
| ResourceTemplate (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.annotations.priority` property |
| ResourceTemplate (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.description` property |
| ResourceTemplate (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.mimeType` property |
| ResourceTemplate (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.name` property |
| ResourceTemplate (`uriTemplate`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceTemplate.uriTemplate` property |
| **ResourceUpdatedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceUpdatedNotification` model |
| ResourceUpdatedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceUpdatedNotification.method` property |
| ResourceUpdatedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceUpdatedNotification.params` property |
| ResourceUpdatedNotification (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ResourceUpdatedNotification.params.uri` property |
| **Result** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Result` model |
| Result (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Result._meta` property |
| **Role** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Role` model |
| **Root** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Root` model |
| Root (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Root.name` property |
| Root (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Root.uri` property |
| **RootsListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.RootsListChangedNotification` model |
| RootsListChangedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.RootsListChangedNotification.method` property |
| RootsListChangedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.RootsListChangedNotification.params` property |
| RootsListChangedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.RootsListChangedNotification.params._meta` property |
| **SamplingMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SamplingMessage` model |
| SamplingMessage (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SamplingMessage.content` property |
| SamplingMessage (`role`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SamplingMessage.role` property |
| **ServerCapabilities** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities` model |
| ServerCapabilities (`experimental`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.experimental` property |
| ServerCapabilities (`logging`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.logging` property |
| ServerCapabilities (`prompts`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.prompts` property |
| ServerCapabilities (`prompts`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.prompts.listChanged` property |
| ServerCapabilities (`resources`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.resources` property |
| ServerCapabilities (`resources`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.resources.listChanged` property |
| ServerCapabilities (`resources`) (`subscribe`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.resources.subscribe` property |
| ServerCapabilities (`tools`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.tools` property |
| ServerCapabilities (`tools`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerCapabilities.tools.listChanged` property |
| **ServerNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerNotification` model |
| **ServerRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerRequest` model |
| **ServerResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ServerResult` model |
| **SetLevelRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SetLevelRequest` model |
| SetLevelRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SetLevelRequest.method` property |
| SetLevelRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SetLevelRequest.params` property |
| SetLevelRequest (`params`) (`level`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SetLevelRequest.params.level` property |
| **SubscribeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SubscribeRequest` model |
| SubscribeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SubscribeRequest.method` property |
| SubscribeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SubscribeRequest.params` property |
| SubscribeRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.SubscribeRequest.params.uri` property |
| **TextContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent` model |
| TextContent (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent.annotations` property |
| TextContent (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent.annotations.audience` property |
| TextContent (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent.annotations.priority` property |
| TextContent (`text`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent.text` property |
| TextContent (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextContent.type` property |
| **TextResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextResourceContents` model |
| TextResourceContents (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextResourceContents.mimeType` property |
| TextResourceContents (`text`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextResourceContents.text` property |
| TextResourceContents (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.TextResourceContents.uri` property |
| **Tool** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool` model |
| Tool (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.description` property |
| Tool (`inputSchema`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.inputSchema` property |
| Tool (`inputSchema`) (`properties`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.inputSchema.properties` property |
| Tool (`inputSchema`) (`required`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.inputSchema.required` property |
| Tool (`inputSchema`) (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.inputSchema.type` property |
| Tool (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.Tool.name` property |
| **ToolListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ToolListChangedNotification` model |
| ToolListChangedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ToolListChangedNotification.method` property |
| ToolListChangedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ToolListChangedNotification.params` property |
| ToolListChangedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.ToolListChangedNotification.params._meta` property |
| **UnsubscribeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.UnsubscribeRequest` model |
| UnsubscribeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.UnsubscribeRequest.method` property |
| UnsubscribeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.UnsubscribeRequest.params` property |
| UnsubscribeRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | `MCP.UnsubscribeRequest.params.uri` property |
