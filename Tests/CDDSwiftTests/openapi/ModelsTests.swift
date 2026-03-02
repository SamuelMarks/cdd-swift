@testable import CDDSwift
import XCTest

final class ModelsTests: XCTestCase {
    func testOpenAPIDocumentModel() throws {
        let info = Info(title: "Test API", version: "1.0")
        let doc = OpenAPIDocument(openapi: "3.0.0", info: info)

        XCTAssertEqual(doc.openapi, "3.0.0")
        XCTAssertEqual(doc.info.title, "Test API")

        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenAPIDocument.self, from: data)

        XCTAssertEqual(decoded, doc)
    }

    func testDocsJsonModels() throws {
        let code = DocsJsonCode(imports: "import Foundation", wrapper_start: "class Wrapper {", snippet: "print(1)", wrapper_end: "}")
        let operation = DocsJsonOperation(method: "GET", path: "/test", operationId: "testOp", code: code)
        let output = DocsJsonOutput(language: "swift", operations: [operation])

        XCTAssertEqual(output.language, "swift")
        XCTAssertEqual(output.operations.count, 1)

        let encoder = JSONEncoder()
        let data = try encoder.encode(output)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DocsJsonOutput.self, from: data)

        XCTAssertEqual(decoded.language, "swift")
        XCTAssertEqual(decoded.operations.first?.method, "GET")
    }
}
