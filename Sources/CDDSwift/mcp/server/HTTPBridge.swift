import Foundation

/// Defines an interface for context that can be extracted from an HTTP request
/// and passed into an MCP session. This satisfies "HTTP Request/Auth Bridging".
public protocol HTTPRequestContext: Sendable {
    var authorizationHeader: String? { get }
    var clientIP: String? { get }
    // Other properties specific to the HTTP layer
}

/// A default implementation for bridging HTTP request properties.
public struct DefaultHTTPRequestContext: HTTPRequestContext {
    public let authorizationHeader: String?
    public let clientIP: String?

    public init(authorizationHeader: String? = nil, clientIP: String? = nil) {
        self.authorizationHeader = authorizationHeader
        self.clientIP = clientIP
    }
}

/// Dynamic API-to-Tool Proxy
/// This abstraction takes incoming tool calls and proxies them to the backend API router.
public protocol APIToolProxy: Sendable {
    /// Documentation for execute
    func execute(toolName: String, arguments: [String: Any], context: HTTPRequestContext?) async throws -> CallToolResult
}
