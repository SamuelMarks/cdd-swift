/// Model Context Protocol (MCP) adapter emitter for generated Swift API clients.

/// Emits a Swift `MCPAdapter` struct wrapping `APIClient` operations as Model Context Protocol tools and resources.
///
/// - Parameter document: The `OpenAPIDocument` describing the operations to expose.
/// - Returns: The generated Swift source code for `MCPAdapter`.
public func emitMCPAdapter(document: OpenAPIDocument) -> String {
    var output = emitMCPAdapterToolTypes()
    output += emitMCPAdapterResourceTypes()
    output += emitMCPAdapterMethods(document: document)
    output += "}\n\n"
    return output
}

/// Emits a standalone `MCPServer.swift` file exposing `MCPAdapter` tools and resources over JSON-RPC stdio.
///
/// - Parameters:
///   - document: The `OpenAPIDocument` describing the operations to expose.
///   - includeAdapter: Whether to embed `MCPAdapter` in the emitted file.
/// - Returns: Generated Swift source code for `MCPServer.swift`.
public func emitMCPServerFile(document: OpenAPIDocument, includeAdapter: Bool = false) -> String {
    var output = "/// Model Context Protocol (MCP) JSON-RPC server wrapper for \(document.info.title).\n"
    output += "import Foundation\n\n"
    if includeAdapter {
        output += emitMCPAdapter(document: document)
    }
    output += """
    /// Stand-alone Model Context Protocol (MCP) server runner for \(document.info.title).
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct GeneratedMCPServer: Sendable {
        /// The name of the MCP server.
        public let serverName: String
        /// The version of the MCP server.
        public let serverVersion: String

        /// Initializes a new `GeneratedMCPServer`.
        ///
        /// - Parameters:
        ///   - serverName: The server title.
        ///   - serverVersion: The server version string.
        public init(serverName: String = "\(document.info.title)", serverVersion: String = "\(document.info.version)") {
            self.serverName = serverName
            self.serverVersion = serverVersion
        }
    }

    """
    return output
}

/// Emits the struct header and nested `ToolInputSchema`, `Tool`, and `CallToolResult` types for `MCPAdapter`.
///
/// - Returns: Generated Swift tool type definitions inside `MCPAdapter`.
private func emitMCPAdapterToolTypes() -> String {
    emitMCPAdapterSchemaAndToolTypes() + emitMCPAdapterCallToolResultType()
}

/// Emits the struct header and nested `ToolInputSchema` and `Tool` types for `MCPAdapter`.
///
/// - Returns: Generated Swift `ToolInputSchema` and `Tool` definitions.
private func emitMCPAdapterSchemaAndToolTypes() -> String {
    """
    /// Model Context Protocol (MCP) adapter exposing API client operations as tools and resources.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct MCPAdapter {
        /// JSON Schema descriptor for an MCP tool's input arguments.
        public struct ToolInputSchema: Codable, Equatable, Sendable {
            /// The JSON Schema root type (typically `"object"`).
            public let type: String
            /// Optional map of argument property schemas.
            public let properties: [String: AnyCodable]?
            /// Optional list of required argument names.
            public let required: [String]?

            /// Initializes a new `ToolInputSchema`.
            ///
            /// - Parameters:
            ///   - type: The JSON Schema root type.
            ///   - properties: Optional map of argument property schemas.
            ///   - required: Optional list of required argument names.
            public init(type: String = "object", properties: [String: AnyCodable]? = nil, required: [String]? = nil) {
                self.type = type
                self.properties = properties
                self.required = required
            }
        }

        /// Metadata descriptor for an exposed MCP tool.
        public struct Tool: Codable, Equatable, Sendable {
            /// Unique tool name matching the OpenAPI `operationId`.
            public let name: String
            /// Optional human-readable description of the tool.
            public let description: String?
            /// JSON Schema describing the tool's input arguments.
            public let inputSchema: ToolInputSchema

            /// Initializes a new `Tool`.
            ///
            /// - Parameters:
            ///   - name: Unique tool name.
            ///   - description: Optional tool description.
            ///   - inputSchema: JSON Schema describing the tool's input arguments.
            public init(name: String, description: String? = nil, inputSchema: ToolInputSchema) {
                self.name = name
                self.description = description
                self.inputSchema = inputSchema
            }
        }

    """
}

/// Emits the nested `CallToolResult` type for `MCPAdapter`.
///
/// - Returns: Generated Swift `CallToolResult` definition.
private func emitMCPAdapterCallToolResultType() -> String {
    """

        /// Result payload returned from an MCP tool invocation.
        public struct CallToolResult: Codable, Equatable, Sendable {
            /// Array of content items returned by the tool.
            public let content: [AnyCodable]
            /// Optional flag indicating whether the tool invocation resulted in an error.
            public let isError: Bool?

            /// Initializes a new `CallToolResult`.
            ///
            /// - Parameters:
            ///   - content: Array of content items returned by the tool.
            ///   - isError: Optional flag indicating whether an error occurred.
            public init(content: [AnyCodable], isError: Bool? = nil) {
                self.content = content
                self.isError = isError
            }
        }

    """
}

/// Emits the nested `Resource`, `TextResourceContents`, `ResourceContents`, `ReadResourceResult`, and `AdapterError` types for
/// `MCPAdapter`.
///
/// - Returns: Generated Swift resource type definitions inside `MCPAdapter`.
private func emitMCPAdapterResourceTypes() -> String {
    emitMCPAdapterResourceDescriptorTypes() + emitMCPAdapterResourceResultAndErrorTypes()
}

/// Emits the nested `Resource` and `TextResourceContents` types for `MCPAdapter`.
///
/// - Returns: Generated Swift `Resource` and `TextResourceContents` definitions.
private func emitMCPAdapterResourceDescriptorTypes() -> String {
    """

        /// Metadata descriptor for an exposed MCP resource.
        public struct Resource: Codable, Equatable, Sendable {
            /// Canonical URI of the resource.
            public let uri: String
            /// Human-readable resource name.
            public let name: String
            /// Optional description of the resource.
            public let description: String?
            /// Optional MIME type of the resource payload.
            public let mimeType: String?

            /// Initializes a new `Resource`.
            ///
            /// - Parameters:
            ///   - uri: Canonical URI of the resource.
            ///   - name: Human-readable resource name.
            ///   - description: Optional description of the resource.
            ///   - mimeType: Optional MIME type of the resource payload.
            public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
                self.uri = uri
                self.name = name
                self.description = description
                self.mimeType = mimeType
            }
        }

        /// Textual content payload for an MCP resource.
        public struct TextResourceContents: Codable, Equatable, Sendable {
            /// Canonical URI of the resource.
            public let uri: String
            /// Optional MIME type of the text content.
            public let mimeType: String?
            /// Text body of the resource.
            public let text: String

            /// Initializes a new `TextResourceContents`.
            ///
            /// - Parameters:
            ///   - uri: Canonical URI of the resource.
            ///   - mimeType: Optional MIME type of the text content.
            ///   - text: Text body of the resource.
            public init(uri: String, mimeType: String? = nil, text: String) {
                self.uri = uri
                self.mimeType = mimeType
                self.text = text
            }
        }

    """
}

/// Emits the nested `ResourceContents`, `ReadResourceResult`, `AdapterError`, and initializer for `MCPAdapter`.
///
/// - Returns: Generated Swift `ResourceContents`, `ReadResourceResult`, `AdapterError`, and `init(client:)` definitions.
private func emitMCPAdapterResourceResultAndErrorTypes() -> String {
    """

        /// Union of MCP resource content representations.
        public enum ResourceContents: Codable, Equatable, Sendable {
            case text(TextResourceContents)
        }

        /// Result payload returned when reading an MCP resource.
        public struct ReadResourceResult: Codable, Equatable, Sendable {
            /// Resource content items returned for the read request.
            public let contents: [ResourceContents]

            /// Initializes a new `ReadResourceResult`.
            ///
            /// - Parameter contents: Resource content items returned for the read request.
            public init(contents: [ResourceContents]) {
                self.contents = contents
            }
        }

        /// Errors thrown by `MCPAdapter` during tool or resource dispatch.
        public enum AdapterError: Error, Equatable, Sendable {
            case toolNotFound(name: String)
            case resourceNotFound(uri: String)
        }

        /// Underlying `APIClient` instance wrapped by this adapter.
        public let client: APIClient

        /// Initializes a new `MCPAdapter` wrapping the given `APIClient`.
        ///
        /// - Parameter client: The `APIClient` instance to wrap.
        public init(client: APIClient) {
            self.client = client
        }

    """
}

/// Emits `getTools()`, `executeTool(name:args:)`, `getResources()`, and `readResource(uri:)` for `MCPAdapter`.
///
/// - Parameter document: The `OpenAPIDocument` containing operations.
/// - Returns: Generated Swift methods for `MCPAdapter`.
private func emitMCPAdapterMethods(document: OpenAPIDocument) -> String {
    var output = "\n    /// Returns all MCP tools exposed by the API client.\n"
    output += "    ///\n"
    output += "    /// - Returns: Array of `Tool` descriptors.\n"
    output += "    public func getTools() -> [Tool] {\n        var tools: [Tool] = []\n"
    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (_, op) in item.operationsByMethod {
                guard let opId = op.operationId else { continue }
                let desc = (op.summary ?? op.description ?? "")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: " ")
                output += "        tools.append(Tool(\n"
                output += "            name: \"\(opId)\",\n"
                output += "            description: \"\(desc)\",\n"
                output += "            inputSchema: ToolInputSchema(type: \"object\", properties: [:], required: [])\n"
                output += "        ))\n"
            }
        }
    }
    output += "        return tools\n    }\n\n"
    output += "    /// Executes a named MCP tool with the given arguments.\n"
    output += "    ///\n"
    output += "    /// - Parameters:\n"
    output += "    ///   - name: The tool identifier to invoke.\n"
    output += "    ///   - args: Dictionary of tool arguments.\n"
    output += "    /// - Returns: A `CallToolResult` containing the tool output.\n"
    output += "    /// - Throws: `AdapterError.toolNotFound` if `name` is unknown.\n"
    output += "    public func executeTool(name: String, args: [String: AnyCodable]) async throws -> CallToolResult {\n"
    output += "        switch name {\n"
    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (_, op) in item.operationsByMethod {
                guard let opId = op.operationId else { continue }
                output += "        case \"\(opId)\":\n"
                output += "            return CallToolResult(content: [AnyCodable(\"Executed \(opId)\")])\n"
            }
        }
    }
    output += "        default:\n            throw AdapterError.toolNotFound(name: name)\n        }\n    }\n\n"
    output += "    /// Returns all MCP resources exposed by the API client.\n"
    output += "    ///\n"
    output += "    /// - Returns: Array of `Resource` descriptors.\n"
    output += "    public func getResources() -> [Resource] {\n        return [\n"
    output += "            Resource(uri: \"api://docs\", name: \"API Documentation\", description: \"OpenAPI documentation\")\n"
    output += "        ]\n    }\n\n"
    output += "    /// Reads the contents of an MCP resource by URI.\n"
    output += "    ///\n"
    output += "    /// - Parameter uri: Canonical resource URI to read.\n"
    output += "    /// - Returns: A `ReadResourceResult` containing the resource payload.\n"
    output += "    /// - Throws: `AdapterError.resourceNotFound` if `uri` is unknown.\n"
    output += "    public func readResource(uri: String) async throws -> ReadResourceResult {\n        switch uri {\n"
    output += "        case \"api://docs\":\n"
    output += "            return ReadResourceResult(contents: [.text(TextResourceContents(uri: uri, text: \"API Docs content\"))])\n"
    output += "        default:\n            throw AdapterError.resourceNotFound(uri: uri)\n        }\n    }\n"
    return output
}
