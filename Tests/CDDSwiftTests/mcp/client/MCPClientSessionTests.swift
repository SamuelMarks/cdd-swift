import XCTest
@testable import CDDSwift

final class MockTransportForClient: MCPTransport, @unchecked Sendable {
    var sentMessages: [Any] = []
    var onMessageCallback: ((Data) async -> Void)?
    var closeCalled = false

    func send<T: Encodable>(_ message: T) async throws {
        sentMessages.append(message)
    }

    func start(onMessage: @escaping (Data) async -> Void) async throws {
        onMessageCallback = onMessage
    }

    func close() async throws {
        closeCalled = true
    }
}

final class MCPClientSessionTests: XCTestCase {
    func testStartDeallocated() async throws {
        let transport = MockTransportForClient()
        var session: MCPClientSession? = MCPClientSession(transport: transport)
        try await session?.start()
        let cb = transport.onMessageCallback
        session = nil
        // Callback should just return and do nothing
        await cb?(Data("{}".utf8))
    }

    func testCloseCancelsPendingRequests() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "pending", params: AnyCodable("test"))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        try await session.close()
        XCTAssertTrue(transport.closeCalled)

        do {
            _ = try await task.value
            XCTFail("Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testProcessIncomingDataFallthrough() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()
        let json = "{\"invalid_jsonrpc\":\"3.0\"}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)
        // Should do nothing without crashing
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

    func testProcessIncomingDataClientRequestSuccess() async throws {
        final class CustomRouter: MCPClientRouter, @unchecked Sendable {
            func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
                return AnyCodable("success")
            }

            func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async {}
        }
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport, router: CustomRouter())
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"do_work\"}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let resp = transport.sentMessages.first as? JSONRPCResponse<AnyCodable> {
            XCTAssertEqual(resp.id, .integer(10))
            XCTAssertEqual(resp.result, AnyCodable("success"))
        } else {
            XCTFail("Expected success response")
        }
    }

    func testProcessIncomingDataClientRequestGeneralError() async throws {
        struct GeneralError: Error {}
        final class CustomRouterError: MCPClientRouter, @unchecked Sendable {
            func handleRequest(request _: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
                throw GeneralError()
            }

            func handleNotification(notification _: JSONRPCNotification<AnyCodable>) async {}
        }
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport, router: CustomRouterError())
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"do_error\"}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let resp = transport.sentMessages.first as? JSONRPCError {
            XCTAssertEqual(resp.id, .integer(11))
            XCTAssertEqual(resp.error.code, JSONRPCErrorCode.internalError.rawValue)
        } else {
            XCTFail("Expected error response")
        }
    }

    func testProcessIncomingDataResponseNoResult() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test_empty_result", params: AnyCodable("foo"))
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<AnyCodable>, case let .integer(reqId) = req.id else {
            XCTFail("Expected JSONRPCRequest with integer ID")
            return
        }

        // Response with no result and no error
        let json = "{\"jsonrpc\":\"2.0\",\"id\":\(reqId)}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result, AnyCodable([String: String]()))
    }

    func testInitialize() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.initialize(serverVersion: "1.0")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(transport.sentMessages.count, 1)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<InitializeRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let initResult = InitializeResult(
            _meta: nil,
            protocolVersion: "1.0",
            capabilities: ServerCapabilities(),
            serverInfo: Implementation(name: "mock-server", version: "1.0.0"),
            instructions: nil
        )
        let resp = JSONRPCResponse<InitializeResult>(id: req.id, result: initResult)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.serverInfo.name, "mock-server")
    }

    func testListTools() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllTools()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req1 = transport.sentMessages.first as? JSONRPCRequest<ListToolsRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let toolsResult1 = ListToolsResult(_meta: nil, nextCursor: "page2", tools: [Tool(name: "tool1", inputSchema: ToolInputSchema(type: "object"))])
        let resp1 = JSONRPCResponse<ListToolsResult>(id: req1.id, result: toolsResult1)
        let data1 = try JSONEncoder().encode(resp1)
        await transport.onMessageCallback?(data1)

        try await Task.sleep(nanoseconds: 10_000_000)

        guard transport.sentMessages.count == 2, let req2 = transport.sentMessages.last as? JSONRPCRequest<ListToolsRequestParams> else {
            XCTFail("Expected 2nd JSONRPCRequest")
            return
        }
        XCTAssertEqual(req2.params?.cursor, "page2")

        let toolsResult2 = ListToolsResult(_meta: nil, nextCursor: nil, tools: [Tool(name: "tool2", inputSchema: ToolInputSchema(type: "object"))])
        let resp2 = JSONRPCResponse<ListToolsResult>(id: req2.id, result: toolsResult2)
        let data2 = try JSONEncoder().encode(resp2)
        await transport.onMessageCallback?(data2)

        let result = try await task.value
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "tool1")
        XCTAssertEqual(result[1].name, "tool2")
    }

    func testExecuteTool() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.executeTool(name: "my_tool", arguments: ["foo": AnyCodable("bar")])
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<CallToolRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let toolResult = CallToolResult(
            _meta: nil,
            content: [AnyCodable(["type": "text", "text": "success"])],
            isError: false
        )
        let resp = JSONRPCResponse<CallToolResult>(id: req.id, result: toolResult)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertFalse(result.isError == true)
        XCTAssertEqual(result.content.count, 1)
    }

    func testDefaultRouter() async throws {
        let router = DefaultMCPClientRouter()

        do {
            _ = try await router.handleRequest(request: JSONRPCRequest(id: .integer(1), method: "test"))
            XCTFail("Expected error")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.code, -32601)
        } catch {
            XCTFail("Unexpected error type")
        }

        try await router.handleNotification(notification: JSONRPCNotification(method: "test"))
    }

    func testProcessIncomingDataError() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32600,\"message\":\"bad\"}}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

    func testProcessIncomingDataNotification() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"method\":\"notif\"}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(transport.sentMessages.count, 0)
    }

    func testProcessIncomingDataRequest() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"req\"}\n"
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.onMessageCallback?(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(transport.sentMessages.count, 1)
        if let errResp = transport.sentMessages.first as? JSONRPCError {
            XCTAssertEqual(errResp.id, .integer(2))
            XCTAssertEqual(errResp.error.code, -32601) // methodNotFound
        } else {
            XCTFail("Expected error response")
        }
    }

    func testSendRequestAndHandleError() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.sendRequest(method: "test", params: AnyCodable("foo"))
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<AnyCodable> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let errResp = JSONRPCError(id: req.id, error: JSONRPCErrorDetail(code: .internalError, message: "failed"))
        let data = try JSONEncoder().encode(errResp)
        await transport.onMessageCallback?(data)

        do {
            _ = try await task.value
            XCTFail("Expected error")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.message, "failed")
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSendRequestTransportError() async throws {
        struct ThrowingTransport: MCPTransport, @unchecked Sendable {
            func send<T: Encodable>(_: T) async throws {
                throw JSONRPCErrorDetail(code: .internalError, message: "transport err")
            }

            func start(onMessage _: @escaping (Data) async -> Void) async throws {}
            func close() async throws {}
        }

        let session = MCPClientSession(transport: ThrowingTransport())
        do {
            _ = try await session.sendRequest(method: "test", params: AnyCodable("foo"))
            XCTFail("Expected error")
        } catch let err as JSONRPCErrorDetail {
            XCTAssertEqual(err.message, "transport err")
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSendNotification() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.sendNotification(method: "test", params: AnyCodable("hi"))
        XCTAssertEqual(transport.sentMessages.count, 1)
    }

    func testListResources() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllResources()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<ListResourcesRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let res = Resource(uri: "test", name: "test_res")
        let resourcesResult = ListResourcesResult(_meta: nil, nextCursor: nil, resources: [res])
        let resp = JSONRPCResponse<ListResourcesResult>(id: req.id, result: resourcesResult)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].uri, "test")
    }

    func testListResourceTemplates() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllResourceTemplates()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<ListResourceTemplatesRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let template = ResourceTemplate(uriTemplate: "test_template", name: "template1")
        let templatesResult = ListResourceTemplatesResult(_meta: nil, nextCursor: nil, resourceTemplates: [template])
        let resp = JSONRPCResponse<ListResourceTemplatesResult>(id: req.id, result: templatesResult)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "template1")
    }

    func testReadResource() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.readResource(uri: "test_uri")
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        guard let req = transport.sentMessages.first as? JSONRPCRequest<ReadResourceRequestParams> else {
            XCTFail("Expected JSONRPCRequest")
            return
        }

        let textContent = TextResourceContents(uri: "test_uri", text: "resource content")
        let readResult = ReadResourceResult(_meta: nil, contents: [.text(textContent)])
        let resp = JSONRPCResponse<ReadResourceResult>(id: req.id, result: readResult)
        let data = try JSONEncoder().encode(resp)
        await transport.onMessageCallback?(data)

        let result = try await task.value
        XCTAssertEqual(result.contents.count, 1)
        if case let .text(content) = result.contents[0] {
            XCTAssertEqual(content.text, "resource content")
        } else {
            XCTFail("Expected text content")
        }
    }
}

extension MCPClientSessionTests {
    func testSendProgress() async throws {
        let transport = MockTransportForClient()
        let router = DefaultMCPClientRouter()
        let session = MCPClientSession(transport: transport, router: router)

        try await session.sendProgress(progressToken: .integer(123), progress: 10.0, total: nil)
        XCTAssertEqual(transport.sentMessages.count, 1)
        if let notif = transport.sentMessages.first as? JSONRPCNotification<ProgressNotificationParams> {
            XCTAssertEqual(notif.method, "notifications/progress")
            XCTAssertEqual(notif.params?.progressToken, .integer(123))
            XCTAssertEqual(notif.params?.progress, 10.0)
            XCTAssertNil(notif.params?.total)
        } else {
            XCTFail("Expected JSONRPCNotification<ProgressNotificationParams>")
        }
    }
}
