/// HTTP authentication context and dynamic API-to-Tool proxy abstractions for MCP servers.
import Foundation

/// Defines an interface for authentication and client metadata extracted from an HTTP request
/// and bridged into an active Model Context Protocol (MCP) session.
public protocol HTTPRequestContext: Sendable {
    /// The raw HTTP `Authorization` header value, if present.
    var authorizationHeader: String? { get }
    /// The originating client IP address, if known.
    var clientIP: String? { get }
}

/// A default value-type implementation of `HTTPRequestContext` for bridging HTTP request properties.
public struct DefaultHTTPRequestContext: HTTPRequestContext {
    /// The raw HTTP `Authorization` header value, if present.
    public let authorizationHeader: String?
    /// The originating client IP address, if known.
    public let clientIP: String?

    /// Initializes a `DefaultHTTPRequestContext`.
    ///
    /// - Parameters:
    ///   - authorizationHeader: Optional HTTP `Authorization` header string.
    ///   - clientIP: Optional client IP address string.
    public init(authorizationHeader: String? = nil, clientIP: String? = nil) {
        self.authorizationHeader = authorizationHeader
        self.clientIP = clientIP
    }
}

/// Dynamic API-to-Tool proxy protocol that translates incoming MCP tool invocations into backend API calls.
public protocol APIToolProxy: Sendable {
    /// Executes a named tool with the given arguments and optional HTTP request context.
    ///
    /// - Parameters:
    ///   - toolName: The name of the MCP tool being invoked.
    ///   - arguments: Strongly-typed dictionary of `AnyCodable` input arguments passed to the tool.
    ///   - context: Optional `HTTPRequestContext` carrying authentication headers and client metadata.
    /// - Returns: A `CallToolResult` containing the tool's response content.
    /// - Throws: An error if the tool does not exist or execution fails.
    func execute(toolName: String, arguments: [String: AnyCodable], context: HTTPRequestContext?) async throws -> CallToolResult
}
