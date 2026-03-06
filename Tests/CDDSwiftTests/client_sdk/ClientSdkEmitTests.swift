import XCTest
@testable import CDDSwift

final class ClientSdkEmitTests: XCTestCase {
    func testSdkEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = OpenAPIToSwiftGenerator.generate(from: doc)
        XCTAssertTrue(code.contains("func getUsers("))
    }
}
