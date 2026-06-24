@testable import CDDSwift
import XCTest

final class ServerEmitTests: XCTestCase {
    func testServerEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = emitServer(document: doc)
        XCTAssertTrue(code.contains("app.get(\"users\")"))
    }

    func testServerEmitWithSchemas() {
        let schema = Schema(type: "object", properties: ["id": Schema(type: "string")])
        let components = Components(schemas: ["User": schema])
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: nil, webhooks: nil, components: components)
        let code = emitServer(document: doc, testsMocks: true)
        XCTAssertTrue(code.contains("extension User: Content, @unchecked Sendable {}"))
        XCTAssertTrue(code.contains("public protocol UserDAO"))
        XCTAssertTrue(code.contains("public struct StubUserDAO"))
        XCTAssertTrue(code.contains("public final class FluentUser: Model"))
        XCTAssertTrue(code.contains("public struct ConcreteUserDAO"))
        XCTAssertTrue(code.contains("public struct CreateUser: AsyncMigration"))
        XCTAssertTrue(code.contains("app.migrations.add(CreateUser())"))
    }
}
