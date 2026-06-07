import XCTest
@testable import CDDSwift

final class MockTransportForRouter: MCPTransport, @unchecked Sendable {
    var sentMessages: [Any] = []
    var onMessageCallback: ((Data) async -> Void)?

    func send<T: Encodable>(_ message: T) async throws {
        sentMessages.append(message)
    }

    func start(onMessage: @escaping (Data) async -> Void) async throws {
        onMessageCallback = onMessage
    }

    func close() async throws {}
}

final class MCPServerSessionTests: XCTestCase {
    func testStartDeallocated() async throws {
        let transport = MockTransportForRouter()
        var session: MCPServerSession? = MCPServerSession(transport: transport, router: DefaultMCPServerRouter())
        try await session?.start()
        let cb = transport.onMessageCallback
        session = nil
        await cb?(Data("{}".utf8))
    }

    func testSendRequestTransportError() async throws {
        struct ThrowingTransport: MCPTransport, @unchecked Sendable {
            func send<T: Encodable>(_: T) async throws {
                throw GenericError()
            }

            func start(onMessage _: @escaping (Data) async -> Void) async throws {}
            func close() async throws {}
        }
        let session = MCPServerSession(transport: ThrowingTransport(), router: DefaultMCPServerRouter())
        do {
            _ = try await session.sendRequest(method: "test", params: AnyCodable("foo"))
            XCTFail("Expected error")
        } catch is GenericError {
            // expected
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testProcessIncomingDataResponseNoResult() async throws {
        let transport = MockTransportForRouter()
        let session = MCPServerSession(transport: transport, router: DefaultMCPServerRouter())
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test", params: AnyCodable("foo"))
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<AnyCodable>, case let .integer(reqId) = req.id else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let json = "{\"jsonrpc\":\"2.0\",\"id\":\(reqId)}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result, AnyCodable([String: String]()))
    }

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
        try await transport.onMessageCallback?(JSONEncoder().encode(req))
        await fulfillment(of: [startExpectation], timeout: 1.0)

        let cancelParams = CancelledNotificationParams(requestId: .integer(100), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        try await transport.onMessageCallback?(JSONEncoder().encode(cancelNotif))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

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
        try await transport.onMessageCallback?(JSONEncoder().encode(req))
        await fulfillment(of: [startExpectation], timeout: 1.0)

        let cancelParams = CancelledNotificationParams(requestId: .integer(101), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        try await transport.onMessageCallback?(JSONEncoder().encode(cancelNotif))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

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
        await transport.onMessageCallback?(data)

        // Wait briefly for the task to process
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let response = transport.sentMessages.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(response.id, .integer(1))
            XCTAssertEqual(response.result?.value as? String, "ok")
        } else {
            XCTFail("Expected response")
        }
    }

    func testHandleRequestMethodNotFound() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(1), method: "unknown")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let err = transport.sentMessages.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(1))
            XCTAssertEqual(err.error.code, -32601) // methodNotFound
        } else {
            XCTFail("Expected error response")
        }
    }

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
        await transport.onMessageCallback?(data)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleInvalidData() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let data = "invalid".data(using: .utf8)!
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

    func testProcessResponseData() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let resp = JSONRPCResponse(id: .integer(1), result: AnyCodable("ok"))
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0) // Should just drop it for now
    }

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
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let err = transport.sentMessages.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(1))
            XCTAssertEqual(err.error.code, -32602)
        } else {
            XCTFail("Expected JSONRPCError")
        }
    }

    struct GenericError: Error {
        var localizedDescription: String {
            return "Generic error"
        }
    }

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
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let err = transport.sentMessages.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(1))
            XCTAssertEqual(err.error.code, -32603)
        } else {
            XCTFail("Expected JSONRPCError")
        }
    }

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
        await transport.onMessageCallback?(data)

        // This will just hit the catch block and do nothing
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func testSessionClose() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.close() // Does nothing but cover the line
    }

    func testSessionCloseCancelsRunningTasks() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")

        router.requestHandlers["long_task"] = { _ in
            startExpectation.fulfill()
            try await Task.sleep(nanoseconds: 500_000_000)
            return AnyCodable("done")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(42), method: "long_task")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        await fulfillment(of: [startExpectation], timeout: 1.0)
        try await session.close()
    }

    func testSendNotification() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)

        try await session.sendNotification(method: "test/notify", params: AnyCodable(["foo": "bar"]))
        XCTAssertEqual(transport.sentMessages.count, 1)
        if let notif = transport.sentMessages.first as? JSONRPCNotification<AnyCodable> {
            XCTAssertEqual(notif.method, "test/notify")
        } else {
            XCTFail("Expected JSONRPCNotification")
        }
    }

    func testSendRequestAndHandleResponse() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.sentMessages.count, 1)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<AnyCodable> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        // Simulate response from client
        let resp = JSONRPCResponse(id: req.id, result: AnyCodable("response_ok"))
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.value as? String, "response_ok")
    }

    func testSendRequestAndHandleError() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<AnyCodable> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        // Simulate error from client
        let errResp = JSONRPCError(id: req.id, error: JSONRPCErrorDetail(code: .internalError, message: "failed"))
        let data = try JSONEncoder().encode(errResp)
        await transport.onMessageCallback?(data)

        do {
            _ = try await task.value
            XCTFail("Expected error to be thrown")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.message, "failed")
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testIncomingRequestCancellation() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()

        let startExpectation = XCTestExpectation(description: "Handler started")

        router.requestHandlers["long_task"] = { _ in
            startExpectation.fulfill()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            return AnyCodable("done")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<CreateMessageRequestParams>(id: .integer(42), method: "long_task")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        await fulfillment(of: [startExpectation], timeout: 1.0)

        // Send cancel notification
        let cancelParams = CancelledNotificationParams(requestId: .integer(42), reason: "timeout")
        let cancelNotif = JSONRPCNotification(method: "notifications/cancelled", params: cancelParams)
        let cancelData = try JSONEncoder().encode(cancelNotif)
        await transport.onMessageCallback?(cancelData)

        try await Task.sleep(nanoseconds: 600_000_000)

        // Should not have sent a response because it was cancelled
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

    func testSessionCloseCancelsPendingRequests() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test/request", params: AnyCodable(["foo": "bar"]))
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Close session
        try await session.close()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Success
        } catch {
            XCTFail("Unexpected error type")
        }
    }
}

extension MCPServerSessionTests {
    func testSendProgress() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)

        try await session.sendProgress(progressToken: .string("token123"), progress: 50.0, total: 100.0)
        XCTAssertEqual(transport.sentMessages.count, 1)
        if let notif = transport.sentMessages.first as? JSONRPCNotification<ProgressNotificationParams> {
            XCTAssertEqual(notif.method, "notifications/progress")
            XCTAssertEqual(notif.params?.progressToken, .string("token123"))
            XCTAssertEqual(notif.params?.progress, 50.0)
            XCTAssertEqual(notif.params?.total, 100.0)
        } else {
            XCTFail("Expected JSONRPCNotification<ProgressNotificationParams>")
        }
    }
}

extension MCPServerSessionTests {
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
        XCTAssertEqual(transport.sentMessages.count, 1)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<CreateMessageRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let resultObj = CreateMessageResult(role: .assistant, content: .text(TextContent(text: "Hello")), model: "test-model")
        let resultData = try JSONEncoder().encode(resultObj)
        let resultAny = try JSONDecoder().decode(AnyCodable.self, from: resultData)

        let resp = JSONRPCResponse(id: req.id, result: resultAny)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.role, .assistant)
        XCTAssertEqual(result.model, "test-model")
    }
}
