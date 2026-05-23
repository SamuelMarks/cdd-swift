@testable import CDDSwift
import XCTest

final class FunctionsTests: XCTestCase {
    func testEmitWebhooks() {
        let paths = ["/hook": PathItem(post: Operation(operationId: "onHook"))]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("public protocol WebhooksDelegate {"))
        XCTAssertTrue(emitted.contains("func onHook(payload: AnyCodable) async throws"))
    }

    func testEmitWebhooksMultiple() {
        let paths = [
            "/hookB": PathItem(post: Operation(operationId: "onHookB")),
            "/hookA": PathItem(post: Operation(operationId: "onHookA"))
        ]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("func onHookA"))
        XCTAssertTrue(emitted.contains("func onHookB"))
    }
}
