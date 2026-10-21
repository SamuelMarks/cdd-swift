/// Unit tests for `MCPClientSession` incoming frame processing, resource operations, and progress notifications.
import CDDSwift
import XCTest

extension MCPClientSessionTests {
    /// Verifies handling an unmatched `JSONRPCError` frame.
    func testProcessIncomingDataError() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = #"{"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"bad"}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 10_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies handling an incoming server notification.
    func testProcessIncomingDataNotification() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = #"{"jsonrpc":"2.0","method":"notif"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 10_000_000)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 0)
    }

    /// Verifies that an unhandled server request returns `-32601` (`methodNotFound`).
    func testProcessIncomingDataRequest() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let json = #"{"jsonrpc":"2.0","id":2,"method":"req"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        await transport.simulateIncoming(data)

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let errResp = try XCTUnwrap(messages.first as? JSONRPCError)
        XCTAssertEqual(errResp.id, .integer(2))
        XCTAssertEqual(errResp.error.code, -32601)
    }

    /// Verifies rejecting a pending request continuation when a `JSONRPCError` is received.
    func testSendRequestAndHandleError() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try? await session.sendRequest(method: "test", params: AnyCodable("foo"))
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<AnyCodable>)

        let errResp = JSONRPCError(id: req.id, error: JSONRPCErrorDetail(code: .internalError, message: "failed"))
        let data = try JSONEncoder().encode(errResp)
        await transport.simulateIncoming(data)

        let val = await task.value
        XCTAssertNil(val)
    }

    /// Verifies that a transport failure during `sendRequest` cleans up and rejects the continuation.
    func testSendRequestTransportError() async {
        let transport = MockTransportForClient()
        await transport.setShouldThrowOnSend(true)
        let session = MCPClientSession(transport: transport)
        let val = try? await session.sendRequest(method: "test", params: AnyCodable("foo"))
        XCTAssertNil(val)
    }

    /// Verifies `sendNotification(method:params:)`.
    func testSendNotification() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.sendNotification(method: "test", params: AnyCodable("hi"))
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
    }

    /// Verifies `listAllResources()`.
    func testListResources() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllResources()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<ListResourcesRequestParams>)

        let res = Resource(uri: "test", name: "test_res")
        let resourcesResult = ListResourcesResult(_meta: nil, nextCursor: nil, resources: [res])
        let resp = JSONRPCResponse<ListResourcesResult>(id: req.id, result: resourcesResult)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].uri, "test")
    }

    /// Verifies `listAllResourceTemplates()`.
    func testListResourceTemplates() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.listAllResourceTemplates()
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<ListResourceTemplatesRequestParams>)

        let template = ResourceTemplate(uriTemplate: "test_template", name: "template1")
        let templatesResult = ListResourceTemplatesResult(_meta: nil, nextCursor: nil, resourceTemplates: [template])
        let resp = JSONRPCResponse<ListResourceTemplatesResult>(id: req.id, result: templatesResult)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "template1")
    }

    /// Verifies `readResource(uri:)`.
    func testReadResource() async throws {
        let transport = MockTransportForClient()
        let session = MCPClientSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.readResource(uri: "test_uri")
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let messages = await transport.sentMessages()
        let req = try XCTUnwrap(messages.first as? JSONRPCRequest<ReadResourceRequestParams>)

        let textContent = TextResourceContents(uri: "test_uri", text: "resource content")
        let readResult = ReadResourceResult(_meta: nil, contents: [.text(textContent)])
        let resp = JSONRPCResponse<ReadResourceResult>(id: req.id, result: readResult)
        let data = try JSONEncoder().encode(resp)
        await transport.simulateIncoming(data)

        let result = try await task.value
        XCTAssertEqual(result.contents, [.text(textContent)])
    }

    /// Verifies `sendProgress(progressToken:progress:total:)`.
    func testSendProgress() async throws {
        let transport = MockTransportForClient()
        let router = DefaultMCPClientRouter()
        let session = MCPClientSession(transport: transport, router: router)

        try await session.sendProgress(progressToken: .integer(123), progress: 10.0, total: nil)
        let messages = await transport.sentMessages()
        XCTAssertEqual(messages.count, 1)
        let notif = try XCTUnwrap(messages.first as? JSONRPCNotification<ProgressNotificationParams>)
        XCTAssertEqual(notif.method, "notifications/progress")
        XCTAssertEqual(notif.params?.progressToken, .integer(123))
        XCTAssertEqual(notif.params?.progress, 10.0)
        XCTAssertNil(notif.params?.total)
    }
}
