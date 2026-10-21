/// Unit tests for `MCPServerSession` and `DefaultMCPServerRouter`.
import XCTest
@testable import CDDSwift

/// Actor-isolated state container for `MockTransportForRouter`.
private actor MockServerTransportState {
    /// Recorded outgoing messages.
    var sentMessages: [any Sendable] = []
    /// Registered incoming message handler.
    var onMessageCallback: (@Sendable (Data) async -> Void)?
    /// When `true`, `send(_:)` throws an error.
    var shouldThrowOnSend = false

    /// Appends a sent message or throws if `shouldThrowOnSend` is enabled.
    ///
    /// - Parameter message: The message to record.
    /// - Throws: `MCPServerSessionTests.GenericError` when `shouldThrowOnSend` is `true`.
    func recordSend(_ message: any Sendable) throws {
        if shouldThrowOnSend {
            throw MCPServerSessionTests.GenericError()
        }
        sentMessages.append(message)
    }

    /// Registers the incoming message callback.
    ///
    /// - Parameter callback: The `@Sendable` message handler closure.
    func setCallback(_ callback: @escaping @Sendable (Data) async -> Void) {
        onMessageCallback = callback
    }

    /// Configures whether `send` should throw.
    ///
    /// - Parameter flag: Boolean flag.
    func setShouldThrow(_ flag: Bool) {
        shouldThrowOnSend = flag
    }
}

/// Thread-safe mock `MCPTransport` for testing `MCPServerSession` without `@unchecked Sendable`.
final class MockTransportForRouter: MCPTransport {
    /// Actor-isolated state container.
    private let state = MockServerTransportState()

    /// Initializes the mock server transport.
    init() {}

    /// Sends a message through the mock transport.
    ///
    /// - Parameter message: The `Encodable & Sendable` message to send.
    /// - Throws: `MCPServerSessionTests.GenericError` if configured to fail.
    func send<T: Encodable & Sendable>(_ message: T) async throws {
        try await state.recordSend(message)
    }

    /// Starts the mock transport with the given message handler.
    ///
    /// - Parameter onMessage: Callback invoked when simulated messages arrive.
    func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws {
        await state.setCallback(onMessage)
    }

    /// Closes the mock transport.
    func close() async throws {}

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

    /// Configures whether subsequent `send` calls should throw.
    ///
    /// - Parameter flag: `true` to throw on `send`.
    func setShouldThrowOnSend(_ flag: Bool) async {
        await state.setShouldThrow(flag)
    }
}

/// Test suite verifying `MCPServerSession` request routing, cancellation, notifications, and sampling.
final class MCPServerSessionTests: XCTestCase {
    /// Dummy error type for testing error handling paths.
    struct GenericError: Error {}

    /// Verifies that invoking the transport callback after `MCPServerSession` is deallocated safely no-ops.
    func testStartDeallocated() async throws {
        let transport = MockTransportForRouter()
        var session: MCPServerSession? = MCPServerSession(transport: transport, router: DefaultMCPServerRouter())
        try await session?.start()
        let cb = await transport.currentCallback()
        session = nil
        await cb?(Data("{}".utf8))
    }

    /// Verifies that a transport error during `sendRequest` cleans up and rejects the continuation.
    func testSendRequestTransportError() async {
        let transport = MockTransportForRouter()
        await transport.setShouldThrowOnSend(true)
        let session = MCPServerSession(transport: transport, router: DefaultMCPServerRouter())
        let res = try? await session.sendRequest(method: "test", params: AnyCodable("foo"))
        XCTAssertNil(res)
    }

    /// Verifies that a client response without a `result` field resolves to an empty `AnyCodable` dictionary.
    func testProcessIncomingDataResponseNoResult() async throws {
        let transport = MockTransportForRouter()
        let session = MCPServerSession(transport: transport, router: DefaultMCPServerRouter())
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test", params: AnyCodable("foo"))
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

    /// Verifies that a cancelled request task suppresses sending a normal response when returning.
    func testIncomingRequestCancellationAtReturn() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")
        router.requestHandlers["test_cancel_return"] = { _ in
            startExpectation.fulfill()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return AnyCodable("ok")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(100), method: "test_cancel_return")
        try await transport.simulateIncoming(JSONEncoder().encode(req))
        await fulfillment(of: [startExpectation], timeout: 1.0)

        let cancelParams = CancelledNotificationParams(requestId: .integer(100), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        try await transport.simulateIncoming(JSONEncoder().encode(cancelNotif))

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies that a cancelled request task suppresses sending an error response when throwing `JSONRPCErrorDetail`.
    func testIncomingRequestCancellationAtThrow() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")
        router.requestHandlers["test_cancel_throw"] = { _ in
            startExpectation.fulfill()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            throw JSONRPCErrorDetail(code: .internalError, message: "err")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(101), method: "test_cancel_throw")
        try await transport.simulateIncoming(JSONEncoder().encode(req))
        await fulfillment(of: [startExpectation], timeout: 1.0)

        let cancelParams = CancelledNotificationParams(requestId: .integer(101), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        try await transport.simulateIncoming(JSONEncoder().encode(cancelNotif))

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies routing a valid client request and returning a `JSONRPCResponse`.
    func testHandleRequest() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()
        router.requestHandlers["test"] = { _ in
            AnyCodable("ok")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(1))
        XCTAssertEqual(response.result?.stringValue, "ok")
    }

    /// Verifies that an unregistered request method returns `-32601` (`methodNotFound`).
    func testHandleRequestMethodNotFound() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(1), method: "unknown")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(1))
        XCTAssertEqual(err.error.code, -32601)
    }

    /// Verifies routing an incoming client notification to the registered handler.
    func testHandleNotification() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let expectation = XCTestExpectation(description: "notification handled")
        router.notificationHandlers["notif"] = { _ in
            expectation.fulfill()
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let notif = JSONRPCNotification<AnyCodable>(method: "notif")
        let data = try JSONEncoder().encode(notif)
        await transport.simulateIncoming(data)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    /// Verifies that malformed non-JSON data is ignored safely.
    func testHandleInvalidData() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let data = Data("invalid".utf8)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies that an uncorrelated `JSONRPCResponse` is ignored safely.
    func testProcessResponseData() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let resp = JSONRPCResponse(id: .integer(1), result: AnyCodable("ok"))
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies that throwing `JSONRPCErrorDetail` inside a request handler emits a matching `JSONRPCError`.
    func testHandleRequestJSONRPCError() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()
        router.requestHandlers["test"] = { _ in
            throw JSONRPCErrorDetail(code: .invalidParams, message: "Custom error")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(1))
        XCTAssertEqual(err.error.code, -32602)
    }

    /// Verifies that throwing a generic `Error` inside a request handler emits `-32603` (`internalError`).
    func testHandleRequestGenericError() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()
        router.requestHandlers["test"] = { _ in
            throw GenericError()
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(1))
        XCTAssertEqual(err.error.code, -32603)
    }
}
