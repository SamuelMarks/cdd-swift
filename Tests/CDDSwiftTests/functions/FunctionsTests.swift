import XCTest
@testable import CDDSwift

final class FunctionsTests: XCTestCase {
    func testEmitWebhooks() {
        let paths = ["/hook": PathItem(post: Operation(operationId: "onHook"))]
        let emitted = emitWebhooks(webhooks: paths)
        XCTAssertTrue(emitted.contains("public protocol WebhooksDelegate {"))
        XCTAssertTrue(emitted.contains("func onHook(payload: AnyCodable) async throws"))
    }
}
