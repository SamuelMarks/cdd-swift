import XCTest
@testable import CDDSwift

final class RoutesEmitBoosterTests: XCTestCase {
    func testEmitCallbacksOptionalPayload() {
        let schema = Schema(type: "object")
        let mediaType = MediaType(schema: schema)
        let requestBody = RequestBody(description: nil, content: ["application/json": mediaType], required: nil)
        let operation = Operation(operationId: "myCallback", requestBody: requestBody)
        let pathItem = PathItem(post: operation)
        let callbacks: [String: Callback] = [
            "myEvent": ["{$request.query.callbackUrl}": pathItem]
        ]

        let swiftCode = emitCallbacks(operationId: "myOperation", callbacks: callbacks)
        XCTAssertTrue(swiftCode.contains("func myCallback(payload: AnyCodable?) async throws"))
    }
}
