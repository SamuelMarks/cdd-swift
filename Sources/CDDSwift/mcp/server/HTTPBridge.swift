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

    /// Initializes a `DefaultHTTPRequestContext` by extracting `Authorization` and forwarded IP headers from a raw HTTP header map.
    ///
    /// - Parameters:
    ///   - headers: Dictionary of HTTP header names to values.
    ///   - clientIP: Optional explicit client IP address override.
    public init(headers: [String: String], clientIP: String? = nil) {
        var resolvedAuth: String?
        var forwardedIP: String?
        for (key, value) in headers {
            let lower = key.lowercased()
            if lower == "authorization" {
                resolvedAuth = value
            } else if lower == "x-forwarded-for" || lower == "x-real-ip" {
                forwardedIP = value.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        authorizationHeader = resolvedAuth
        self.clientIP = clientIP ?? forwardedIP
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

/// Concrete `APIToolProxy` implementation that resolves incoming MCP tool calls to registered backend route handlers and bridges
/// `HTTPRequestContext` into a `DefaultMCPServerRouter`.
public struct DynamicAPIToolProxy: APIToolProxy, Sendable {
    /// Asynchronous route handler signature receiving tool arguments and optional HTTP request context.
    public typealias RouteToolHandler = @Sendable ([String: AnyCodable], HTTPRequestContext?) async throws -> CallToolResult

    /// Exposed MCP tool definitions.
    public let tools: [Tool]
    /// Registered route handlers keyed by MCP tool name.
    private let handlers: [String: RouteToolHandler]

    /// Initializes a `DynamicAPIToolProxy`.
    ///
    /// - Parameters:
    ///   - tools: Array of MCP `Tool` descriptors advertised via `tools/list`.
    ///   - handlers: Dictionary mapping tool names to backend `RouteToolHandler` closures.
    public init(tools: [Tool] = [], handlers: [String: RouteToolHandler] = [:]) {
        self.tools = tools
        self.handlers = handlers
    }

    /// Resolves `toolName` to its registered backend route handler and executes it with `arguments` and `context`.
    ///
    /// - Parameters:
    ///   - toolName: The name of the MCP tool being invoked.
    ///   - arguments: Dictionary of input arguments passed to the tool.
    ///   - context: Optional `HTTPRequestContext` carrying authentication headers and client IP.
    /// - Returns: The `CallToolResult` produced by the route handler.
    /// - Throws: `JSONRPCErrorDetail` with `.methodNotFound` if `toolName` is not registered, or any error thrown by the handler.
    public func execute(toolName: String, arguments: [String: AnyCodable], context: HTTPRequestContext?) async throws -> CallToolResult {
        guard let handler = handlers[toolName] else {
            throw JSONRPCErrorDetail(code: .methodNotFound, message: "Tool '\(toolName)' not found")
        }
        return try await handler(arguments, context)
    }

    /// Constructs a `DefaultMCPServerRouter` wiring `tools/list` and `tools/call` to this proxy with the given `HTTPRequestContext`.
    ///
    /// - Parameter context: Optional `HTTPRequestContext` propagated into `tools/call` invocations.
    /// - Returns: A configured `DefaultMCPServerRouter`.
    public func makeRouter(context: HTTPRequestContext? = nil) -> DefaultMCPServerRouter {
        var router = DefaultMCPServerRouter()
        let proxy = self
        router.requestHandlers["tools/list"] = { _ in
            let listResult = ListToolsResult(tools: proxy.tools)
            let data = try JSONEncoder().encode(listResult)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }
        router.requestHandlers["tools/call"] = { request in
            guard let params = request.params,
                  let paramsData = try? JSONEncoder().encode(params),
                  let callParams = try? JSONDecoder().decode(CallToolRequestParams.self, from: paramsData)
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Invalid tools/call parameters")
            }
            let result = try await proxy.execute(
                toolName: callParams.name,
                arguments: callParams.arguments ?? [:],
                context: context
            )
            let data = try JSONEncoder().encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }
        return router
    }
}
