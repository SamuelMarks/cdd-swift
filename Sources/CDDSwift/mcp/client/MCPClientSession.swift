import Foundation

/// A router for handling MCP Client incoming notifications or server requests
public protocol MCPClientRouter: Sendable {
    /// Documentation for handleRequest
    func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable
    /// Documentation for handleNotification
    func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws
}

/// A default empty client router
public struct DefaultMCPClientRouter: MCPClientRouter {
    public init() {}
    /// Documentation for handleRequest
    public func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
        throw JSONRPCErrorDetail(code: .methodNotFound, message: "Method not found")
    }

    /// Documentation for handleNotification
    public func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async throws {}
}

public actor MCPClientSession {
    private let transport: MCPTransport
    private let router: MCPClientRouter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingRequests: [JSONRPCId: Continuation] = [:]
    private var nextRequestId: Int = 1

    /// Documentation for Continuation
    private struct Continuation {
        let resolve: (AnyCodable) -> Void
        let reject: (Error) -> Void
    }

    public init(transport: MCPTransport, router: MCPClientRouter = DefaultMCPClientRouter()) {
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
        if let request = try? decoder.decode(JSONRPCRequest<AnyCodable>.self, from: data) {
            await handleRequest(request)
            return
        }
        if let notification = try? decoder.decode(JSONRPCNotification<AnyCodable>.self, from: data) {
            await handleNotification(notification)
            return
        }
        if let error = try? decoder.decode(JSONRPCError.self, from: data) {
            await handleError(error)
            return
        }
        if let response = try? decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data) {
            await handleResponse(response)
            return
        }
    }

    /// Documentation for handleRequest
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

    /// Documentation for handleNotification
    private func handleNotification(_ notification: JSONRPCNotification<AnyCodable>) async {
        try? await router.handleNotification(notification: notification)
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

    // MARK: - Client specific adapters

    /// Documentation for initialize
    public func initialize(serverVersion: String, capabilities: ClientCapabilities? = nil) async throws -> InitializeResult {
        let defaultCaps = ClientCapabilities(experimental: nil, roots: nil, sampling: nil)
        let params = InitializeRequestParams(
            protocolVersion: serverVersion,
            capabilities: capabilities ?? defaultCaps,
            clientInfo: Implementation(name: "cdd-swift-client", version: "1.0.0")
        )
        let response = try await sendRequest(method: "initialize", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(InitializeResult.self, from: data)
    }

    /// Documentation for listTools
    public func listTools(cursor: String? = nil) async throws -> ListToolsResult {
        let params = ListToolsRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "tools/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListToolsResult.self, from: data)
    }

    /// Documentation for listAllTools
    public func listAllTools() async throws -> [Tool] {
        var allTools: [Tool] = []
        var currentCursor: String?

        repeat {
            let result = try await listTools(cursor: currentCursor)
            allTools.append(contentsOf: result.tools)
            currentCursor = result.nextCursor
        } while currentCursor != nil

        return allTools
    }

    /// Documentation for executeTool
    public func executeTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> CallToolResult {
        let params = CallToolRequestParams(name: name, arguments: arguments)
        let response = try await sendRequest(method: "tools/call", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(CallToolResult.self, from: data)
    }

    /// Documentation for listResources
    public func listResources(cursor: String? = nil) async throws -> ListResourcesResult {
        let params = ListResourcesRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "resources/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListResourcesResult.self, from: data)
    }

    /// Documentation for listAllResources
    public func listAllResources() async throws -> [Resource] {
        var allResources: [Resource] = []
        var currentCursor: String?

        repeat {
            let result = try await listResources(cursor: currentCursor)
            allResources.append(contentsOf: result.resources)
            currentCursor = result.nextCursor
        } while currentCursor != nil

        return allResources
    }

    /// Documentation for readResource
    public func readResource(uri: String) async throws -> ReadResourceResult {
        let params = ReadResourceRequestParams(uri: uri)
        let response = try await sendRequest(method: "resources/read", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ReadResourceResult.self, from: data)
    }

    /// Documentation for listResourceTemplates
    public func listResourceTemplates(cursor: String? = nil) async throws -> ListResourceTemplatesResult {
        let params = ListResourceTemplatesRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "resources/templates/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListResourceTemplatesResult.self, from: data)
    }

    /// Documentation for listAllResourceTemplates
    public func listAllResourceTemplates() async throws -> [ResourceTemplate] {
        var allTemplates: [ResourceTemplate] = []
        var currentCursor: String?

        repeat {
            let result = try await listResourceTemplates(cursor: currentCursor)
            allTemplates.append(contentsOf: result.resourceTemplates)
            currentCursor = result.nextCursor
        } while currentCursor != nil

        return allTemplates
    }
}
