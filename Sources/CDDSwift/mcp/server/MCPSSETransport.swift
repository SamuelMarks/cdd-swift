import Foundation

/// An SSE-based transport for MCP.
/// Handles sending messages via Server-Sent Events (SSE) and receiving them via HTTP POST.
public class MCPSSETransport: MCPTransport, @unchecked Sendable {
    private let endpoint: URL
    private let encoder = JSONEncoder()
    private var isReading = false

    // For handling incoming POST messages
    private var messageHandler: ((Data) async -> Void)?

    // For server-side emitting of SSE events
    private var eventEmitter: ((String, Data) async throws -> Void)?

    /// Initialize a new SSE transport.
    /// - Parameters:
    ///   - endpoint: The HTTP endpoint for receiving POST messages.
    ///   - eventEmitter: A closure provided by the web framework to emit SSE events to the client connection.
    public init(endpoint: URL, eventEmitter: @escaping (String, Data) async throws -> Void) {
        self.endpoint = endpoint
        self.eventEmitter = eventEmitter
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// Documentation for send
    public func send<T: Encodable>(_ message: T) async throws {
        let data = try encoder.encode(message)
        // Send as a JSON-RPC message event
        try await eventEmitter?("message", data)
    }

    /// Documentation for start
    public func start(onMessage: @escaping (Data) async -> Void) async throws {
        messageHandler = onMessage
        isReading = true

        // In a server-side SSE transport, "start" typically just registers the handler and sends the endpoint event.
        let endpointData = try encoder.encode(endpoint.absoluteString)
        try await eventEmitter?("endpoint", endpointData)
    }

    /// Documentation for close
    public func close() async throws {
        isReading = false
        messageHandler = nil
        eventEmitter = nil
    }

    /// Bridge an incoming HTTP POST request's JSON body to the MCP session.
    /// Frameworks call this when they receive a POST at the message endpoint.
    public func handleIncomingPost(data: Data) async throws {
        guard isReading, let handler = messageHandler else {
            throw JSONRPCErrorDetail(code: .internalError, message: "Transport not started or closed")
        }
        await handler(data)
    }
}
