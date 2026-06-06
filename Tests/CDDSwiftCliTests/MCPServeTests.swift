import XCTest
@testable import cdd_swift_cli
@testable import CDDSwift

final class MockMCPTransport: MCPTransport, @unchecked Sendable {
    var messagesSent: [Any] = []
    var isStarted = false
    var onMessageCallback: ((Data) async -> Void)?
    var closeCalled = false

    func send<T: Encodable>(_ message: T) async throws {
        messagesSent.append(message)
    }

    func start(onMessage: @escaping (Data) async -> Void) async throws {
        isStarted = true
        onMessageCallback = onMessage

        while !closeCalled {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func close() async throws {
        closeCalled = true
    }
}

final class MCPServeTests: XCTestCase {
    func testMCPServeInitialize() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        // Wait for server to start
        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Simulate receiving an initialize request
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
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let response = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(response.id, .integer(1))
            // Decode back to InitializeResult to assert
            if let resultData = try? JSONEncoder().encode(response.result),
               let result = try? JSONDecoder().decode(InitializeResult.self, from: resultData)
            {
                XCTAssertEqual(result.protocolVersion, "2024-11-05")
            } else {
                XCTFail("Failed to decode InitializeResult from AnyCodable")
            }
        } else {
            XCTFail("Expected JSONRPCResponse<AnyCodable>")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServePing() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Simulate receiving a ping request
        let req = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "ping")
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let response = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(response.id, .integer(2))
        } else {
            XCTFail("Expected JSONRPCResponse<EmptyResult>")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServeInitializedNotification() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Simulate receiving an initialized notification
        let notif = JSONRPCNotification<AnyCodable>(method: "notifications/initialized")
        let data = try JSONEncoder().encode(notif)
        await mockTransport.onMessageCallback?(data)

        try await mockTransport.close()
        try await task.value

        XCTAssertEqual(mockTransport.messagesSent.count, 0)
    }

    func testMCPServeToolsList() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let req = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "tools/list")
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let response = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(response.id, .integer(3))

            if let resultData = try? JSONEncoder().encode(response.result),
               let result = try? JSONDecoder().decode(ListToolsResult.self, from: resultData)
            {
                XCTAssertEqual(result.tools.count, 1)
                XCTAssertEqual(result.tools[0].name, "generate_from_openapi")
            } else {
                XCTFail("Failed to decode ListToolsResult")
            }
        } else {
            XCTFail("Expected JSONRPCResponse<AnyCodable>")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServeToolsCallInvalidName() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // no name parameter
        let req = JSONRPCRequest(id: .integer(4), method: "tools/call", params: AnyCodable(["arguments": ["a": "b"]]))
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let err = mockTransport.messagesSent.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(4))
            XCTAssertEqual(err.error.code, -32602)
        } else {
            XCTFail("Expected JSONRPCError")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServeToolsCallUnknownTool() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let req = JSONRPCRequest(id: .integer(4), method: "tools/call", params: AnyCodable(["name": "unknown_tool", "arguments": [:]]))
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let err = mockTransport.messagesSent.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(4))
            XCTAssertEqual(err.error.code, -32601)
        } else {
            XCTFail("Expected JSONRPCError")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServeToolsCallMissingArgs() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let callParams = CallToolRequestParams(name: "generate_from_openapi") // missing arguments
        let req = JSONRPCRequest(id: .integer(5), method: "tools/call", params: callParams)
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let err = mockTransport.messagesSent.first as? JSONRPCError {
            XCTAssertEqual(err.id, .integer(5))
            XCTAssertEqual(err.error.code, -32602) // invalid params
        } else {
            XCTFail("Expected JSONRPCError")
        }

        try await mockTransport.close()
        try await task.value
    }

    func testMCPServeToolsCallSuccess() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let callParams = CallToolRequestParams(name: "generate_from_openapi", arguments: ["input_path": AnyCodable("in"), "output_dir": AnyCodable("out")])
        let req = JSONRPCRequest(id: .integer(6), method: "tools/call", params: callParams)
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockTransport.messagesSent.count, 1)
        if let res = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(res.id, .integer(6))
        } else {
            XCTFail("Expected JSONRPCResponse")
        }

        try await mockTransport.close()
        try await task.value
    }
}
