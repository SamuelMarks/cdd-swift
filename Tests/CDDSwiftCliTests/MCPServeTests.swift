/// Unit tests for `MCPServe` CLI command and `MCPServeRuntime` actor dependency injection.
import XCTest
@testable import cdd_swift_cli
@testable import CDDSwift

/// Actor-isolated state container for `MockMCPTransport`.
private actor MockMCPTransportState {
    /// Recorded outgoing messages.
    var messagesSent: [any Sendable] = []
    /// Registered incoming message handler.
    var onMessageCallback: (@Sendable (Data) async -> Void)?

    /// Appends a sent message.
    ///
    /// - Parameter message: The message to record.
    func recordSend(_ message: any Sendable) {
        messagesSent.append(message)
    }

    /// Registers the incoming message callback.
    ///
    /// - Parameter callback: Incoming message callback.
    func setCallback(_ callback: @escaping @Sendable (Data) async -> Void) {
        onMessageCallback = callback
    }
}

/// Thread-safe mock `MCPTransport` for testing `MCPServe` without `@unchecked Sendable`.
final class MockMCPTransport: MCPTransport {
    /// Actor-isolated state container.
    private let state = MockMCPTransportState()
    /// Buffered stream signaling transport start.
    private let startStream: AsyncStream<Void>
    /// Continuation yielding into `startStream`.
    private let startContinuation: AsyncStream<Void>.Continuation
    /// Buffered stream signaling transport close.
    private let closeStream: AsyncStream<Void>
    /// Continuation yielding into `closeStream`.
    private let closeContinuation: AsyncStream<Void>.Continuation
    /// Buffered stream signaling each sent message.
    private let sendStream: AsyncStream<Void>
    /// Continuation yielding into `sendStream`.
    private let sendContinuation: AsyncStream<Void>.Continuation

    /// Initializes the mock MCP transport.
    init() {
        (startStream, startContinuation) = AsyncStream<Void>.makeStream()
        (closeStream, closeContinuation) = AsyncStream<Void>.makeStream()
        (sendStream, sendContinuation) = AsyncStream<Void>.makeStream()
    }

    /// Records an outgoing message and signals `sendStream`.
    ///
    /// - Parameter message: The `Encodable & Sendable` message to send.
    func send<T: Encodable & Sendable>(_ message: T) async throws {
        await state.recordSend(message)
        sendContinuation.yield()
    }

    /// Starts the mock transport and suspends until `close()` is called.
    ///
    /// - Parameter onMessage: Callback invoked when simulated messages arrive.
    func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws {
        await state.setCallback(onMessage)
        startContinuation.yield()
        var iterator = closeStream.makeAsyncIterator()
        _ = await iterator.next()
    }

    /// Closes the mock transport.
    func close() async throws {
        closeContinuation.yield()
    }

    /// Waits until `start(onMessage:)` has been called on the transport.
    func waitUntilStarted() async throws {
        var iterator = startStream.makeAsyncIterator()
        _ = await iterator.next()
    }

    /// Simulates receiving a raw JSON-RPC `Data` payload.
    ///
    /// - Parameter data: The serialized JSON-RPC payload.
    func simulateIncoming(_ data: Data) async {
        let cb = await state.onMessageCallback
        await cb?(data)
        let isNotification = !String(decoding: data, as: UTF8.self).contains("\"id\":")
        if !isNotification {
            var iterator = sendStream.makeAsyncIterator()
            _ = await iterator.next()
        }
    }

    /// Returns all recorded outgoing messages.
    ///
    /// - Returns: Array of sent messages.
    func sentMessages() async -> [any Sendable] {
        return await state.messagesSent
    }
}

/// Test suite verifying `MCPServe` initialization, tools, resources, and notifications.
final class MCPServeTests: XCTestCase {
    /// Verifies `initialize` request handling on `MCPServe`.
    func testMCPServeInitialize() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest(
            id: .integer(1),
            method: "initialize",
            params: InitializeRequestParams(
                protocolVersion: "2024-11-05",
                capabilities: ClientCapabilities(),
                clientInfo: Implementation(name: "test", version: "1.0")
            )
        )
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(1))
        let resultData = try JSONEncoder().encode(response.result)
        let result = try JSONDecoder().decode(InitializeResult.self, from: resultData)
        XCTAssertEqual(result.protocolVersion, "2024-11-05")

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `ping` request handling on `MCPServe`.
    func testMCPServePing() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "ping")
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(2))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/list` request handling.
    func testMCPServeResourcesList2() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "resources/list")
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/read` across valid, missing, and unknown URIs.
    func testMCPServeResourcesRead2() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await mockTransport.waitUntilStarted()

        let req1 = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "resources/read", params: AnyCodable(["uri": "cdd-swift://ast"]))
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req1))

        let req2 = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "resources/read", params: AnyCodable([String: String]()))
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req2))

        let req3 = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "resources/read", params: AnyCodable(["uri": "invalid"]))
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req3))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` for `to_openapi` and `to_docs_json` with valid and missing arguments.
    func testMCPServeToolsCallMoreTools() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        let dummySwift = FileManager.default.temporaryDirectory.appendingPathComponent("mcp_dummy.swift")
        let dummyJson = FileManager.default.temporaryDirectory.appendingPathComponent("mcp_dummy.json")
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("mcp_out.json")
        defer {
            try? FileManager.default.removeItem(at: dummySwift)
            try? FileManager.default.removeItem(at: dummyJson)
            try? FileManager.default.removeItem(at: dummyOut)
        }
        try "struct M: Codable {}".write(to: dummySwift, atomically: true, encoding: .utf8)
        try #"{"openapi": "3.2.0", "info": {"title": "T", "version": "1.0"}, "paths": {}}"#.write(
            to: dummyJson,
            atomically: true,
            encoding: .utf8
        )

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await mockTransport.waitUntilStarted()

        let req1 = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "tools/call", params: [
            "name": "to_openapi",
            "arguments": ["input_path": AnyCodable(dummySwift.path), "output_path": AnyCodable(dummyOut.path)]
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req1))

        let req2 = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "tools/call", params: [
            "name": "to_openapi",
            "arguments": ["input_path": AnyCodable(dummySwift.path)]
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req2))

        let req2a = JSONRPCRequest<AnyCodable>(id: .integer(20), method: "tools/call", params: [
            "name": "to_openapi"
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req2a))

        let req3 = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "tools/call", params: [
            "name": "to_docs_json",
            "arguments": ["input_path": AnyCodable(dummyJson.path), "output_path": AnyCodable(dummyOut.path)]
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req3))

        let req4a = JSONRPCRequest<AnyCodable>(id: .integer(40), method: "tools/call", params: [
            "name": "to_docs_json"
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req4a))

        let req4 = JSONRPCRequest<AnyCodable>(id: .integer(4), method: "tools/call", params: [
            "name": "to_docs_json",
            "arguments": ["input_path": AnyCodable(dummyJson.path)]
        ])
        try await mockTransport.simulateIncoming(JSONEncoder().encode(req4))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `notifications/initialized` notification handling.
    func testMCPServeInitializedNotification() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let notif = JSONRPCNotification<AnyCodable>(method: "notifications/initialized")
        let data = try JSONEncoder().encode(notif)
        await mockTransport.simulateIncoming(data)

        try await mockTransport.close()
        try await task.value

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies `tools/list` returns the 3 registered CDD tools.
    func testMCPServeToolsList() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "tools/list")
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(3))

        let resultData = try JSONEncoder().encode(response.result)
        let result = try JSONDecoder().decode(ListToolsResult.self, from: resultData)
        XCTAssertEqual(result.tools.count, 3)
        XCTAssertEqual(result.tools[0].name, "generate_from_openapi")
        XCTAssertEqual(result.tools[1].name, "to_openapi")
        XCTAssertEqual(result.tools[2].name, "to_docs_json")

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` returns `-32602` (`invalidParams`) when `name` is missing.
    func testMCPServeToolsCallInvalidName() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(4), method: "tools/call", params: ["arguments": ["a": "b"]])
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(4))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` returns `-32601` (`methodNotFound`) for an unknown tool name.
    func testMCPServeToolsCallUnknownTool() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(4), method: "tools/call", params: ["name": "unknown_tool", "arguments": [:]])
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(4))
        XCTAssertEqual(err.error.code, -32601)

        try await mockTransport.close()
        try await task.value
    }
}
