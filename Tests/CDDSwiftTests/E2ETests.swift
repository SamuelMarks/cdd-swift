@testable import CDDSwift
import XCTest

final class E2ETests: XCTestCase {
    func testE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("example-openapi.json")
        let json = try String(contentsOfFile: fileURL.path)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let schemas = try SwiftASTParser().parseModels(from: swiftCode)
        XCTAssertGreaterThan(schemas.count, 0)
    }

    func testComprehensiveE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("comprehensive-openapi.json")
        let json = try String(contentsOfFile: fileURL.path)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let schemas = try SwiftASTParser().parseModels(from: swiftCode)
        XCTAssertGreaterThan(schemas.count, 0)
    }

    func testParseDocument() throws {
        let code = """
        struct MyModel: Codable { let id: String }
        func mockGetUsers() {}
        func mockUsers() {}
        func getRoute() {}
        """
        let doc = try SwiftASTParser().parseDocument(from: code)
        XCTAssertNotNil(doc.components?.schemas?["MyModel"])
        XCTAssertNotNil(doc.paths?["/users"])
        XCTAssertNotNil(doc.paths?["/getRoute"])
    }

    func testOverlapParse() throws {
        let code = """
        func getUsers() {}
        func mockUsers() {}
        """
        let doc = try SwiftASTParser().parseDocument(from: code)
        XCTAssertNotNil(doc.paths?["/users"])
    }
}
