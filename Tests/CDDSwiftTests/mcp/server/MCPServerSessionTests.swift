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
    func testHandleRequest() async throws {
        let transport = MockTransportForRouter()
        var router = DefaultMCPServerRouter()
        router.requestHandlers["test"] = { _ in
            AnyCodable("ok")
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        // Wait briefly for the task to process
        try await Task.sleep(nanoseconds: 10_000_000)

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

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "unknown")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

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

        try await Task.sleep(nanoseconds: 10_000_000)
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

        try await Task.sleep(nanoseconds: 10_000_000)
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

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

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

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test")
        let data = try JSONEncoder().encode(req)
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

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
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    func testSessionClose() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.close() // Does nothing but cover the line
    }

    func testProcessErrorDataHit() async throws {
        let transport = MockTransportForRouter()
        let router = DefaultMCPServerRouter()
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":2,\"message\":\"err2\"}}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }
}
