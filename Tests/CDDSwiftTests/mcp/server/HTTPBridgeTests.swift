import XCTest
@testable import CDDSwift

final class HTTPBridgeTests: XCTestCase {
    func testDefaultContext() {
        let ctx = DefaultHTTPRequestContext(authorizationHeader: "Bearer token123", clientIP: "127.0.0.1")
        XCTAssertEqual(ctx.authorizationHeader, "Bearer token123")
        XCTAssertEqual(ctx.clientIP, "127.0.0.1")
    }

    struct MockToolProxy: APIToolProxy {
        func execute(toolName: String, arguments _: [String: Any], context: HTTPRequestContext?) async throws -> CallToolResult {
            if let ctx = context {
                let text = TextContent(text: "Executed \(toolName) with auth: \(ctx.authorizationHeader ?? "none")")
                return CallToolResult(content: [AnyCodable(["type": text.type, "text": text.text])])
            }
            return CallToolResult(content: [])
        }
    }

    func testAPIToolProxy() async throws {
        let proxy = MockToolProxy()
        let ctx = DefaultHTTPRequestContext(authorizationHeader: "auth", clientIP: "ip")

        let result = try await proxy.execute(toolName: "test_tool", arguments: [:], context: ctx)
        XCTAssertEqual(result.content.count, 1)
    }
}
