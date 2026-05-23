@testable import CDDSwift
import XCTest

final class MocksTests: XCTestCase {
    func testEmitMockClient() {
        let emitted = emitMockClient(paths: nil)
        XCTAssertTrue(emitted.contains("public class MockAPIClient {"))
    }

    func testEmitMockClientWithPaths() {
        let op = Operation(
            operationId: "getUsers",
            parameters: [Parameter(name: "id", in: "query", required: true, schema: Schema(type: "string"))],
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
            requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "string"))])
        )
        let paths: [String: PathItem] = [
            "/users": PathItem(get: op, put: opForm, post: opPost, delete: Operation(operationId: "delUser"), patch: opMulti)
        ]

        let emitted = emitMockClient(paths: paths)
        XCTAssertTrue(emitted.contains("public func getUsers(id: String) async throws -> String {"))
        XCTAssertTrue(emitted.contains("public func postUser(body: String) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func postForm(formData: String? = nil) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func postMulti(multipartData: String? = nil) async throws -> Void {"))
        XCTAssertTrue(emitted.contains("public func delUser() async throws -> Void {"))
    }
}
