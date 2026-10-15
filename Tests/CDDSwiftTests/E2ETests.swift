@testable import CDDSwift
import SwiftParser
import SwiftSyntax
import XCTest

final class E2ETests: XCTestCase {
    func testE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("example-openapi.json")
        let json = try String(contentsOfFile: fileURL.path, encoding: .utf8)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let syntax = Parser.parse(source: swiftCode)
        XCTAssertFalse(syntax.hasError)
        let schemas = try SwiftASTParser().parseModels(from: swiftCode)
        XCTAssertGreaterThan(schemas.count, 0)
    }

    func testComprehensiveE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("comprehensive-openapi.json")
        let json = try String(contentsOfFile: fileURL.path, encoding: .utf8)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let cliCode = emitSDKCLI(document: document)
        let serverCode = emitServer(document: document)

        XCTAssertFalse(Parser.parse(source: swiftCode).hasError)
        XCTAssertFalse(Parser.parse(source: cliCode).hasError)
        XCTAssertFalse(Parser.parse(source: serverCode).hasError)

        // This will test the parsing of all generated code components
        let combinedCode = swiftCode + "\n" + cliCode + "\n" + serverCode
        let parsedDoc = try SwiftASTParser().parseDocument(from: combinedCode)

        let schemas = try XCTUnwrap(parsedDoc.components?.schemas)
        XCTAssertGreaterThan(schemas.count, 0)
        XCTAssertNotNil(parsedDoc.paths)
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

    func testEmptyJSONParse() {
        let json = "{}"
        XCTAssertThrowsError(try OpenAPIParser.parse(json: json))
    }
}
