@testable import CDDSwift
import XCTest

final class RoutesTests: XCTestCase {
    func testEmitMethod() {
        let op = Operation(
            summary: "Get something",
            description: "Returns a thing",
            operationId: "getThing",
            responses: ["200": Response(description: "OK", content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        let emitted = emitMethod(path: "/thing", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("public func getThing() async throws -> String"))
        XCTAssertTrue(emitted.contains("request.httpMethod = \"GET\""))
    }

    func testEmitMethodFormUrlEncoded() {
        let op = Operation(
            summary: "Post form",
            operationId: "postForm",
            requestBody: RequestBody(
                content: [
                    "application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object")),
                ]
            )
        )
        let emitted = emitMethod(path: "/form", method: "POST", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")"))
        XCTAssertTrue(emitted.contains("let unreserved = CharacterSet(charactersIn: \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~\")"))
        XCTAssertTrue(emitted.contains("encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \" \", with: \"+\")"))
    }

    func testEmitMethodWithJsonBody() {
        let op = Operation(
            summary: "Post JSON",
            operationId: "postJson",
            requestBody: RequestBody(
                content: [
                    "application/json": MediaType(schema: Schema(type: "object"))
                ]
            )
        )
        let emitted = emitMethod(path: "/json", method: "POST", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("body: AnyCodable? = nil"))
        XCTAssertTrue(emitted.contains("request.httpMethod = \"POST\""))
        XCTAssertTrue(emitted.contains("request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"))
        XCTAssertTrue(emitted.contains("request.httpBody = try JSONEncoder().encode(body)"))
    }

    func testEmitMethodNoBody() {
        let op = Operation(
            summary: "Delete something",
            operationId: "deleteSomething"
        )
        let emitted = emitMethod(path: "/something", method: "DELETE", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertFalse(emitted.contains("body:"))
        XCTAssertTrue(emitted.contains("public func deleteSomething() async throws -> Void"))
        XCTAssertTrue(emitted.contains("request.httpMethod = \"DELETE\""))
        XCTAssertFalse(emitted.contains("request.httpBody"))
    }

    func testEmitMethodDifferentHTTPMethods() {
        let methods = ["PUT", "PATCH", "OPTIONS", "HEAD"]
        for method in methods {
            let op = Operation(
                summary: "\(method) something",
                operationId: "\(method.lowercased())Something"
            )
            let emitted = emitMethod(path: "/something", method: method, operation: op, documentSecurity: nil, securitySchemes: [:])
            XCTAssertTrue(emitted.contains("request.httpMethod = \"\(method)\""))
            XCTAssertTrue(emitted.contains("public func \(method.lowercased())Something() async throws -> Void"))
        }
    }

    func testEmitMethodCheckResponse() {
        let op = Operation(
            summary: "Get specific response",
            operationId: "getSpecificResponse",
            responses: ["200": Response(description: "OK", content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/MyModel"))])]
        )
        let emitted = emitMethod(path: "/specific", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("public func getSpecificResponse() async throws -> MyModel"))
        XCTAssertTrue(emitted.contains("return try JSONDecoder().decode(MyModel.self, from: data)"))
    }
}
