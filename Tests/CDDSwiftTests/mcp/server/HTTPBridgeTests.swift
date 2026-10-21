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
