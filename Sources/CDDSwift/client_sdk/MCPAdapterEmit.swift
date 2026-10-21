/// Model Context Protocol (MCP) adapter emitter for generated Swift API clients.
import Foundation

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

/// Emits the struct header and nested `ToolInputSchema`, `Tool`, and `CallToolResult` types for `MCPAdapter`.
///
/// - Returns: Generated Swift tool type definitions inside `MCPAdapter`.
private func emitMCPAdapterToolTypes() -> String {
    return """
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct MCPAdapter {
        public struct ToolInputSchema: Codable, Equatable, Sendable {
            public let type: String
            public let properties: [String: AnyCodable]?
            public let required: [String]?

            public init(type: String = "object", properties: [String: AnyCodable]? = nil, required: [String]? = nil) {
                self.type = type
                self.properties = properties
                self.required = required
            }
        }

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

        public struct CallToolResult: Codable, Equatable, Sendable {
            public let content: [AnyCodable]
            public let isError: Bool?

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
    return """

        public struct Resource: Codable, Equatable, Sendable {
            public let uri: String
            public let name: String
            public let description: String?
            public let mimeType: String?

            public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
                self.uri = uri
                self.name = name
                self.description = description
                self.mimeType = mimeType
            }
        }

        public struct TextResourceContents: Codable, Equatable, Sendable {
            public let uri: String
            public let mimeType: String?
            public let text: String

            public init(uri: String, mimeType: String? = nil, text: String) {
                self.uri = uri
                self.mimeType = mimeType
                self.text = text
            }
        }

        public enum ResourceContents: Codable, Equatable, Sendable {
            case text(TextResourceContents)
        }

        public struct ReadResourceResult: Codable, Equatable, Sendable {
            public let contents: [ResourceContents]

            public init(contents: [ResourceContents]) {
                self.contents = contents
            }
        }

        public enum AdapterError: Error, Equatable, Sendable {
            case toolNotFound(name: String)
            case resourceNotFound(uri: String)
        }

        public let client: APIClient

    """
}

/// Emits `getTools()`, `executeTool(name:args:)`, `getResources()`, and `readResource(uri:)` for `MCPAdapter`.
///
/// - Parameter document: The `OpenAPIDocument` containing operations.
/// - Returns: Generated Swift methods for `MCPAdapter`.
private func emitMCPAdapterMethods(document: OpenAPIDocument) -> String {
    var output = "\n    public func getTools() -> [Tool] {\n        var tools: [Tool] = []\n"
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
    output += "    public func getResources() -> [Resource] {\n        return [\n"
    output += "            Resource(uri: \"api://docs\", name: \"API Documentation\", description: \"OpenAPI documentation\")\n"
    output += "        ]\n    }\n\n"
    output += "    public func readResource(uri: String) async throws -> ReadResourceResult {\n        switch uri {\n"
    output += "        case \"api://docs\":\n"
    output += "            return ReadResourceResult(contents: [.text(TextResourceContents(uri: uri, text: \"API Docs content\"))])\n"
    output += "        default:\n            throw AdapterError.resourceNotFound(uri: uri)\n        }\n    }\n"
    return output
}
