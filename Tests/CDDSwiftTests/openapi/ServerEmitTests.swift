import XCTest
@testable import CDDSwift

final class ServerEmitTests: XCTestCase {
    func testServerEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = emitServer(document: doc)
        XCTAssertTrue(code.contains("app.get("))
    }
}
