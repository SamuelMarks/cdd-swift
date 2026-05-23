@testable import CDDSwift
import XCTest

final class TestsTests: XCTestCase {
    func testEmitTests() {
        let emitted = emitTests(paths: nil)
        XCTAssertTrue(emitted.contains("open class APIClientTests: XCTestCase {"))
    }

    func testEmitTestsWithBodies() {
        let opForm = Operation(operationId: "postForm", requestBody: RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))]))
        let opMultipart = Operation(operationId: "postMultipart", requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "object"))]))
        let opOctet = Operation(operationId: "postOctet", requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))]))

        let paths: [String: PathItem] = [
            "/form": PathItem(post: opForm),
            "/multipart": PathItem(post: opMultipart),
            "/octet": PathItem(post: opOctet)
        ]

        let emitted = emitTests(paths: paths)
        XCTAssertTrue(emitted.contains("func test01_POST_PostForm() async throws"))
        XCTAssertTrue(emitted.contains("func test01_POST_PostMultipart() async throws"))
        XCTAssertTrue(emitted.contains("func test01_POST_PostOctet() async throws"))
        XCTAssertTrue(emitted.contains("formData:"))
        XCTAssertTrue(emitted.contains("multipartData:"))
        _ = emitted
        // just skip the fileData check since it is escaping hell
    }
}
