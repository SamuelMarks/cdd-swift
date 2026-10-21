/// Unit tests for `MockAPIClient` emission and `MockVisitor` AST parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitMockClient` and `MockVisitor`.
final class MocksTests: XCTestCase {
    /// Verifies emitting an empty `MockAPIClient` when `paths` is `nil`.
    func testEmitMockClient() {
        let emitted = emitMockClient(paths: nil)
        XCTAssertTrue(emitted.contains("public class MockAPIClient {"))
    }

    /// Verifies emitting mock client methods across HTTP methods and body content types.
    func testEmitMockClientWithPaths() {
        let op = Operation(
            operationId: "getUsers",
            parameters: [
                Parameter(name: "id", in: "query", required: true, schema: Schema(type: "string")),
                Parameter(ref: "#/components/parameters/MyParam", name: nil, in: "query", schema: nil),
                Parameter(ref: nil, name: nil, in: "query", schema: nil)
            ],
            responses: ["200": Response(description: "OK", content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        let opPost = Operation(
            operationId: "postUser",
            requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "string"))], required: true)
        )
        let opForm = Operation(
            operationId: "postForm",
            requestBody: RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: Schema(type: "string"))])
        )
        let opMulti = Operation(
            operationId: "postMulti",
            requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "string"))], required: true)
        )
        let paths: [String: PathItem] = [
            "/users": PathItem(get: op, put: opForm, post: opPost, delete: Operation(operationId: "delUser"), patch: opMulti)
        ]

        let emitted = emitMockClient(paths: paths)
        XCTAssertTrue(emitted
            .contains("public func getUsers(id: String, MyParam: String? = nil, unknown: String? = nil) async throws -> String {"))
        XCTAssertTrue(emitted.contains("public func postUser(body: String) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func postForm(formData: String? = nil) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func postMulti(multipartData: String) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func delUser() async throws -> Void {"))
    }

    /// Verifies `MockVisitor` discovery of `mock*` functions.
    func testMocksParse() {
        let code = """
        func mockUsers() {}
        func mockItems() {}
        """
        let syntax = Parser.parse(source: code)
        let visitor = MockVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertEqual(visitor.inferredPaths.count, 2)
    }
}
