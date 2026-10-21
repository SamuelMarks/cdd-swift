/// Unit tests for `MCPSSETransport` Server-Sent Events and HTTP POST bridging.
import XCTest
@testable import CDDSwift

/// Actor-isolated capture container for `MCPSSETransportTests`.
private actor SSETestCapture {
    /// Emitted `(event, data)` pairs.
    var emittedEvents: [(String, Data)] = []
    /// Received incoming POST message payloads.
    var receivedMessages: [Data] = []
    /// Generic invocation counter.
    var count = 0

    /// Appends an emitted SSE event.
    ///
    /// - Parameters:
    ///   - event: The SSE event name.
    ///   - data: The SSE event data.
    func recordEvent(_ event: String, _ data: Data) {
        emittedEvents.append((event, data))
    }

    /// Appends a received POST message payload.
    ///
    /// - Parameter data: The received `Data`.
    func recordMessage(_ data: Data) {
        receivedMessages.append(data)
    }

    /// Increments `count` by 1.
    func increment() {
        count += 1
    }

    /// Returns all recorded SSE events.
    func events() -> [(String, Data)] {
        return emittedEvents
    }

    /// Returns all recorded POST messages.
    func messages() -> [Data] {
        return receivedMessages
    }

    /// Returns the current `count`.
    func currentCount() -> Int {
        return count
    }
}

/// Test suite verifying `MCPSSETransport` event emission, POST handling, and closure.
final class MCPSSETransportTests: XCTestCase {
    /// Verifies `send(_:)` emits a `"message"` SSE event with the JSON-encoded payload.
    func testSend() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            await capture.recordEvent(event, data)
        }

        let message = JSONRPCNotification(method: "test", params: AnyCodable("data"))
        try await transport.send(message)

        let events = await capture.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].0, "message")
        let decoded = try JSONDecoder().decode(JSONRPCNotification<AnyCodable>.self, from: events[0].1)
        XCTAssertEqual(decoded.method, "test")
    }

    /// Verifies `start(onMessage:)` emits the `"endpoint"` SSE event and forwards `handleIncomingPost(data:)`.
    func testStartAndHandleIncomingPost() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { event, data in
            await capture.recordEvent(event, data)
        }

        try await transport.start { data in
            await capture.recordMessage(data)
        }

        let events = await capture.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].0, "endpoint")
        let endpointStr = try JSONDecoder().decode(String.self, from: events[0].1)
        XCTAssertEqual(endpointStr, "http://localhost/mcp/message")

        let dummyData = Data("dummy".utf8)
        try await transport.handleIncomingPost(data: dummyData)
        let messages = await capture.messages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0], dummyData)
    }

    /// Verifies that calling `handleIncomingPost(data:)` before `start` throws an error.
    func testHandleIncomingPostBeforeStartThrows() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in
            await capture.increment()
        }
        try await transport.send(JSONRPCNotification(method: "test", params: AnyCodable("data")))
        let count = await capture.currentCount()
        XCTAssertEqual(count, 1)
        let result: Void? = try? await transport.handleIncomingPost(data: Data())
        XCTAssertNil(result)
    }

    /// Verifies that `close()` deactivates the transport and causes subsequent `handleIncomingPost(data:)` calls to throw.
    func testClose() async throws {
        let capture = SSETestCapture()
        let transport = try MCPSSETransport(endpoint: XCTUnwrap(URL(string: "http://localhost/mcp/message"))) { _, _ in }
        try await transport.start { _ in
            await capture.increment()
        }
        try await transport.handleIncomingPost(data: Data("msg".utf8))
        let count = await capture.currentCount()
        XCTAssertEqual(count, 1)
        try await transport.close()

        let result: Void? = try? await transport.handleIncomingPost(data: Data())
        XCTAssertNil(result)
    }
}
