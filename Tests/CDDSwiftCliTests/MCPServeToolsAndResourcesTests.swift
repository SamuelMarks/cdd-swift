/// Unit tests for `MCPServe` tool execution, resource reading, and transport resolution.
import CDDSwift
@testable import cdd_swift_cli
import Foundation
import XCTest

extension MCPServeTests {
    /// Verifies `tools/call` returns `-32602` when required arguments for `generate_from_openapi` are missing.
    func testMCPServeToolsCallMissingArgs() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let callParams = CallToolRequestParams(name: "generate_from_openapi")
        let req = JSONRPCRequest(id: .integer(5), method: "tools/call", params: callParams)
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(5))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` succeeds for `generate_from_openapi`.
    func testMCPServeToolsCallSuccess() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in.json")
        try? #"{"openapi": "3.2.0", "info": {"title": "Dummy", "version": "1.0.0"}, "paths": {}}"#.write(
            to: dummyIn,
            atomically: true,
            encoding: .utf8
        )
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_out").path

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let callParams = CallToolRequestParams(
            name: "generate_from_openapi",
            arguments: ["input_path": AnyCodable(dummyIn.path), "output_dir": AnyCodable(dummyOut)]
        )
        let req = JSONRPCRequest(id: .integer(6), method: "tools/call", params: callParams)
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let res = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(res.id, .integer(6))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/list` returns `"cdd-swift://ast"`.
    func testMCPServeResourcesList3() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(id: .integer(7), method: "resources/list")
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(7))
        let resultData = try JSONEncoder().encode(response.result)
        let result = try JSONDecoder().decode(ListResourcesResult.self, from: resultData)
        XCTAssertEqual(result.resources.count, 1)
        XCTAssertEqual(result.resources[0].uri, "cdd-swift://ast")

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/read` for `"cdd-swift://ast"`.
    func testMCPServeResourcesRead3() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest(id: .integer(8), method: "resources/read", params: AnyCodable(["uri": "cdd-swift://ast"]))
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let response = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(response.id, .integer(8))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/read` returns `-32602` for an unknown resource URI.
    func testMCPServeResourcesReadUnknown() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest(id: .integer(9), method: "resources/read", params: AnyCodable(["uri": "unknown://uri"]))
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(9))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `resources/read` returns `-32602` when `uri` is missing from params.
    func testMCPServeResourcesReadMissingParams() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest(id: .integer(10), method: "resources/read", params: AnyCodable(["wrong": "uri"]))
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(10))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` for `to_openapi` with missing `output_path`.
    func testMCPServeToolsCallToOpenAPIMissingArgs() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(
            id: .integer(11),
            method: "tools/call",
            params: ["name": "to_openapi", "arguments": ["input_path": "a"]]
        )
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(11))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` for `to_docs_json` with missing `input_path`.
    func testMCPServeToolsCallToDocsJsonMissingArgs() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(
            id: .integer(12),
            method: "tools/call",
            params: ["name": "to_docs_json", "arguments": ["output_path": "a"]]
        )
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let err = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(err.id, .integer(12))
        XCTAssertEqual(err.error.code, -32602)

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` for `to_openapi` with valid arguments.
    func testMCPServeToolsCallToOpenAPI() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_swift.swift")
        try? "struct TestModel: Codable {}".write(to: dummyIn, atomically: true, encoding: .utf8)
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("out.json").path

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(
            id: .integer(13),
            method: "tools/call",
            params: ["name": "to_openapi", "arguments": ["input_path": AnyCodable(dummyIn.path), "output_path": AnyCodable(dummyOut)]]
        )
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let res = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(res.id, .integer(13))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `tools/call` for `to_docs_json` with valid arguments.
    func testMCPServeToolsCallToDocsJson() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)

        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in.json")
        try? #"{"openapi": "3.2.0", "info": {"title": "Dummy", "version": "1.0.0"}, "paths": {}}"#.write(
            to: dummyIn,
            atomically: true,
            encoding: .utf8
        )
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("docs.json").path

        var serve = MCPServe()
        let task = Task {
            try await serve.run()
        }

        try await mockTransport.waitUntilStarted()

        let req = JSONRPCRequest<AnyCodable>(
            id: .integer(14),
            method: "tools/call",
            params: ["name": "to_docs_json", "arguments": ["input_path": AnyCodable(dummyIn.path), "output_path": AnyCodable(dummyOut)]]
        )
        let data = try JSONEncoder().encode(req)
        await mockTransport.simulateIncoming(data)

        let messages = await mockTransport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let res = try XCTUnwrap(messages.first as? JSONRPCResponse<AnyCodable>)
        XCTAssertEqual(res.id, .integer(14))

        try await mockTransport.close()
        try await task.value
    }

    /// Verifies `MCPServe` startup and clean shutdown.
    func testMCPServeBlockingLoop() async throws {
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)
        setenv("CDD_TEST_BLOCK", "1", 1)

        var serve = MCPServe()
        let task = Task { try await serve.run() }
        try await mockTransport.waitUntilStarted()
        try await mockTransport.close()
        try await task.value
        unsetenv("CDD_TEST_BLOCK")
    }

    /// Verifies `MCPServe` default `MCPStdioTransport` resolution when no override transport is set.
    func testMCPServeRealTransport() async throws {
        await MCPServeRuntime.shared.setTransport(nil)
        let resolved = await MCPServeRuntime.shared.resolveTransport()
        XCTAssertTrue(resolved is MCPStdioTransport)
        let mockTransport = MockMCPTransport()
        await MCPServeRuntime.shared.setTransport(mockTransport)
        var cmd = try MCPServe.parse([])
        let task = Task {
            try await cmd.run()
        }
        try await mockTransport.waitUntilStarted()
        try await mockTransport.close()
        try await task.value
        await MCPServeRuntime.shared.setTransport(nil)
    }
}
