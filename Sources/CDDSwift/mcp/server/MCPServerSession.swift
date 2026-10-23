/// Model Context Protocol (MCP) server session actor and server-side routing protocol.
import Foundation

/// A router for handling incoming client JSON-RPC requests and notifications on an MCP server.
public protocol MCPServerRouter: Sendable {
    /// Handles an incoming JSON-RPC request sent by the MCP client to the server.
    ///
    /// - Parameter request: The incoming `JSONRPCRequest` envelope.
    /// - Returns: The `AnyCodable` result payload to send back to the client.
    /// - Throws: `JSONRPCErrorDetail` or any error if handling the request fails.
    func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable
    /// Handles an incoming JSON-RPC notification sent by the MCP client to the server.
    ///
    /// - Parameter notification: The incoming `JSONRPCNotification` envelope.
    /// - Throws: An error if processing the notification fails.
    func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws
}

/// Actor managing an active Model Context Protocol (MCP) server session over an `MCPTransport`.
public actor MCPServerSession {
    /// Underlying bidirectional message transport.
    private let transport: MCPTransport
    /// Router dispatching client requests and notifications.
    private let router: MCPServerRouter
    /// JSON encoder for serializing outgoing responses and server requests.
    private let encoder: JSONEncoder
    /// JSON decoder for deserializing incoming frames.
    private let decoder: JSONDecoder
    /// Map of in-flight server-to-client request IDs to their awaiting continuations.
    private var pendingRequests: [JSONRPCId: Continuation] = [:]
    /// Map of active client request IDs to their executing `Task` instances for cancellation support.
    private var runningTasks: [JSONRPCId: Task<Void, Never>] = [:]
    /// Monotonically increasing counter for server-initiated request IDs.
    private var nextRequestId: Int = 1

    /// Pair of closures used to resolve or reject an awaiting server-to-client request continuation.
    private struct Continuation {
        /// Closure invoked when a matching `JSONRPCResponse` arrives from the client.
        let resolve: (AnyCodable) -> Void
        /// Closure invoked when a matching `JSONRPCError` or transport failure occurs.
        let reject: (Error) -> Void
    }

    /// Initializes an `MCPServerSession`.
    ///
    /// - Parameters:
    ///   - transport: The `MCPTransport` used for sending and receiving JSON-RPC frames.
    ///   - router: The `MCPServerRouter` handling client requests and notifications.
    public init(transport: MCPTransport, router: MCPServerRouter) {
        self.transport = transport
        self.router = router
        encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    /// Starts the underlying transport and begins processing incoming JSON-RPC frames.
    ///
    /// - Throws: An error if the transport fails to start.
    public func start() async throws {
        try await transport.start { [weak self] data in
            guard let self else { return }
            await processIncomingData(data)
        }
    }

    /// Closes the transport, cancels all running request tasks, and fails pending server-to-client requests.
    ///
    /// - Throws: An error if closing the transport fails.
    public func close() async throws {
        try await transport.close()
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
        for continuation in pendingRequests.values {
            continuation.reject(CancellationError())
        }
        pendingRequests.removeAll()
    }

    /// Sends a server-initiated JSON-RPC request to the client and awaits the client's response.
    ///
    /// - Parameters:
    ///   - method: The JSON-RPC method name to invoke on the client.
    ///   - params: Optional structured parameters for the method.
    /// - Returns: The `AnyCodable` result returned by the client.
    /// - Throws: `JSONRPCErrorDetail` or a transport error if the request fails.
    public func sendRequest(method: String, params: (some Codable & Sendable)?) async throws -> AnyCodable {
        let reqId = JSONRPCId.integer(nextRequestId)
        nextRequestId += 1

        let request = JSONRPCRequest(id: reqId, method: method, params: params)
        return try await withCheckedThrowingContinuation { continuation in
            let cont = Continuation(
                resolve: { result in continuation.resume(returning: result) },
                reject: { error in continuation.resume(throwing: error) }
            )
            self.pendingRequests[reqId] = cont

            Task {
                do {
                    try await self.transport.send(request)
                } catch {
                    self.failPendingRequest(id: reqId, error: error)
                }
            }
        }
    }

    /// Removes and fails a pending request continuation when transmission fails.
    ///
    /// - Parameters:
    ///   - id: The `JSONRPCId` of the failed request.
    ///   - error: The error to resume the continuation with.
    private func failPendingRequest(id: JSONRPCId, error: Error) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(error)
        }
    }

    /// Sends a one-way JSON-RPC notification from the server to the client.
    ///
    /// - Parameters:
    ///   - method: The notification method name.
    ///   - params: Optional structured parameters for the notification.
    /// - Throws: An error if encoding or transmitting the notification fails.
    public func sendNotification(method: String, params: (some Codable & Sendable)?) async throws {
        let notification = JSONRPCNotification(method: method, params: params)
        try await transport.send(notification)
    }

    /// Sends a `notifications/progress` update to the client for an active progress token.
    ///
    /// - Parameters:
    ///   - progressToken: The `ProgressToken` identifying the operation.
    ///   - progress: Current progress value.
    ///   - total: Optional total expected progress value.
    /// - Throws: An error if transmitting the notification fails.
    public func sendProgress(progressToken: ProgressToken, progress: Double, total: Double? = nil) async throws {
        let params = ProgressNotificationParams(progressToken: progressToken, progress: progress, total: total)
        try await sendNotification(method: "notifications/progress", params: params)
    }

    /// Decodes a raw incoming JSON-RPC frame and dispatches it to the appropriate handler.
    ///
    /// - Parameter data: Raw UTF-8 JSON bytes received from the transport.
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

        // Try decoding as Error first since Response has an optional result and would incorrectly decode errors
        if let error = try? decoder.decode(JSONRPCError.self, from: data) {
            await handleError(error)
            return
        }

        // Try decoding as Response (if we sent requests to the client)
        if let response = try? decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data) {
            await handleResponse(response)
            return
        }
    }

    /// Spawns a cancellable task to handle an incoming client `JSONRPCRequest` and transmit the response.
    ///
    /// - Parameter request: The decoded `JSONRPCRequest` from the client.
    private func handleRequest(_ request: JSONRPCRequest<AnyCodable>) async {
        let reqId = request.id
        let task = Task {
            do {
                let result = try await router.handleRequest(request: request)
                guard !Task.isCancelled else { return }
                let response = JSONRPCResponse(id: reqId, result: result)
                try await transport.send(response)
            } catch let error as JSONRPCErrorDetail {
                guard !Task.isCancelled else { return }
                let response = JSONRPCError(id: reqId, error: error)
                try? await transport.send(response)
            } catch {
                guard !Task.isCancelled else { return }
                let errorDetail = JSONRPCErrorDetail(code: JSONRPCErrorCode.internalError, message: error.localizedDescription)
                let response = JSONRPCError(id: reqId, error: errorDetail)
                try? await transport.send(response)
            }
            self.removeRunningTask(id: reqId)
        }
        runningTasks[reqId] = task
    }

    /// Removes a completed task from `runningTasks`.
    ///
    /// - Parameter id: The `JSONRPCId` of the finished request.
    private func removeRunningTask(id: JSONRPCId) {
        runningTasks.removeValue(forKey: id)
    }

    /// Handles an incoming client `JSONRPCNotification`, including `notifications/cancelled`.
    ///
    /// - Parameter notification: The decoded `JSONRPCNotification` from the client.
    private func handleNotification(_ notification: JSONRPCNotification<AnyCodable>) async {
        if notification.method == "notifications/cancelled" {
            if let params = notification.params,
               let data = try? encoder.encode(params),
               let cancelParams = try? decoder.decode(CancelledNotificationParams.self, from: data),
               let task = runningTasks[cancelParams.requestId] {
                task.cancel()
                runningTasks.removeValue(forKey: cancelParams.requestId)
            }
            return
        }

        do {
            try await router.handleNotification(notification: notification)
        } catch {
            // Notifications don't get responses, but we could log
        }
    }

    /// Resolves the awaiting continuation matching a client `JSONRPCResponse`.
    ///
    /// - Parameter response: The decoded `JSONRPCResponse` from the client.
    private func handleResponse(_ response: JSONRPCResponse<AnyCodable>) async {
        if let cont = pendingRequests.removeValue(forKey: response.id) {
            if let result = response.result {
                cont.resolve(result)
            } else {
                cont.resolve(AnyCodable([String: String]()))
            }
        }
    }

    /// Rejects the awaiting continuation matching a client `JSONRPCError`.
    ///
    /// - Parameter errorResponse: The decoded `JSONRPCError` from the client.
    private func handleError(_ errorResponse: JSONRPCError) async {
        if let id = errorResponse.id, let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(errorResponse.error)
        }
    }

    // MARK: - Server specific adapters

    /// Sends a `sampling/createMessage` request to the client to sample an LLM completion.
    ///
    /// - Parameter params: The `CreateMessageRequestParams` specifying messages, model preferences, and token limits.
    /// - Returns: The `CreateMessageResult` returned by the client.
    /// - Throws: An error if the sampling request fails.
    public func createMessage(params: CreateMessageRequestParams) async throws -> CreateMessageResult {
        let response = try await sendRequest(method: "sampling/createMessage", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(CreateMessageResult.self, from: data)
    }
}
