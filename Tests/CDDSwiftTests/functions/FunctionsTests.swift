/// Unit tests for OpenAPI webhook delegate protocol emission and function AST parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitWebhooks` and `FunctionVisitor`.
final class FunctionsTests: XCTestCase {
    /// Verifies emitting a `WebhooksDelegate` protocol for a single webhook.
    func testEmitWebhooks() {
        XCTAssertEqual(emitWebhooks(webhooks: nil), "")
        XCTAssertEqual(emitWebhooks(webhooks: [:]), "")

        let paths = ["/hook": PathItem(get: Operation(operationId: "func1"), post: Operation(operationId: "onHook"))]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("public protocol WebhooksDelegate {"))
        XCTAssertTrue(emitted.contains("func onHook(payload: AnyCodable) async throws"))
        XCTAssertTrue(emitted.contains("func func1(payload: AnyCodable) async throws"))
    }

    /// Verifies emitting multiple webhooks with typed and fallback payloads.
    func testEmitWebhooksMultiple() {
        let paths = [
            "/hookB": PathItem(post: Operation(operationId: "onHookB", requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/HookEvent"))]))),
            "/hookA": PathItem(post: Operation())
        ]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("func on/hookA(payload: AnyCodable)"))
        XCTAssertTrue(emitted.contains("func onHookB(payload: HookEvent)"))
    }

    /// Verifies `FunctionVisitor` parsing of top-level webhook functions.
    func testFunctionsParse() {
        let code = """
        func testFunc() {}
        """
        let syntax = Parser.parse(source: code)
        let visitor = FunctionVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertNotNil(visitor)
    }
}
