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
        XCTAssertFalse(Parser.parse(source: emitted).hasError)
    }

    /// Verifies emitting multiple webhooks with typed and fallback payloads and valid Swift syntax.
    func testEmitWebhooksMultiple() {
        let paths = [
            "/hookB": PathItem(post: Operation(
                operationId: "onHookB",
                requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/HookEvent"))])
            )),
            "/hookA": PathItem(post: Operation())
        ]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("func onHookA(payload: AnyCodable)"))
        XCTAssertTrue(emitted.contains("func onHookB(payload: HookEvent)"))
        XCTAssertFalse(Parser.parse(source: emitted).hasError)
    }

    /// Verifies `FunctionVisitor` parsing of `WebhooksDelegate`, `*Callbacks` protocols, and non-webhook declarations.
    func testFunctionsParse() {
        let code = """
        func testFunc() {}
        public protocol OtherProtocol {
            func doNothing()
        }
        public protocol EmptyCallbacks {}
        public protocol WebhooksDelegate {
            var ignoredProp: Int { get }
            func onSubscriptionRenewal(payload: RenewalEvent) async throws
            func customWebhook() async throws
            func on() async throws
            func ongoingTask(payload: String) async throws
        }
        public protocol CreateOrderCallbacks {
            var ignoredProp: Int { get }
            func onOrderShipped(payload: ShipmentPayload) async throws
        }
        """
        let syntax = Parser.parse(source: code)
        let visitor = FunctionVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertEqual(visitor.webhooks.count, 4)
        XCTAssertNotNil(visitor.webhooks["subscriptionrenewal"])
        XCTAssertEqual(
            visitor.webhooks["subscriptionrenewal"]?.post?.requestBody?.content?["application/json"]?.schema?.ref,
            "#/components/schemas/RenewalEvent"
        )
        XCTAssertNotNil(visitor.webhooks["customwebhook"])
        XCTAssertNotNil(visitor.webhooks["on"])
        XCTAssertNotNil(visitor.webhooks["ongoingtask"])
        XCTAssertEqual(visitor.callbacks.count, 1)
        XCTAssertEqual(
            visitor.callbacks["createOrder"]?["{$request.query.callbackUrl}"]?.post?.requestBody?.content?["application/json"]?.schema?.ref,
            "#/components/schemas/ShipmentPayload"
        )
    }
}
