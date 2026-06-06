import Foundation

/// A router for handling MCP Server incoming requests and notifications
public protocol MCPServerRouter: Sendable {
    func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable
    func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws
}

public actor MCPServerSession {
    private let transport: MCPTransport
    private let router: MCPServerRouter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingRequests: [JSONRPCId: Continuation] = [:]

    private struct Continuation {
        // We'll use this when the server sends requests to the client and awaits a response.
        // For now, the server mainly handles requests from the client.
    }

    public init(transport: MCPTransport, router: MCPServerRouter) {
        self.transport = transport
        self.router = router
        encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    public func start() async throws {
        try await transport.start { [weak self] data in
            guard let self = self else { return }
            Task {
                await self.processIncomingData(data)
            }
        }
    }

    public func close() async throws {
        try await transport.close()
    }

    private func processIncomingData(_ data: Data) async {
        // Try decoding as a Request first
        if let request = try? decoder.decode(JSONRPCRequest<AnyCodable>.self, from: data) {
            await handleRequest(request)
            return
        }

        // Try decoding as Notification
        if let notification = try? decoder.decode(JSONRPCNotification<AnyCodable>.self, from: data) {
            await handleNotification(notification)
            return
        }

        // Try decoding as Response (if we sent requests to the client)
        if let response = try? decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data) {
            await handleResponse(response)
            return
        }

        if let error = try? decoder.decode(JSONRPCError.self, from: data) {
            await handleError(error)
            return
        }
    }

    private func handleRequest(_ request: JSONRPCRequest<AnyCodable>) async {
        let reqId = request.id
        do {
            let result = try await router.handleRequest(request: request)
            let response = JSONRPCResponse(id: reqId, result: result)
            try await transport.send(response)
        } catch let error as JSONRPCErrorDetail {
            let response = JSONRPCError(id: reqId, error: error)
            try? await transport.send(response)
        } catch {
            let errorDetail = JSONRPCErrorDetail(code: JSONRPCErrorCode.internalError, message: error.localizedDescription)
            let response = JSONRPCError(id: reqId, error: errorDetail)
            try? await transport.send(response)
        }
    }

    private func handleNotification(_ notification: JSONRPCNotification<AnyCodable>) async {
        do {
            try await router.handleNotification(notification: notification)
        } catch {
            // Notifications don't get responses, but we could log
        }
    }

    private func handleResponse(_: JSONRPCResponse<AnyCodable>) async {
        // Handle responses to requests we sent
    }

    private func handleError(_: JSONRPCError) async {
        // Handle error responses to requests we sent
    }
}
