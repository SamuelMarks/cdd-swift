/// Unit tests for `MCPClientSession` and `DefaultMCPClientRouter`.
import XCTest
@testable import CDDSwift

/// Actor-isolated state container for `MockTransportForClient`.
private actor MockClientTransportState {
    /// Recorded outgoing messages.
    var sentMessages: [any Sendable] = []
    /// Registered incoming message handler.
    var onMessageCallback: (@Sendable (Data) async -> Void)?
    /// Indicates whether `close()` was called.
    var closeCalled = false
    /// When `true`, `send(_:)` throws an error.
    var shouldThrowOnSend = false

    /// Appends a sent message or throws if `shouldThrowOnSend` is enabled.
    ///
    /// - Parameter message: The message to record.
    /// - Throws: `JSONRPCErrorDetail` when `shouldThrowOnSend` is `true`.
    func recordSend(_ message: any Sendable) throws {
        if shouldThrowOnSend {
            throw JSONRPCErrorDetail(code: .internalError, message: "transport err")
        }
        sentMessages.append(message)
    }

    /// Registers the incoming message callback.
    ///
    /// - Parameter callback: The `@Sendable` message handler closure.
    func setCallback(_ callback: @escaping @Sendable (Data) async -> Void) {
        onMessageCallback = callback
    }

    /// Marks the transport as closed.
    func markClosed() {
        closeCalled = true
    }

    /// Configures whether `send` should throw.
    ///
    /// - Parameter flag: Boolean flag.
    func setShouldThrow(_ flag: Bool) {
        shouldThrowOnSend = flag
    }
}

/// Thread-safe mock `MCPTransport` for testing `MCPClientSession` without `@unchecked Sendable`.
final class MockTransportForClient: MCPTransport {
    /// Actor-isolated state container.
    private let state = MockClientTransportState()

    /// Initializes the mock client transport.
    init() {}

    /// Sends a message through the mock transport.
    ///
    /// - Parameter message: The `Encodable & Sendable` message to send.
    /// - Throws: `JSONRPCErrorDetail` if configured to fail.
    func send(_ message: some Encodable & Sendable) async throws {
        try await state.recordSend(message)
    }

    /// Starts the mock transport with the given message handler.
    ///
    /// - Parameter onMessage: Callback invoked when simulated messages arrive.
    func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws {
        await state.setCallback(onMessage)
    }

    /// Closes the mock transport.
    func close() async throws {
        await state.markClosed()
    }

    /// Returns all sent messages recorded by the transport.
    func sentMessages() async -> [any Sendable] {
        await state.sentMessages
    }

    /// Simulates receiving raw `Data` from the remote peer.
    ///
    /// - Parameter data: The JSON-RPC message payload.
    func simulateIncoming(_ data: Data) async {
        let cb = await state.onMessageCallback
        await cb?(data)
    }

    /// Returns the currently registered message callback.
    func currentCallback() async -> (@Sendable (Data) async -> Void)? {
        await state.onMessageCallback
    }

    /// Returns whether `close()` has been called.
    func isClosed() async -> Bool {
        await state.closeCalled
    }

    /// Configures whether subsequent `send` calls should throw.
    ///
    /// - Parameter flag: `true` to throw on `send`.
    func setShouldThrowOnSend(_ flag: Bool) async {
        await state.setShouldThrow(flag)
    }
}

/// Test suite verifying `MCPClientSession` initialization, requests, notifications, pagination, and error handling.
final class MCPClientSessionTests: XCTestCase {
    /// Verifies that invoking the transport callback after `MCPClientSession` is deallocated safely no-ops.
    func testStartDeallocated() async throws {
        let transport = MockTransportForClient()
        var session: MCPClientSession? = MCPClientSession(transport: transport)
        try await session?.start()
        let cb = await transport.currentCallback()
        session = nil
        await cb?(Data("{}".utf8))
    }

    /// Verifies that `close()` cancels in-flight pending requests.
    func testCloseCancelsPendingRequests() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try? await session.sendRequest(method: "pending", params: AnyCodable("test"))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        try await session.close()
        let closed = await transport.isClosed()
        XCTAssertTrue(closed)

        let value = await task.value
        XCTAssertNil(value)
    }

    /// Verifies that unrecognized JSON-RPC payloads are ignored without crashing.
    func testProcessIncomingDataFallthrough() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()
        let json = #"{"invalid_jsonrpc":"3.0"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies handling a server-to-client request with a custom `MCPClientRouter`.
    func testProcessIncomingDataClientRequestSuccess() async throws {
        /// Custom test router returning `"success"`.
        struct CustomRouter: MCPClientRouter {
            /// Handles an incoming server request.
            ///
            /// - Parameter request: Incoming JSON-RPC request.
            /// - Returns: `"success"` wrapped in `AnyCodable`.
            func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
                AnyCodable("success")
            }

            /// Handles an incoming server notification.
            ///
            /// - Parameter notification: Incoming JSON-RPC notification.
            func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async {}
        }
        let router = CustomRouter()
        await router.handleNotification(notification: JSONRPCNotification(method: "noop"))
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport, router: router)
        try await session.start()

        let json = #"{"jsonrpc":"2.0","id":10,"method":"do_work"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let resp = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(resp.id, .integer(10))
        XCTAssertEqual(resp.result, AnyCodable("success"))
    }

    /// Verifies that a generic error thrown by `MCPClientRouter` is returned as `.internalError`.
    func testProcessIncomingDataClientRequestGeneralError() async throws {
        /// Dummy error type for testing.
        struct GeneralError: Error {}
        /// Custom test router that throws `GeneralError`.
        struct CustomRouterError: MCPClientRouter {
            /// Throws `GeneralError` on every request.
            ///
            /// - Parameter request: Incoming JSON-RPC request.
            /// - Returns: Never returns.
            func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
                throw GeneralError()
            }

            /// Handles an incoming server notification.
            ///
            /// - Parameter notification: Incoming JSON-RPC notification.
            func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async {}
        }
        let router = CustomRouterError()
        await router.handleNotification(notification: JSONRPCNotification(method: "noop"))
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport, router: router)
        try await session.start()

        let json = #"{"jsonrpc":"2.0","id":11,"method":"do_error"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let resp = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(resp.id, .integer(11))
        XCTAssertEqual(resp.error.code, JSONRPCErrorCode.internalError.rawValue)
    }

    /// Verifies that a response without a `result` field resolves to an empty `AnyCodable` dictionary.
    func testProcessIncomingDataResponseNoResult() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test_empty_result", params: AnyCodable("foo"))
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<AnyCodable>)
        XCTAssertEqual(req.id, .integer(1))

        let json = #"{"jsonrpc":"2.0","id":1}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result, AnyCodable([String: String]()))
    }

    /// Verifies the MCP `initialize` handshake and `notifications/initialized` emission.
    func testInitialize() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.initialize(serverVersion: "1.0")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)

        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<InitializeRequestParams>)

        let initResult = InitializeResult(
            _meta: nil,
            protocolVersion: "1.0",
            capabilities: ServerCapabilities(),
            serverInfo: Implementation(name: "mock-server", version: "1.0.0"),
            instructions: nil
        )
        let resp = JSONRPCResponse<InitializeResult>(id: req.id, result: initResult)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.serverInfo.name, "mock-server")
    }

    /// Verifies paginated `listAllTools()` across multiple cursors.
    func testListTools() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllTools()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages1 = await transport.sentMessages()
        let req1 = try XCTUnwrap(messages1.first as? JSONRPCRequest<ListToolsRequestParams>)

        let toolsResult1 = ListToolsResult(
            _meta: nil,
            nextCursor: "page2",
            tools: [Tool(name: "tool1", inputSchema: ToolInputSchema(type: "object"))]
        )
        let resp1 = JSONRPCResponse<ListToolsResult>(id: req1.id, result: toolsResult1)
        let data1 = try JSONEncoder().encode(resp1)
        await transport.simulateIncoming(data1)

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages2 = await transport.sentMessages()
        XCTAssertEqual(messages2.count, 2)
        let req2 = try XCTUnwrap(messages2.last as? JSONRPCRequest<ListToolsRequestParams>)
        XCTAssertEqual(req2.params?.cursor, "page2")

        let toolsResult2 = ListToolsResult(
            _meta: nil,
            nextCursor: nil,
            tools: [Tool(name: "tool2", inputSchema: ToolInputSchema(type: "object"))]
        )
        let resp2 = JSONRPCResponse<ListToolsResult>(id: req2.id, result: toolsResult2)
        let data2 = try JSONEncoder().encode(resp2)
        await transport.simulateIncoming(data2)

        let result = try await task.value
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "tool1")
        XCTAssertEqual(result[1].name, "tool2")
    }

    /// Verifies `executeTool(name:arguments:)`.
    func testExecuteTool() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.executeTool(name: "my_tool", arguments: ["foo": AnyCodable("bar")])
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<CallToolRequestParams>)

        let toolResult = CallToolResult(
            _meta: nil,
            content: [AnyCodable(["type": "text", "text": "success"])],
            isError: false
        )
        let resp = JSONRPCResponse<CallToolResult>(id: req.id, result: toolResult)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertFalse(result.isError == true)
        XCTAssertEqual(result.content.count, 1)
    }

    /// Verifies `DefaultMCPClientRouter` default behavior.
    func testDefaultRouter() async throws {
        let router = DefaultMCPClientRouter()

        let res = try? await router.handleRequest(request: JSONRPCRequest(id: .integer(1), method: "test"))
        XCTAssertNil(res)

        try await router.handleNotification(notification: JSONRPCNotification(method: "test"))
    }
}
