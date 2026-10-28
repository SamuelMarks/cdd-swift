/// Server-Sent Events (SSE) and HTTP POST transport for the Model Context Protocol (MCP).

/// Actor-isolated state container for `MCPSSETransport`, providing compile-time `Sendable` safety without `NSLock`.
private actor SSETransportState {
    /// Flag indicating whether the transport is open.
    private var isReading = false
    /// Callback for incoming client POST payloads.
    private var messageHandler: (@Sendable (Data) async -> Void)?
    /// Callback for outgoing SSE events.
    private var eventEmitter: (@Sendable (String, Data) async throws -> Void)?

    /// Initializes the state with an event emitter closure.
    ///
    /// - Parameter eventEmitter: The closure invoked to emit SSE events.
    init(eventEmitter: (@Sendable (String, Data) async throws -> Void)?) {
        self.eventEmitter = eventEmitter
    }

    /// Configures the message handler and marks the transport as reading.
    ///
    /// - Parameter handler: Incoming message callback closure.
    func activate(handler: @escaping @Sendable (Data) async -> Void) {
        messageHandler = handler
        isReading = true
    }

    /// Closes the state and clears all registered callbacks.
    func deactivate() {
        isReading = false
        messageHandler = nil
        eventEmitter = nil
    }

    /// Emits a named SSE event if an event emitter is registered.
    ///
    /// - Parameters:
    ///   - event: The SSE event name.
    ///   - data: The serialized event data.
    /// - Throws: Any error thrown by `eventEmitter`.
    func emit(event: String, data: Data) async throws {
        try await eventEmitter?(event, data)
    }

    /// Returns the active message handler if the transport is currently reading.
    ///
    /// - Returns: The registered `@Sendable (Data) async -> Void` closure, or `nil`.
    func activeHandler() -> (@Sendable (Data) async -> Void)? {
        guard isReading else { return nil }
        return messageHandler
    }
}

/// An SSE-based transport for the Model Context Protocol (MCP).
/// Handles sending messages via Server-Sent Events (SSE) and receiving client messages via HTTP POST.
public final class MCPSSETransport: MCPTransport {
    /// The HTTP POST endpoint URL advertised to connected SSE clients.
    private let endpoint: URL
    /// JSON encoder used to serialize outgoing SSE event payloads.
    private let encoder = JSONEncoder()
    /// Actor-isolated state holding the active callbacks.
    private let state: SSETransportState

    /// Initializes a new Server-Sent Events (SSE) transport.
    ///
    /// - Parameters:
    ///   - endpoint: The HTTP endpoint URL where the client should send POST messages.
    ///   - eventEmitter: A closure provided by the web framework to emit named SSE events to the client connection.
    public init(endpoint: URL, eventEmitter: @escaping @Sendable (String, Data) async throws -> Void) {
        self.endpoint = endpoint
        state = SSETransportState(eventEmitter: eventEmitter)
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// Encodes a message to JSON and emits it as a `"message"` SSE event.
    ///
    /// - Parameter message: The `Encodable & Sendable` JSON-RPC payload to transmit.
    /// - Throws: An error if encoding or emitting the SSE event fails.
    public func send(_ message: some Encodable & Sendable) async throws {
        let data = try encoder.encode(message)
        try await state.emit(event: "message", data: data)
    }

    /// Registers the incoming message callback and emits the initial `"endpoint"` SSE event.
    ///
    /// - Parameter onMessage: Closure invoked whenever `handleIncomingPost(data:)` receives data.
    /// - Throws: An error if emitting the `"endpoint"` SSE event fails.
    public func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws {
        await state.activate(handler: onMessage)

        let endpointData = try encoder.encode(endpoint.absoluteString)
        try await state.emit(event: "endpoint", data: endpointData)
    }

    /// Closes the SSE transport and releases registered handlers.
    ///
    /// - Throws: Never throws by default.
    public func close() async throws {
        await state.deactivate()
    }

    /// Bridges an incoming HTTP POST request body to the active MCP session.
    ///
    /// - Parameter data: Raw JSON-RPC body bytes from the HTTP POST request.
    /// - Throws: `JSONRPCErrorDetail` with `.internalError` if the transport has not been started or is already closed.
    public func handleIncomingPost(data: Data) async throws {
        guard let handler = await state.activeHandler() else {
            throw JSONRPCErrorDetail(code: .internalError, message: "Transport not started or closed")
        }
        await handler(data)
    }
}
