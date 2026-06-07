import Foundation

/// A router for handling MCP Server incoming requests and notifications
public protocol MCPServerRouter: Sendable {
    /// Documentation for handleRequest
    func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable
    /// Documentation for handleNotification
    func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws
}

public actor MCPServerSession {
    private let transport: MCPTransport
    private let router: MCPServerRouter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingRequests: [JSONRPCId: Continuation] = [:]
    private var runningTasks: [JSONRPCId: Task<Void, Never>] = [:]
    private var nextRequestId: Int = 1

    /// Documentation for Continuation
    private struct Continuation {
        let resolve: (AnyCodable) -> Void
        let reject: (Error) -> Void
    }

    public init(transport: MCPTransport, router: MCPServerRouter) {
        self.transport = transport
        self.router = router
        encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    /// Documentation for start
    public func start() async throws {
        try await transport.start { [weak self] data in
            guard let self = self else { return }
            Task {
                await self.processIncomingData(data)
            }
        }
    }

    /// Documentation for close
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

    /// Documentation for sendRequest
    public func sendRequest<T: Codable & Sendable>(method: String, params: T?) async throws -> AnyCodable {
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

    /// Documentation for failPendingRequest
    private func failPendingRequest(id: JSONRPCId, error: Error) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(error)
        }
    }

    /// Documentation for sendNotification
    public func sendNotification<T: Codable & Sendable>(method: String, params: T?) async throws {
        let notification = JSONRPCNotification(method: method, params: params)
        try await transport.send(notification)
    }

    /// Documentation for sendProgress
    public func sendProgress(progressToken: ProgressToken, progress: Double, total: Double? = nil) async throws {
        let params = ProgressNotificationParams(progressToken: progressToken, progress: progress, total: total)
        try await sendNotification(method: "notifications/progress", params: params)
    }

    /// Documentation for processIncomingData
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

    /// Documentation for handleRequest
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

    /// Documentation for removeRunningTask
    private func removeRunningTask(id: JSONRPCId) {
        runningTasks.removeValue(forKey: id)
    }

    /// Documentation for handleNotification
    private func handleNotification(_ notification: JSONRPCNotification<AnyCodable>) async {
        if notification.method == "notifications/cancelled" {
            if let paramsAny = notification.params?.value as? [String: Any],
               let data = try? encoder.encode(AnyCodable(paramsAny)),
               let cancelParams = try? decoder.decode(CancelledNotificationParams.self, from: data)
            {
                if let task = runningTasks[cancelParams.requestId] {
                    task.cancel()
                    runningTasks.removeValue(forKey: cancelParams.requestId)
                }
            }
            return
        }

        do {
            try await router.handleNotification(notification: notification)
        } catch {
            // Notifications don't get responses, but we could log
        }
    }

    /// Documentation for handleResponse
    private func handleResponse(_ response: JSONRPCResponse<AnyCodable>) async {
        if let cont = pendingRequests.removeValue(forKey: response.id) {
            if let result = response.result {
                cont.resolve(result)
            } else {
                cont.resolve(AnyCodable([String: String]()))
            }
        }
    }

    /// Documentation for handleError
    private func handleError(_ errorResponse: JSONRPCError) async {
        if let id = errorResponse.id, let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(errorResponse.error)
        }
    }

    // MARK: - Server specific adapters

    /// Documentation for createMessage
    public func createMessage(params: CreateMessageRequestParams) async throws -> CreateMessageResult {
        let response = try await sendRequest(method: "sampling/createMessage", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(CreateMessageResult.self, from: data)
    }
}
