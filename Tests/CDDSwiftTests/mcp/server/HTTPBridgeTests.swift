/// Unit tests for `DefaultHTTPRequestContext` and `APIToolProxy` HTTP-to-MCP bridging.
import XCTest
@testable import CDDSwift

/// Test suite verifying `DefaultHTTPRequestContext` and `APIToolProxy`.
final class HTTPBridgeTests: XCTestCase {
    /// Verifies `DefaultHTTPRequestContext` initialization and stored properties.
    func testDefaultContext() {
        let ctx = DefaultHTTPRequestContext(authorizationHeader: "Bearer token123", clientIP: "127.0.0.1")
        XCTAssertEqual(ctx.authorizationHeader, "Bearer token123")
        XCTAssertEqual(ctx.clientIP, "127.0.0.1")

        let ctxFromHeaders = DefaultHTTPRequestContext(headers: [
            "Authorization": "Bearer abc",
            "X-Forwarded-For": "10.0.0.1, 10.0.0.2"
        ])
        XCTAssertEqual(ctxFromHeaders.authorizationHeader, "Bearer abc")
        XCTAssertEqual(ctxFromHeaders.clientIP, "10.0.0.1")

        let ctxOverrideIP = DefaultHTTPRequestContext(headers: ["X-Real-IP": "192.168.1.1"], clientIP: "127.0.0.9")
        XCTAssertNil(ctxOverrideIP.authorizationHeader)
        XCTAssertEqual(ctxOverrideIP.clientIP, "127.0.0.9")
    }

    /// Verifies `DynamicAPIToolProxy` tool execution, HTTP context bridging, and `DefaultMCPServerRouter` integration.
    func testDynamicAPIToolProxyAndRouter() async throws {
        let tool = Tool(name: "getUser", description: "Fetch user", inputSchema: ToolInputSchema(type: "object"))
        let proxy = DynamicAPIToolProxy(
            tools: [tool],
            handlers: [
                "getUser": { args, ctx in
                    let id = args["id"]?.stringValue ?? "none"
                    let auth = ctx?.authorizationHeader ?? "anon"
                    return CallToolResult(content: [AnyCodable(["type": "text", "text": "\(id):\(auth)"])])
                }
            ]
        )

        let ctx = DefaultHTTPRequestContext(authorizationHeader: "Bearer secret", clientIP: "127.0.0.1")
        let direct = try await proxy.execute(toolName: "getUser", arguments: ["id": "42"], context: ctx)
        XCTAssertEqual(direct.content.count, 1)

        let directNilCtx = try await proxy.execute(toolName: "getUser", arguments: [:], context: nil)
        XCTAssertEqual(directNilCtx.content.count, 1)

        let missingResult = try? await proxy.execute(toolName: "missing", arguments: [:], context: nil)
        XCTAssertNil(missingResult)

        let router = proxy.makeRouter(context: ctx)
        let listResp = try await router.handleRequest(request: JSONRPCRequest(id: .integer(1), method: "tools/list", params: nil))
        XCTAssertNotNil(listResp.objectValue?["tools"])

        let callParams = AnyCodable(["name": AnyCodable("getUser"), "arguments": AnyCodable(["id": AnyCodable("99")])])
        let callResp = try await router.handleRequest(request: JSONRPCRequest(id: .integer(2), method: "tools/call", params: callParams))
        XCTAssertNotNil(callResp.objectValue?["content"])

        let callNoArgs = AnyCodable(["name": AnyCodable("getUser")])
        let callNoArgsResp = try await router.handleRequest(
            request: JSONRPCRequest(id: .integer(3), method: "tools/call", params: callNoArgs)
        )
        XCTAssertNotNil(callNoArgsResp.objectValue?["content"])

        let invalidParamsResult = try? await router.handleRequest(
            request: JSONRPCRequest(id: .integer(4), method: "tools/call", params: nil)
        )
        XCTAssertNil(invalidParamsResult)
    }

    /// Mock implementation of `APIToolProxy` for testing context propagation.
    struct MockToolProxy: APIToolProxy {
        /// Executes the named tool with the given arguments and optional HTTP request context.
        ///
        /// - Parameters:
        ///   - toolName: The name of the MCP tool.
        ///   - arguments: Dictionary of tool arguments.
        ///   - context: Optional HTTP request context.
        /// - Returns: A `CallToolResult` containing the execution message.
        func execute(toolName: String, arguments _: [String: AnyCodable], context: HTTPRequestContext?) async throws -> CallToolResult {
            if let ctx = context {
                let text = TextContent(text: "Executed \(toolName) with auth: \(ctx.authorizationHeader ?? "none")")
                return CallToolResult(content: [AnyCodable(["type": text.type, "text": text.text])])
            }
            return CallToolResult(content: [])
        }
    }

    /// Verifies `APIToolProxy.execute` with authenticated, unauthenticated, and `nil` contexts.
    func testAPIToolProxy() async throws {
        let proxy = MockToolProxy()
        let ctx = DefaultHTTPRequestContext(authorizationHeader: "auth", clientIP: "ip")

        let result = try await proxy.execute(toolName: "test_tool", arguments: [:], context: ctx)
        XCTAssertEqual(result.content.count, 1)

        let ctxNoAuth = DefaultHTTPRequestContext(authorizationHeader: nil, clientIP: nil)
        let resultNoAuth = try await proxy.execute(toolName: "test_tool", arguments: [:], context: ctxNoAuth)
        XCTAssertEqual(resultNoAuth.content.count, 1)

        let resultNilCtx = try await proxy.execute(toolName: "test_tool", arguments: [:], context: nil)
        XCTAssertEqual(resultNilCtx.content.count, 0)
    }
}
