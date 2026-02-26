import XCTest
@testable import CDDSwift

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
                    "application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))
                ]
            )
        )
        let emitted = emitMethod(path: "/form", method: "POST", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")"))
        XCTAssertTrue(emitted.contains("let unreserved = CharacterSet(charactersIn: \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~\")"))
        XCTAssertTrue(emitted.contains("encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \" \", with: \"+\")"))
    }
}

