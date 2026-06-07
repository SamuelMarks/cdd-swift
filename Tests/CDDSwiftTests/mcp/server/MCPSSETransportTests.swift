import XCTest
@testable import CDDSwift

final class MCPSSETransportTests: XCTestCase {
    func testSend() async throws {
        var emittedEvents: [(String, Data)] = []
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            emittedEvents.append((event, data))
        }

        let message = JSONRPCNotification(method: "test", params: AnyCodable("data"))
        try await transport.send(message)

        XCTAssertEqual(emittedEvents.count, 1)
        XCTAssertEqual(emittedEvents[0].0, "message")
        let decoded = try JSONDecoder().decode(JSONRPCNotification<AnyCodable>.self, from: emittedEvents[0].1)
        XCTAssertEqual(decoded.method, "test")
    }

    func testStartAndHandleIncomingPost() async throws {
        var emittedEvents: [(String, Data)] = []
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            emittedEvents.append((event, data))
        }

        var receivedMessages: [Data] = []
        try await transport.start { data in
            receivedMessages.append(data)
        }

        XCTAssertEqual(emittedEvents.count, 1)
        XCTAssertEqual(emittedEvents[0].0, "endpoint")
        let endpointStr = try JSONDecoder().decode(String.self, from: emittedEvents[0].1)
        XCTAssertEqual(endpointStr, "http://localhost/mcp/message")

        let dummyData = "dummy".data(using: .utf8)!
        try await transport.handleIncomingPost(data: dummyData)
        XCTAssertEqual(receivedMessages.count, 1)
        XCTAssertEqual(receivedMessages[0], dummyData)
    }

    func testHandleIncomingPostBeforeStartThrows() async throws {
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in }
        do {
            try await transport.handleIncomingPost(data: Data())
            XCTFail("Expected error")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.message, "Transport not started or closed")
        }
    }

    func testClose() async throws {
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in }
        try await transport.start { _ in }
        try await transport.close()

        do {
            try await transport.handleIncomingPost(data: Data())
            XCTFail("Expected error")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.message, "Transport not started or closed")
        }
    }
}
