/// Unit tests for `MCPServerSession` lifecycle, cancellation, server-to-client requests, and sampling.
import CDDSwift
import XCTest

extension MCPServerSessionTests {
    /// Verifies that errors thrown by notification handlers are caught without crashing the session.
    func testHandleNotificationError() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        router.notificationHandlers["notif"] = { _ in
            throw GenericError()
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let notif = JSONRPCNotification<AnyCodable>(method: "notif")
        let data = try JSONEncoder().encode(notif)
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Verifies `close()` on an idle session.
    func testSessionClose() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.close()
    }

    /// Verifies that `close()` cancels in-flight request handler tasks.
    func testSessionCloseCancelsRunningTasks() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")

        router.requestHandlers["long_task"] = { _ in
            startExpectation.fulfill()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return AnyCodable("done")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(42), method: "long_task")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        await fulfillment(of: [startExpectation], timeout: 1.0)
        try await session.close()
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    /// Verifies `sendNotification(method:params:)`.
    func testSendNotification() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)

        try await session.sendNotification(method: "test/notify", params: AnyCodable(["foo": "bar"]))
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let notif = try XCTUnwrap(messages.first as? JSONRPCNotification<AnyCodable>)
        XCTAssertEqual(notif.method, "test/notify")
    }

    /// Verifies `sendRequest(method:params:)` and matching the correlated client response.
    func testSendRequestAndHandleResponse() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)

        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<AnyCodable>)

        let resp = JSONRPCResponse(id: req.id, result: AnyCodable("response_ok"))
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.stringValue, "response_ok")
    }

    /// Verifies `sendRequest(method:params:)` rejection when the client responds with `JSONRPCError`.
    func testSendRequestAndHandleError() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try? await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<AnyCodable>)

        let errResp = JSONRPCError(id: req.id, error: JSONRPCErrorDetail(code: .internalError, message: "failed"))
        let data = try JSONEncoder().encode(errResp)
        await transport.simulateIncoming(data)

        let val = await task.value
        XCTAssertNil(val)
    }

    /// Verifies `notifications/cancelled` handling when a request handler throws a generic error after cancellation.
    func testIncomingRequestCancellation() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")

        router.requestHandlers["long_task"] = { _ in
            startExpectation.fulfill()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            throw GenericError()
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(42), method: "long_task")
        let data = try JSONEncoder().encode(req)
        await transport.simulateIncoming(data)

        await fulfillment(of: [startExpectation], timeout: 1.0)

        let cancelParams = CancelledNotificationParams(requestId: .integer(42), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        let cancelData = try JSONEncoder().encode(cancelNotif)
        await transport.simulateIncoming(cancelData)

        try await Task.sleep(nanoseconds: 100_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies that `close()` cancels pending server-to-client request continuations.
    func testSessionCloseCancelsPendingRequests() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try? await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        try await session.close()

        let val = await task.value
        XCTAssertNil(val)
    }

    /// Verifies `sendProgress(progressToken:progress:total:)`.
    func testSendProgress() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)

        try await session.sendProgress(progressToken: .string("token123"), progress: 50.0, total: 100.0)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let notif = try XCTUnwrap(messages.first as? JSONRPCNotification<ProgressNotificationParams>)
        XCTAssertEqual(notif.method, "notifications/progress")
        XCTAssertEqual(notif.params?.progressToken, .string("token123"))
        XCTAssertEqual(notif.params?.progress, 50.0)
        XCTAssertEqual(notif.params?.total, 100.0)
    }

    /// Verifies `createMessage(params:)` server-initiated sampling request.
    func testCreateMessage() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            let params = CreateMessageRequestParams(messages: [], maxTokens: 100)
            return try await session.createMessage(params: params)
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)

        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<CreateMessageRequestParams>)

        let resultObj = CreateMessageResult(role: .assistant, content: .text(TextContent(text: "Hello")), model: "test-model")
        let resultData = try JSONEncoder().encode(resultObj)
        let resultAny = try JSONDecoder().decode(AnyCodable.self, from: resultData)

        let resp = JSONRPCResponse(id: req.id, result: resultAny)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.role, .assistant)
        XCTAssertEqual(result.model, "test-model")
    }
}
