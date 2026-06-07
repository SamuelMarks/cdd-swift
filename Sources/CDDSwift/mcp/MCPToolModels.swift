import Foundation

/// Definition for a tool the client can call.
public struct Tool: Codable, Equatable, Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: ToolInputSchema

    public init(name: String, description: String? = nil, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for the tool input.
public struct ToolInputSchema: Codable, Equatable, Sendable {
    public let type: String
    public let properties: [String: AnyCodable]?
    public let required: [String]?

    public init(type: String, properties: [String: AnyCodable]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// CallToolRequest parameters.
public struct CallToolRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let name: String
    public let arguments: [String: AnyCodable]?

    public init(_meta: Meta? = nil, name: String, arguments: [String: AnyCodable]? = nil) {
        self._meta = _meta
        self.name = name
        self.arguments = arguments
    }
}

/// Content returned by tools.
public struct CallToolResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let content: [AnyCodable]
    public let isError: Bool?

    public init(_meta: Meta? = nil, content: [AnyCodable], isError: Bool? = nil) {
        self._meta = _meta
        self.content = content
        self.isError = isError
    }
}

/// ListToolsRequest parameters.
public struct ListToolsRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let cursor: String?

    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// ListToolsResult.
public struct ListToolsResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let nextCursor: String?
    public let tools: [Tool]

    public init(_meta: Meta? = nil, nextCursor: String? = nil, tools: [Tool]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.tools = tools
    }
}

/// ToolListChangedNotification params.
public struct ToolListChangedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}
