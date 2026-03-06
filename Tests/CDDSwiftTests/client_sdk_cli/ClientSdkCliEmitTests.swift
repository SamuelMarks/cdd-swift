import XCTest
@testable import CDDSwift

final class ClientSdkCliEmitTests: XCTestCase {
    func testCliEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = emitSDKCLI(document: doc)
        XCTAssertTrue(code.contains("struct GetUsersCommand: AsyncParsableCommand"))
    }
}
