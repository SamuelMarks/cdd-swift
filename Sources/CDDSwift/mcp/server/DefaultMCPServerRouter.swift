import Foundation

/// Documentation for DefaultMCPServerRouter
public struct DefaultMCPServerRouter: MCPServerRouter {
    public var requestHandlers: [String: @Sendable (JSONRPCRequest<AnyCodable>) async throws -> AnyCodable] = [:]
    public var notificationHandlers: [String: @Sendable (JSONRPCNotification<AnyCodable>) async throws -> Void] = [:]

    public init() {}

    /// Documentation for handleRequest
    public func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
        if let handler = requestHandlers[request.method] {
            return try await handler(request)
        }
        throw JSONRPCErrorDetail(code: .methodNotFound, message: "Method '\(request.method)' not found")
    }

    /// Documentation for handleNotification
    public func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws {
        if let handler = notificationHandlers[notification.method] {
            try await handler(notification)
        }
    }
}
