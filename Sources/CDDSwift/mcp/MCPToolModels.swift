/// Model Context Protocol (MCP) tool definition, invocation, and listing models.
import Foundation

/// Definition for a tool the client can call on an MCP server.
public struct Tool: Codable, Equatable, Sendable {
    /// Unique identifier name of the tool.
    public let name: String
    /// Human-readable description of what the tool does.
    public let description: String?
    /// JSON Schema object defining the expected parameters for the tool.
    public let inputSchema: ToolInputSchema

    /// Initializes a `Tool` definition.
    ///
    /// - Parameters:
    ///   - name: The unique tool identifier.
    ///   - description: Optional explanation of the tool's behavior.
    ///   - inputSchema: The JSON Schema for the tool's input arguments.
    public init(name: String, description: String? = nil, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema describing the input object accepted by an MCP `Tool`.
public struct ToolInputSchema: Codable, Equatable, Sendable {
    /// Root schema type (typically `"object"`).
    public let type: String
    /// Map of parameter names to their JSON Schema definitions.
    public let properties: [String: AnyCodable]?
    /// List of required parameter names.
    public let required: [String]?

    /// Initializes a `ToolInputSchema`.
    ///
    /// - Parameters:
    ///   - type: The root JSON Schema type (e.g. `"object"`).
    ///   - properties: Optional map of property definitions.
    ///   - required: Optional list of required property names.
    public init(type: String, properties: [String: AnyCodable]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Parameters for a `tools/call` request invoking a server tool.
public struct CallToolRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// The name of the tool to invoke.
    public let name: String
    /// Key-value arguments passed to the tool.
    public let arguments: [String: AnyCodable]?

    /// Initializes `CallToolRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - name: The target tool name.
    ///   - arguments: Optional map of argument names to values.
    public init(_meta: Meta? = nil, name: String, arguments: [String: AnyCodable]? = nil) {
        self._meta = _meta
        self.name = name
        self.arguments = arguments
    }
}

/// Result returned by the server in response to a `tools/call` request.
public struct CallToolResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Array of content blocks (text, image, or embedded resources) produced by the tool.
    public let content: [AnyCodable]
    /// Whether the tool call ended in an application-level execution error.
    public let isError: Bool?

    /// Initializes a `CallToolResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - content: Array of output content items.
    ///   - isError: Optional flag indicating whether the tool execution failed.
    public init(_meta: Meta? = nil, content: [AnyCodable], isError: Bool? = nil) {
        self._meta = _meta
        self.content = content
        self.isError = isError
    }
}

/// Parameters for a paginated `tools/list` request.
public struct ListToolsRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// Opaque pagination cursor from a previous `ListToolsResult`.
    public let cursor: String?

    /// Initializes `ListToolsRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - cursor: Optional pagination cursor string.
    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// Result returned by a `tools/list` request containing available server tools.
public struct ListToolsResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Opaque cursor for fetching the next page of tools, if more exist.
    public let nextCursor: String?
    /// The list of available `Tool` definitions for this page.
    public let tools: [Tool]

    /// Initializes a `ListToolsResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - nextCursor: Optional pagination cursor for the next page.
    ///   - tools: Array of `Tool` descriptors.
    public init(_meta: Meta? = nil, nextCursor: String? = nil, tools: [Tool]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.tools = tools
    }
}

/// Parameters for a `notifications/tools/list_changed` notification.
public struct ToolListChangedNotificationParams: Codable, Equatable, Sendable {
    /// Optional notification metadata.
    public let _meta: Meta?

    /// Initializes `ToolListChangedNotificationParams`.
    ///
    /// - Parameter _meta: Optional notification metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}
