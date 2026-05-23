@testable import CDDSwift
import XCTest

final class ClientSdkEmitTests: XCTestCase {
    func testSdkEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = OpenAPIToSwiftGenerator.generate(from: doc)
        XCTAssertTrue(code.contains("func getUsers("))
    }

    func testOpenAPIDocumentBuilder() {
        let builder = OpenAPIDocumentBuilder(title: "Test API", version: "2.0")
            .addPath("/test", item: PathItem(get: Operation(operationId: "getTest")))
            .addWebhook("hook", item: PathItem(post: Operation(operationId: "postHook")))
            .addSchema("MyModel", schema: Schema(type: "object"))
            .addSecurityScheme("BearerAuth", scheme: SecurityScheme(type: "http", scheme: "bearer"))

        let doc = builder.build()
        XCTAssertEqual(doc.info.title, "Test API")
        XCTAssertEqual(doc.info.version, "2.0")
        XCTAssertNotNil(doc.paths?["/test"])
        XCTAssertNotNil(doc.webhooks?["hook"])
        XCTAssertNotNil(doc.components?.schemas?["MyModel"])
        XCTAssertNotNil(doc.components?.securitySchemes?["BearerAuth"])

        do {
            let json = try builder.serialize()
            XCTAssertTrue(json.contains("Test API"))
        } catch {
            XCTFail("Failed to serialize: \\(error)")
        }
    }
}
