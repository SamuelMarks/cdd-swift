import XCTest
@testable import CDDSwift

private final class SSETestCapture: @unchecked Sendable {
    var emittedEvents: [(String, Data)] = []
    var receivedMessages: [Data] = []
    var count = 0
}

final class MCPSSETransportTests: XCTestCase {
    func testSend() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            capture.emittedEvents.append((event, data))
        }

        let message = JSONRPCNotification(method: "test", params: AnyCodable("data"))
        try await transport.send(message)

        XCTAssertEqual(capture.emittedEvents.count, 1)
        XCTAssertEqual(capture.emittedEvents[0].0, "message")
        let decoded = try JSONDecoder().decode(JSONRPCNotification<AnyCodable>.self, from: capture.emittedEvents[0].1)
        XCTAssertEqual(decoded.method, "test")
    }

    func testStartAndHandleIncomingPost() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            capture.emittedEvents.append((event, data))
        }

        try await transport.start { data in
            capture.receivedMessages.append(data)
        }

        XCTAssertEqual(capture.emittedEvents.count, 1)
        XCTAssertEqual(capture.emittedEvents[0].0, "endpoint")
        let endpointStr = try JSONDecoder().decode(String.self, from: capture.emittedEvents[0].1)
        XCTAssertEqual(endpointStr, "http://localhost/mcp/message")

        let dummyData = Data("dummy".utf8)
        try await transport.handleIncomingPost(data: dummyData)
        XCTAssertEqual(capture.receivedMessages.count, 1)
        XCTAssertEqual(capture.receivedMessages[0], dummyData)
    }

    func testHandleIncomingPostBeforeStartThrows() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in
            capture.count += 1
        }
        try await transport.send(JSONRPCNotification(method: "test", params: AnyCodable("data")))
        XCTAssertEqual(capture.count, 1)
        let result: Void? = try? await transport.handleIncomingPost(data: Data())
        XCTAssertNil(result)
    }

    func testClose() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in }
        try await transport.start { _ in
            capture.count += 1
        }
        try await transport.handleIncomingPost(data: Data("msg".utf8))
        XCTAssertEqual(capture.count, 1)
        try await transport.close()

        let result: Void? = try? await transport.handleIncomingPost(data: Data())
        XCTAssertNil(result)
    }
}
