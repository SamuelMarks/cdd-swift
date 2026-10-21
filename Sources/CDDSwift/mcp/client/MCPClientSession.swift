/// Model Context Protocol (MCP) client session actor and client-side routing abstractions.
import Foundation

/// A router for handling incoming server-initiated JSON-RPC requests and notifications on an MCP client.
public protocol MCPClientRouter: Sendable {
    /// Handles an incoming JSON-RPC request sent by the MCP server to the client.
    ///
    /// - Parameter request: The incoming `JSONRPCRequest` envelope.
    /// - Returns: The `AnyCodable` result payload to send back to the server.
    /// - Throws: `JSONRPCErrorDetail` or any error if handling the request fails.
    func handleRequest(request: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable
    /// Handles an incoming JSON-RPC notification sent by the MCP server to the client.
    ///
    /// - Parameter notification: The incoming `JSONRPCNotification` envelope.
    /// - Throws: An error if processing the notification fails.
    func handleNotification(notification: JSONRPCNotification<AnyCodable>) async throws
}

/// A default no-op client router that rejects all server-initiated requests with `.methodNotFound`.
public struct DefaultMCPClientRouter: MCPClientRouter {
    /// Initializes a `DefaultMCPClientRouter`.
    public init() {}

    /// Rejects incoming server requests with a `.methodNotFound` JSON-RPC error.
    ///
    /// - Parameter request: The incoming `JSONRPCRequest` envelope.
    /// - Returns: Never returns normally.
    /// - Throws: `JSONRPCErrorDetail` with code `.methodNotFound`.
    public func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
        throw JSONRPCErrorDetail(code: .methodNotFound, message: "Method not found")
    }

    /// Ignores incoming server notifications.
    ///
    /// - Parameter notification: The incoming `JSONRPCNotification` envelope.
    /// - Throws: Never throws by default.
    public func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async throws {}
}

/// Actor managing an active Model Context Protocol (MCP) client session over an `MCPTransport`.
public actor MCPClientSession {
    /// Underlying bidirectional message transport.
    private let transport: MCPTransport
    /// Router handling server-initiated requests and notifications.
    private let router: MCPClientRouter
    /// JSON encoder for serializing outgoing requests and responses.
    private let encoder: JSONEncoder
    /// JSON decoder for deserializing incoming frames.
    private let decoder: JSONDecoder
    /// Map of in-flight request IDs to their awaiting continuations.
    private var pendingRequests: [JSONRPCId: Continuation] = [:]
    /// Monotonically increasing counter for assigning request IDs.
    private var nextRequestId: Int = 1

    /// Pair of closures used to resolve or reject an awaiting request continuation.
    private struct Continuation {
        /// Closure invoked when a matching `JSONRPCResponse` arrives.
        let resolve: (AnyCodable) -> Void
        /// Closure invoked when a matching `JSONRPCError` or transport failure occurs.
        let reject: (Error) -> Void
    }

    /// Initializes an `MCPClientSession`.
    ///
    /// - Parameters:
    ///   - transport: The `MCPTransport` used for sending and receiving JSON-RPC messages.
    ///   - router: The `MCPClientRouter` used to handle server-initiated requests (defaults to `DefaultMCPClientRouter()`).
    public init(transport: MCPTransport, router: MCPClientRouter = DefaultMCPClientRouter()) {
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
            guard let self = self else { return }
            await self.processIncomingData(data)
        }
    }

    /// Closes the transport and cancels all in-flight pending requests with `CancellationError`.
    ///
    /// - Throws: An error if closing the transport fails.
    public func close() async throws {
        try await transport.close()
        for continuation in pendingRequests.values {
            continuation.reject(CancellationError())
        }
        pendingRequests.removeAll()
    }

    /// Sends a typed JSON-RPC request to the server and awaits the response result.
    ///
    /// - Parameters:
    ///   - method: The JSON-RPC method name to call.
    ///   - params: Optional structured parameters for the method.
    /// - Returns: The `AnyCodable` result returned by the server.
    /// - Throws: `JSONRPCErrorDetail` or a transport error if the request fails.
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

    /// Removes and fails a pending request continuation when sending fails.
    ///
    /// - Parameters:
    ///   - id: The `JSONRPCId` of the failed request.
    ///   - error: The error to resume the continuation with.
    private func failPendingRequest(id: JSONRPCId, error: Error) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(error)
        }
    }

    /// Sends a one-way JSON-RPC notification to the server.
    ///
    /// - Parameters:
    ///   - method: The notification method name.
    ///   - params: Optional structured parameters for the notification.
    /// - Throws: An error if encoding or transmitting the notification fails.
    public func sendNotification<T: Codable & Sendable>(method: String, params: T?) async throws {
        let notification = JSONRPCNotification(method: method, params: params)
        try await transport.send(notification)
    }

    /// Sends a `notifications/progress` update for an active progress token.
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

    /// Invokes the client router for a server-initiated request and transmits the response or error.
    ///
    /// - Parameter request: The decoded `JSONRPCRequest` from the server.
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

    /// Forwards an incoming server notification to the client router.
    ///
    /// - Parameter notification: The decoded `JSONRPCNotification` from the server.
    private func handleNotification(_ notification: JSONRPCNotification<AnyCodable>) async {
        try? await router.handleNotification(notification: notification)
    }

    /// Resolves the awaiting continuation matching a server `JSONRPCResponse`.
    ///
    /// - Parameter response: The decoded `JSONRPCResponse` from the server.
    private func handleResponse(_ response: JSONRPCResponse<AnyCodable>) async {
        if let cont = pendingRequests.removeValue(forKey: response.id) {
            if let result = response.result {
                cont.resolve(result)
            } else {
                cont.resolve(AnyCodable([String: String]()))
            }
        }
    }

    /// Rejects the awaiting continuation matching a server `JSONRPCError`.
    ///
    /// - Parameter errorResponse: The decoded `JSONRPCError` from the server.
    private func handleError(_ errorResponse: JSONRPCError) async {
        if let id = errorResponse.id, let cont = pendingRequests.removeValue(forKey: id) {
            cont.reject(errorResponse.error)
        }
    }

    // MARK: - Client specific adapters

    /// Performs the MCP `initialize` handshake with the server.
    ///
    /// - Parameters:
    ///   - serverVersion: The MCP protocol version string to request.
    ///   - capabilities: Optional `ClientCapabilities` to advertise.
    /// - Returns: The server's `InitializeResult`.
    /// - Throws: An error if the handshake fails or response decoding fails.
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

    /// Requests a single page of tools from the server via `tools/list`.
    ///
    /// - Parameter cursor: Optional pagination cursor.
    /// - Returns: The decoded `ListToolsResult`.
    /// - Throws: An error if the RPC call fails.
    public func listTools(cursor: String? = nil) async throws -> ListToolsResult {
        let params = ListToolsRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "tools/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListToolsResult.self, from: data)
    }

    /// Iterates through all pages of `tools/list` and returns the complete list of available tools.
    ///
    /// - Returns: Array of all `Tool` definitions exposed by the server.
    /// - Throws: An error if any page request fails.
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

    /// Invokes a named tool on the server via `tools/call`.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to execute.
    ///   - arguments: Dictionary of input arguments for the tool.
    /// - Returns: The `CallToolResult` returned by the server.
    /// - Throws: An error if the tool invocation fails.
    public func executeTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> CallToolResult {
        let params = CallToolRequestParams(name: name, arguments: arguments)
        let response = try await sendRequest(method: "tools/call", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(CallToolResult.self, from: data)
    }

    /// Requests a single page of resources from the server via `resources/list`.
    ///
    /// - Parameter cursor: Optional pagination cursor.
    /// - Returns: The decoded `ListResourcesResult`.
    /// - Throws: An error if the RPC call fails.
    public func listResources(cursor: String? = nil) async throws -> ListResourcesResult {
        let params = ListResourcesRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "resources/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListResourcesResult.self, from: data)
    }

    /// Iterates through all pages of `resources/list` and returns all available resources.
    ///
    /// - Returns: Array of all `Resource` descriptors exposed by the server.
    /// - Throws: An error if any page request fails.
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

    /// Reads the contents of a specific resource URI via `resources/read`.
    ///
    /// - Parameter uri: The canonical resource URI to read.
    /// - Returns: The decoded `ReadResourceResult`.
    /// - Throws: An error if reading the resource fails.
    public func readResource(uri: String) async throws -> ReadResourceResult {
        let params = ReadResourceRequestParams(uri: uri)
        let response = try await sendRequest(method: "resources/read", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ReadResourceResult.self, from: data)
    }

    /// Requests a single page of resource templates from the server via `resources/templates/list`.
    ///
    /// - Parameter cursor: Optional pagination cursor.
    /// - Returns: The decoded `ListResourceTemplatesResult`.
    /// - Throws: An error if the RPC call fails.
    public func listResourceTemplates(cursor: String? = nil) async throws -> ListResourceTemplatesResult {
        let params = ListResourceTemplatesRequestParams(_meta: nil, cursor: cursor)
        let response = try await sendRequest(method: "resources/templates/list", params: params)
        let data = try encoder.encode(response)
        return try decoder.decode(ListResourceTemplatesResult.self, from: data)
    }

    /// Iterates through all pages of `resources/templates/list` and returns all resource templates.
    ///
    /// - Returns: Array of all `ResourceTemplate` definitions exposed by the server.
    /// - Throws: An error if any page request fails.
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
