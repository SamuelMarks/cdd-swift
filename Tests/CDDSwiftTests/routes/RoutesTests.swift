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
                    "application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))
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

    func testRoutesEmitPathUnknownStyle() {
        let op = Operation(
            parameters: [
                Parameter(name: "p", in: "path", required: true, style: "unknown", explode: false, schema: Schema(type: "string"))
            ]
        )
        let emitted = emitMethod(path: "/test/{p}", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("\\(p)"))
    }

    func testRoutesEmitQueryArrayUnknownStyle() {
        let op = Operation(
            parameters: [
                Parameter(name: "q", in: "query", required: false, style: "unknown", explode: false, schema: Schema(type: "array", items: SchemaItem(type: "string")))
            ]
        )
        let emitted = emitMethod(path: "/test", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("String(describing: val_q)"))
    }

    func testRoutesEmitInBodyParam() {
        let op = Operation(
            parameters: [
                Parameter(name: "myBody", in: "body", required: true, schema: Schema(type: "string"))
            ]
        )
        // By adding an existing `myBody` to `args` before the param loop, we trigger the `if !args.contains` check. However `args` is an internal variable inside `emitMethod`, so we cannot inject into `args`.
        // The `args` list contains path parameters, query parameters, header parameters, etc.
        // Let's create a path parameter and a body parameter with the same name.
        let op2 = Operation(
            parameters: [
                Parameter(name: "sharedName", in: "path", required: true, schema: Schema(type: "string")),
                Parameter(name: "sharedName", in: "body", required: true, schema: Schema(type: "string"))
            ]
        )
        let emitted2 = emitMethod(path: "/test/{sharedName}", method: "POST", operation: op2, documentSecurity: nil, securitySchemes: [:])

        let emitted = emitMethod(path: "/test", method: "POST", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("myBody: String"))
        XCTAssertTrue(emitted.contains("request.httpBody = try JSONEncoder().encode(myBody)"))
        XCTAssertTrue(emitted2.contains("sharedName: String"))
        XCTAssertTrue(emitted2.contains("request.httpBody = try JSONEncoder().encode(sharedName)"))
    }

    func testRoutesEmitReturnData() {
        let op = Operation(
            responses: [
                "200": Response(description: "OK", content: ["application/json": MediaType(schema: Schema(type: "string", format: "binary"))])
            ]
        )
        let emitted = emitMethod(path: "/test", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("return data"))
    }

    func testEmitCallbacksEmpty() {
        let emitted1 = emitCallbacks(operationId: "myOp", callbacks: nil)
        XCTAssertEqual(emitted1, "")

        let emitted2 = emitCallbacks(operationId: "myOp", callbacks: [:])
        XCTAssertEqual(emitted2, "")
    }

    func testEmitCallbacksPopulated() {
        let op = Operation(
            operationId: "myCallbackOp",
            requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "string"))], required: true)
        )
        let pathItem = PathItem(post: op)
        let callbacks: [String: Callback] = ["myCallback": ["{$request.query.callbackUrl}": pathItem]]

        let emitted = emitCallbacks(operationId: "subscribe", callbacks: callbacks)
        XCTAssertTrue(emitted.contains("public protocol SubscribeCallbacks {"))
        XCTAssertTrue(emitted.contains("func myCallbackOp(payload: String) async throws"))
    }
}
