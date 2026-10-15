import Foundation

/// Internal thread-safe state box for `MCPSSETransport`.
private final class SSETransportState: @unchecked Sendable {
    private let lock = NSLock()
    private var _isReading = false
    private var _messageHandler: ((Data) async -> Void)?
    private var _eventEmitter: ((String, Data) async throws -> Void)?

    /// Initializes the state with an event emitter closure.
    init(eventEmitter: ((String, Data) async throws -> Void)?) {
        _eventEmitter = eventEmitter
    }

    /// Thread-safe access to the reading state.
    var isReading: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isReading
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isReading = newValue
        }
    }

    /// Thread-safe access to the incoming message handler.
    var messageHandler: ((Data) async -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _messageHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _messageHandler = newValue
        }
    }

    /// Thread-safe access to the SSE event emitter closure.
    var eventEmitter: ((String, Data) async throws -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _eventEmitter
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _eventEmitter = newValue
        }
    }
}

/// An SSE-based transport for the Model Context Protocol (MCP).
/// Handles sending messages via Server-Sent Events (SSE) and receiving client messages via HTTP POST.
public final class MCPSSETransport: MCPTransport, @unchecked Sendable {
    private let endpoint: URL
    private let encoder = JSONEncoder()
    private let state: SSETransportState

    /// Initializes a new Server-Sent Events (SSE) transport.
    ///
    /// - Parameters:
    ///   - endpoint: The HTTP endpoint URL where the client should send POST messages.
    ///   - eventEmitter: A closure provided by the web framework to emit named SSE events to the client connection.
    public init(endpoint: URL, eventEmitter: @escaping (String, Data) async throws -> Void) {
        self.endpoint = endpoint
        state = SSETransportState(eventEmitter: eventEmitter)
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// Encodes a message to JSON and emits it as a `"message"` SSE event.
    ///
    /// - Parameter message: The `Encodable` JSON-RPC payload to transmit.
    /// - Throws: An error if encoding or emitting the SSE event fails.
    public func send<T: Encodable>(_ message: T) async throws {
        let data = try encoder.encode(message)
        try await state.eventEmitter?("message", data)
    }

    /// Registers the incoming message callback and emits the initial `"endpoint"` SSE event.
    ///
    /// - Parameter onMessage: Closure invoked whenever `handleIncomingPost(data:)` receives data.
    /// - Throws: An error if emitting the `"endpoint"` SSE event fails.
    public func start(onMessage: @escaping (Data) async -> Void) async throws {
        state.messageHandler = onMessage
        state.isReading = true

        let endpointData = try encoder.encode(endpoint.absoluteString)
        try await state.eventEmitter?("endpoint", endpointData)
    }

    /// Closes the SSE transport and releases registered handlers.
    public func close() async throws {
        state.isReading = false
        state.messageHandler = nil
        state.eventEmitter = nil
    }

    /// Bridges an incoming HTTP POST request body to the active MCP session.
    ///
    /// - Parameter data: Raw JSON-RPC body bytes from the HTTP POST request.
    /// - Throws: `JSONRPCErrorDetail` with `.internalError` if the transport has not been started or is already closed.
    public func handleIncomingPost(data: Data) async throws {
        guard state.isReading, let handler = state.messageHandler else {
            throw JSONRPCErrorDetail(code: .internalError, message: "Transport not started or closed")
        }
        await handler(data)
    }
}
