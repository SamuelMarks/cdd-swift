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

    func testMCPServeResourcesList() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await Task.sleep(nanoseconds: 50_000_000)

        let req = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "resources/list")
        let data = try JSONEncoder().encode(req)
        await mockTransport.onMessageCallback?(data)
        try await Task.sleep(nanoseconds: 50_000_000)

        task.cancel()
    }

    func testMCPServeResourcesRead() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await Task.sleep(nanoseconds: 50_000_000)

        // Read success
        let req1 = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "resources/read", params: AnyCodable(["uri": "cdd-swift://ast"]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req1))

        // Read missing params
        let req2 = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "resources/read", params: AnyCodable([String: String]()))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req2))

        // Read invalid uri
        let req3 = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "resources/read", params: AnyCodable(["uri": "invalid"]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req3))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
    }

    func testMCPServeToolsCallMoreTools() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await Task.sleep(nanoseconds: 50_000_000)

        // to_openapi success
        let req1 = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "tools/call", params: AnyCodable([
            "name": "to_openapi",
            "arguments": ["input_path": "/tmp/cdd_test_empty.json", "output_path": "/tmp/cdd_test_out.json"]
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req1))

        // to_openapi missing args
        let req2 = JSONRPCRequest<AnyCodable>(id: .integer(2), method: "tools/call", params: AnyCodable([
            "name": "to_openapi",
            "arguments": ["input_path": "/tmp/cdd_test_empty.json"]
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req2))

        // to_openapi missing args object completely
        let req2a = JSONRPCRequest<AnyCodable>(id: .integer(20), method: "tools/call", params: AnyCodable([
            "name": "to_openapi"
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req2a))

        // to_docs_json success
        let req3 = JSONRPCRequest<AnyCodable>(id: .integer(3), method: "tools/call", params: AnyCodable([
            "name": "to_docs_json",
            "arguments": ["input_path": "/tmp/cdd_test_empty.json", "output_path": "/tmp/cdd_test_out.json"]
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req3))

        // to_docs_json missing args object completely
        let req4a = JSONRPCRequest<AnyCodable>(id: .integer(40), method: "tools/call", params: AnyCodable([
            "name": "to_docs_json"
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req4a))

        // to_docs_json missing args
        let req4 = JSONRPCRequest<AnyCodable>(id: .integer(4), method: "tools/call", params: AnyCodable([
            "name": "to_docs_json",
            "arguments": ["input_path": "/tmp/cdd_test_empty.json"]
        ]))
        try await mockTransport.onMessageCallback?(JSONEncoder().encode(req4))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
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
                XCTAssertEqual(result.tools.count, 3)
                XCTAssertEqual(result.tools[0].name, "generate_from_openapi")
                XCTAssertEqual(result.tools[1].name, "to_openapi")
                XCTAssertEqual(result.tools[2].name, "to_docs_json")
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

        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in.json")
        try? "{\"openapi\": \"3.2.0\", \"info\": {\"title\": \"Dummy\", \"version\": \"1.0.0\"}, \"paths\": {}}".write(to: dummyIn, atomically: true, encoding: .utf8)
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_out").path

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        while !mockTransport.isStarted {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let callParams = CallToolRequestParams(name: "generate_from_openapi", arguments: ["input_path": AnyCodable(dummyIn.path), "output_dir": AnyCodable(dummyOut)])
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

        func testMCPServeResourcesList() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest<AnyCodable>(id: .integer(7), method: "resources/list")
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let response = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
                XCTAssertEqual(response.id, .integer(7))
                if let resultData = try? JSONEncoder().encode(response.result),
                   let result = try? JSONDecoder().decode(ListResourcesResult.self, from: resultData)
                {
                    XCTAssertEqual(result.resources.count, 1)
                    XCTAssertEqual(result.resources[0].uri, "cdd-swift://ast")
                } else {
                    XCTFail("Failed to decode ListResourcesResult")
                }
            } else {
                XCTFail("Expected JSONRPCResponse<AnyCodable>")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeResourcesRead() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(8), method: "resources/read", params: AnyCodable(["uri": "cdd-swift://ast"]))
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let response = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
                XCTAssertEqual(response.id, .integer(8))
            } else {
                XCTFail("Expected JSONRPCResponse<AnyCodable>")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeResourcesReadUnknown() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(9), method: "resources/read", params: AnyCodable(["uri": "unknown://uri"]))
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let err = mockTransport.messagesSent.first as? JSONRPCError {
                XCTAssertEqual(err.id, .integer(9))
                XCTAssertEqual(err.error.code, -32602)
            } else {
                XCTFail("Expected JSONRPCError")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeResourcesReadMissingParams() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(10), method: "resources/read", params: AnyCodable(["wrong": "uri"]))
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let err = mockTransport.messagesSent.first as? JSONRPCError {
                XCTAssertEqual(err.id, .integer(10))
                XCTAssertEqual(err.error.code, -32602)
            } else {
                XCTFail("Expected JSONRPCError")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeToolsCallToOpenAPIMissingArgs() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(11), method: "tools/call", params: AnyCodable(["name": "to_openapi", "arguments": ["input_path": "a"]])) // missing output
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let err = mockTransport.messagesSent.first as? JSONRPCError {
                XCTAssertEqual(err.id, .integer(11))
                XCTAssertEqual(err.error.code, -32602)
            } else {
                XCTFail("Expected JSONRPCError")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeToolsCallToDocsJsonMissingArgs() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(12), method: "tools/call", params: AnyCodable(["name": "to_docs_json", "arguments": ["output_path": "a"]])) // missing input
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let err = mockTransport.messagesSent.first as? JSONRPCError {
                XCTAssertEqual(err.id, .integer(12))
                XCTAssertEqual(err.error.code, -32602)
            } else {
                XCTFail("Expected JSONRPCError")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeToolsCallToOpenAPI() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_swift.swift")
            try? "struct TestModel: Codable {}".write(to: dummyIn, atomically: true, encoding: .utf8)
            let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("out.json").path

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(13), method: "tools/call", params: AnyCodable(["name": "to_openapi", "arguments": ["input_path": dummyIn.path, "output_path": dummyOut]]))
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let res = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
                XCTAssertEqual(res.id, .integer(13))
            } else {
                XCTFail("Expected JSONRPCResponse")
            }

            try await mockTransport.close()
            try await task.value
        }

        func testMCPServeToolsCallToDocsJson() async throws {
            let mockTransport = MockMCPTransport()
            MCPServe.mockTransport = mockTransport

            let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in.json")
            try? "{\"openapi\": \"3.2.0\", \"info\": {\"title\": \"Dummy\", \"version\": \"1.0.0\"}, \"paths\": {}}".write(to: dummyIn, atomically: true, encoding: .utf8)
            let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("docs.json").path

            var serve = MCPServe()
            let task = Task {
                try await serve.run()
            }

            while !mockTransport.isStarted {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let req = JSONRPCRequest(id: .integer(14), method: "tools/call", params: AnyCodable(["name": "to_docs_json", "arguments": ["input_path": dummyIn.path, "output_path": dummyOut]]))
            let data = try JSONEncoder().encode(req)
            await mockTransport.onMessageCallback?(data)

            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(mockTransport.messagesSent.count, 1)
            if let res = mockTransport.messagesSent.first as? JSONRPCResponse<AnyCodable> {
                XCTAssertEqual(res.id, .integer(14))
            } else {
                XCTFail("Expected JSONRPCResponse")
            }

            try await mockTransport.close()
            try await task.value
        }
    }

    func testMCPServeBlockingLoop() async throws {
        let mockTransport = MockMCPTransport()
        MCPServe.mockTransport = mockTransport
        setenv("CDD_TEST_BLOCK", "1", 1)

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        unsetenv("CDD_TEST_BLOCK")
    }

    func testMCPServeRealTransport() async throws {
        MCPServe.mockTransport = nil
        var cmd = try MCPServe.parse([])
        let task = Task {
            try await cmd.run()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
    }
}
