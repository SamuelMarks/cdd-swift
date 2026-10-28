/// Default dictionary-backed router implementation for `MCPServerRouter`.

/// A configurable dictionary-backed router for handling incoming MCP server requests and notifications.
public struct DefaultMCPServerRouter: MCPServerRouter {
    /// Registered asynchronous handlers keyed by JSON-RPC request method name.
    public var requestHandlers: [String: @Sendable (JSONRPCRequest<AnyCodable>) async throws -> AnyCodable] = [:]
    /// Registered asynchronous handlers keyed by JSON-RPC notification method name.
    public var notificationHandlers: [String: @Sendable (JSONRPCNotification<AnyCodable>) async throws -> Void] = [:]

    /// Initializes an empty `DefaultMCPServerRouter`.
    public init() {}

    /// Dispatches an incoming JSON-RPC request to the registered handler for `request.method`.
    ///
    /// - Parameter request: The incoming `JSONRPCRequest` envelope.
    /// - Returns: The `AnyCodable` result produced by the registered handler.
    /// - Throws: `JSONRPCErrorDetail` with `.methodNotFound` if no handler is registered for `request.method`, or any error thrown by the
    /// handler.
    public func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
        if let handler = requestHandlers[request.method] {
            return try await handler(request)
        }
        throw JSONRPCErrorDetail(code: .methodNotFound, message: "Method '\(request.method)' not found")
    }

    /// Dispatches an incoming JSON-RPC notification to the registered handler for `notification.method`, if any.
    ///
    /// - Parameter notification: The incoming `JSONRPCNotification` envelope.
    /// - Throws: Any error thrown by the registered notification handler.
    public func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws {
        if let handler = notificationHandlers[notification.method] {
            try await handler(notification)
        }
    }
}
