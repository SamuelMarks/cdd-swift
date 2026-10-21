/// Unit tests for API client route method emission, callback delegate emission, and route AST parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitMethod`, `emitCallbacks`, `inferOperationReturnType`, and `RouteVisitor`.
final class RoutesTests: XCTestCase {
    /// Verifies emitting a standard GET operation returning a `String`.
    func testEmitMethod() {
        let op = Operation(
            summary: "Get something",
            description: "Returns a thing",
            operationId: "getThing",
            responses: ["200": Response(description: "OK", content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        let emitted = emitMethod(path: "/thing", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("public func getThing() async throws -> String"))
        XCTAssertTrue(emitted.contains(#"request.httpMethod = "GET""#))
    }

    /// Verifies emitting a POST operation with an `application/x-www-form-urlencoded` body.
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
        XCTAssertTrue(emitted.contains(#"request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")"#))
        XCTAssertTrue(emitted
            .contains(
                #"let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")"#
            ))
        XCTAssertTrue(emitted
            .contains(
                #"encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: " ", with: "+")"#
            ))
    }

    /// Verifies emitting a POST operation with an `application/json` body.
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
        XCTAssertTrue(emitted.contains(#"request.httpMethod = "POST""#))
        XCTAssertTrue(emitted.contains(#"request.setValue("application/json", forHTTPHeaderField: "Content-Type")"#))
        XCTAssertTrue(emitted.contains("request.httpBody = try JSONEncoder().encode(body)"))

        let reqOp = Operation(
            operationId: "postJsonReq",
            requestBody: RequestBody(
                content: ["application/json": MediaType(schema: Schema(type: "object"))],
                required: true
            )
        )
        let emittedReq = emitMethod(path: "/json", method: "POST", operation: reqOp, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emittedReq.contains("body: AnyCodable)"))
    }

    /// Verifies emitting a DELETE operation with no request body.
    func testEmitMethodNoBody() {
        let op = Operation(
            summary: "Delete something",
            operationId: "deleteSomething"
        )
        let emitted = emitMethod(path: "/something", method: "DELETE", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertFalse(emitted.contains("body:"))
        XCTAssertTrue(emitted.contains("public func deleteSomething() async throws -> Void"))
        XCTAssertTrue(emitted.contains(#"request.httpMethod = "DELETE""#))
        XCTAssertFalse(emitted.contains("request.httpBody"))
    }

    /// Verifies emitting `PUT`, `PATCH`, `OPTIONS`, and `HEAD` operations.
    func testEmitMethodDifferentHTTPMethods() {
        let methods = ["PUT", "PATCH", "OPTIONS", "HEAD"]
        for method in methods {
            let op = Operation(
                summary: "\(method) something",
                operationId: "\(method.lowercased())Something"
            )
            let emitted = emitMethod(path: "/something", method: method, operation: op, documentSecurity: nil, securitySchemes: [:])
            XCTAssertTrue(emitted.contains("request.httpMethod = " + String(UnicodeScalar(34)) + method + String(UnicodeScalar(34))))
            XCTAssertTrue(emitted.contains("public func \(method.lowercased())Something() async throws -> Void"))
        }
    }

    /// Verifies emitting an operation returning a `$ref` model type.
    func testEmitMethodCheckResponse() {
        let op = Operation(
            summary: "Get specific response",
            operationId: "getSpecificResponse",
            responses: ["200": Response(
                description: "OK",
                content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/MyModel"))]
            )]
        )
        let emitted = emitMethod(path: "/specific", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("public func getSpecificResponse() async throws -> MyModel"))
        XCTAssertTrue(emitted.contains("return try JSONDecoder().decode(MyModel.self, from: data)"))
    }

    /// Verifies fallback interpolation for unknown path parameter styles.
    func testRoutesEmitPathUnknownStyle() {
        let op = Operation(
            parameters: [
                Parameter(name: "p", in: "path", required: true, style: "unknown", explode: false, schema: Schema(type: "string"))
            ]
        )
        let emitted = emitMethod(path: "/test/{p}", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        let bs = String(UnicodeScalar(92))
        XCTAssertTrue(emitted.contains(bs + "(p)"))
    }

    /// Verifies fallback serialization for unknown query array parameter styles.
    func testRoutesEmitQueryArrayUnknownStyle() {
        let op = Operation(
            parameters: [
                Parameter(
                    name: "q",
                    in: "query",
                    required: false,
                    style: "unknown",
                    explode: false,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                )
            ]
        )
        let emitted = emitMethod(path: "/test", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("String(describing: val_q)"))
    }

    /// Verifies Swagger 2.0 `in: "body"` parameter emission.
    func testRoutesEmitInBodyParam() {
        let op = Operation(
            parameters: [
                Parameter(name: "myBody", in: "body", required: true, schema: Schema(type: "string"))
            ]
        )
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

    /// Verifies binary `Data` response handling in `emitMethod`.
    func testRoutesEmitReturnData() {
        let op = Operation(
            responses: [
                "200": Response(
                    description: "OK",
                    content: ["application/json": MediaType(schema: Schema(type: "string", format: "binary"))]
                )
            ]
        )
        let emitted = emitMethod(path: "/test", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emitted.contains("return data"))
    }

    /// Verifies `emitCallbacks` returns an empty string when callbacks are `nil` or empty.
    func testEmitCallbacksEmpty() {
        let emitted1 = emitCallbacks(operationId: "myOp", callbacks: nil)
        XCTAssertEqual(emitted1, "")

        let emitted2 = emitCallbacks(operationId: "myOp", callbacks: [:])
        XCTAssertEqual(emitted2, "")
    }

    /// Verifies `emitCallbacks` emits callback protocols with required and optional payloads.
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

        let optOp = Operation(
            operationId: "myCallback",
            requestBody: RequestBody(
                description: nil,
                content: ["application/json": MediaType(schema: Schema(type: "object"))],
                required: nil
            )
        )
        let optCallbacks: [String: Callback] = [
            "myEvent": ["{$request.query.callbackUrl}": PathItem(post: optOp)],
            "CB2": ["/path2": PathItem(post: Operation(operationId: nil))]
        ]
        let emittedOpt = emitCallbacks(operationId: "myOperation", callbacks: optCallbacks)
        XCTAssertTrue(emittedOpt.contains("func myCallback(payload: AnyCodable?) async throws"))
    }

    /// Verifies Swagger 2.0 `in: "formData"` parameters and `default` response fallback.
    func testEmitMethodFormDataParamsAndDefaultResponse() {
        let formOp = Operation(
            operationId: "submitFormFields",
            parameters: [
                Parameter(name: "title", in: "formData", required: true, schema: Schema(type: "string")),
                Parameter(name: "tag", in: "formData", required: false, schema: Schema(type: "string"))
            ],
            responses: [
                "default": Response(description: "Default", content: ["application/json": MediaType(schema: Schema(type: "integer"))])
            ]
        )
        let q = String(UnicodeScalar(34))
        let bs = String(UnicodeScalar(92))
        let emittedForm = emitMethod(path: "/submit", method: "POST", operation: formOp, documentSecurity: nil, securitySchemes: [:])
        XCTAssertTrue(emittedForm.contains("public func submitFormFields(title: String, tag: String? = nil) async throws -> Int"))
        XCTAssertTrue(emittedForm.contains("application/x-www-form-urlencoded"))
        XCTAssertTrue(emittedForm.contains("formComponents.append(" + q + "title=" + bs + "(encoded)" + q + ")"))
        XCTAssertTrue(emittedForm.contains("formComponents.append(" + q + "tag=" + bs + "(encoded)" + q + ")"))

        let multipartFormOp = Operation(
            operationId: "uploadAvatar",
            parameters: [
                Parameter(name: "caption", in: "formData", required: true, schema: Schema(type: "string")),
                Parameter(name: "note", in: "formData", required: false, schema: Schema(type: "string")),
                Parameter(name: "avatar", in: "formData", required: true, schema: Schema(type: "string", format: "binary"))
            ],
            requestBody: RequestBody(
                content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))],
                required: false
            )
        )
        let emittedMultipart = emitMethod(
            path: "/avatar",
            method: "POST",
            operation: multipartFormOp,
            documentSecurity: nil,
            securitySchemes: [:]
        )
        XCTAssertTrue(emittedMultipart.contains("multipart/form-data; boundary="))
        XCTAssertTrue(emittedMultipart.contains("name=" + bs + q + "caption" + bs + q))
        XCTAssertTrue(emittedMultipart.contains("name=" + bs + q + "note" + bs + q))
    }
}

/// Test suite verifying parameter serialization styles, security schemes, and `RouteVisitor` parsing.
final class RoutesStylesAndSecurityTests: XCTestCase {
    /// Verifies path styles (`simple`, `matrix`), header parameters, and security schemes.
    func testEmitMethodPathStylesAndSecurity() {
        let op1 = Operation(
            operationId: "updatePetWithForm",
            parameters: [
                Parameter(name: "name", in: "query", schema: Schema(type: "string")),
                Parameter(name: "status", in: "query", schema: Schema(type: "string")),
                Parameter(
                    name: "id", in: "path", style: "simple", explode: true,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "id2", in: "path", style: "simple", explode: false,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(name: "id3", in: "path", style: "matrix", explode: false, schema: Schema(type: "string")),
                Parameter(name: "head", in: "header", schema: Schema(type: "string")),
                Parameter(name: "api_key", in: "query", schema: Schema(type: "string"))
            ],
            requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string"))], required: true)
        )
        let schemes1 = [
            "bearerAuth": SecurityScheme(type: "http", scheme: "bearer"),
            "apiKeyAuth": SecurityScheme(type: "apiKey", name: "X-API-KEY", in: "header"),
            "apiKeyQuery": SecurityScheme(type: "apiKey", name: "api_key", in: "query")
        ]
        XCTAssertTrue(emitMethod(
            path: "/path/{id}/{id2}/{id3}",
            method: "POST",
            operation: op1,
            documentSecurity: [["bearerAuth": []], ["apiKeyAuth": []], ["apiKeyQuery": []]],
            securitySchemes: schemes1
        ).contains("func updatePetWithForm"))
    }

    /// Verifies required path/query/header parameters across `simple`, `matrix`, `label`, `form`, `pipeDelimited`, and `deepObject` styles.
    func testEmitMethodRequiredArrayAndObjectStyles() {
        let op2 = Operation(
            operationId: nil,
            parameters: [
                Parameter(
                    name: "p_simple_array_req", in: "path", required: true, style: "simple", explode: true,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "p_simple_array_req_noexp", in: "path", required: true, style: "simple", explode: false,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "p_matrix_array_req", in: "path", required: true, style: "matrix", explode: true,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "p_matrix_array_req_noexp", in: "path", required: true, style: "matrix", explode: false,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(name: "p_matrix_req", in: "path", required: true, style: "matrix", schema: Schema(type: "string")),
                Parameter(
                    name: "p_label_array_req", in: "path", required: true, style: "label", explode: true,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "p_label_array_req_noexp", in: "path", required: true, style: "label", explode: false,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(name: "p_label_req", in: "path", required: true, style: "label", schema: Schema(type: "string")),
                Parameter(
                    name: "q_arr_form_exp_req", in: "query", required: true, style: "form", explode: true,
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(
                    name: "q_arr_pipe_req", in: "query", required: true, style: "pipeDelimited",
                    schema: Schema(type: "array", items: SchemaItem(type: "string"))
                ),
                Parameter(name: "q_obj_deep_req", in: "query", required: true, style: "deepObject", schema: Schema(type: "object")),
                Parameter(name: "header_req", in: "header", required: true, schema: Schema(type: "string"))
            ],
            requestBody: RequestBody(content: [
                "multipart/form-data": MediaType(schema: Schema(type: "object", properties: ["f": Schema(type: "string")])),
                "application/octet-stream": MediaType(schema: Schema(type: "string"))
            ], required: true),
            responses: ["200": Response(content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        let schemes2 = [
            "oauth": SecurityScheme(type: "oauth2"),
            "openIdConnect": SecurityScheme(type: "openIdConnect"),
            "apiKeyQuery": SecurityScheme(type: "apiKey", name: "api_key", in: "query"),
            "apiKeyHeader": SecurityScheme(type: "apiKey", name: "X-API-KEY", in: "header")
        ]
        XCTAssertTrue(emitMethod(
            path: "/path/{p_simple_array_req}",
            method: "POST",
            operation: op2,
            documentSecurity: [["oauth": []], ["openIdConnect": []]],
            securitySchemes: schemes2
        ).contains("func post_path_p_simple_array_req"))
    }

    /// Verifies optional array/object styles and Swagger 2.0 body parameter fallback.
    func testEmitMethodOptionalStylesAndBodyFallback() {
        let optParams: [Parameter] = [
            Parameter(ref: nil, name: nil, in: nil, schema: nil),
            Parameter(
                name: "p_simple_opt", in: "path", required: false, style: "simple", explode: true,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(
                name: "p_simple_opt_noexp", in: "path", required: false, style: "simple", explode: false,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(
                name: "p_matrix_opt", in: "path", required: false, style: "matrix", explode: true,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(
                name: "p_matrix_opt_noexp", in: "path", required: false, style: "matrix", explode: false,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(
                name: "p_label_opt", in: "path", required: false, style: "label", explode: true,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(
                name: "p_label_opt_noexp", in: "path", required: false, style: "label", explode: false,
                schema: Schema(type: "array", items: SchemaItem(type: "string"))
            ),
            Parameter(name: "p2", in: "query", style: "pipeDelimited", schema: Schema(type: "array", items: SchemaItem(type: "string"))),
            Parameter(name: "q", in: "query", style: "deepObject", schema: Schema(type: "object")),
            Parameter(name: "qObjNoStyle", in: "query", schema: Schema(type: "object")),
            Parameter(name: nil, in: "body", schema: Schema(type: "string"))
        ]
        let op3 = Operation(
            parameters: optParams,
            requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string"))], required: nil)
        )
        let schemes3 = [
            "k1": SecurityScheme(type: "apiKey", name: nil, in: "query"),
            "k2": SecurityScheme(type: "apiKey", name: "k2", in: nil)
        ]
        XCTAssertTrue(emitMethod(
            path: "/path/{p_simple_opt}/{p_matrix_opt}/{p_label_opt}",
            method: "POST",
            operation: op3,
            documentSecurity: [["k1": []], ["k2": []]],
            securitySchemes: schemes3
        ).contains("URLQueryItem"))

        let opBodyParam = Operation(parameters: [Parameter(name: nil, in: "body", schema: Schema(type: "string"))])
        XCTAssertTrue(emitMethod(path: "/body", method: "POST", operation: opBodyParam, documentSecurity: nil, securitySchemes: [:])
            .contains("JSONEncoder().encode"))
    }

    /// Verifies `RouteVisitor` parsing of function declarations, parameters, bodies, and `@link` annotations.
    func testRoutesParse() {
        let code = """
        func getRoute(param: String) {}
        func postRoute(body: String, formData: String, multipartData: String, q: String) {}
        func putRoute() {}
        func deleteRoute() {}
        func patchRoute() {}
        func otherRoute() {}

        /// @link myLink -> myOpId
        func getOnlyLink() {}
        """
        let syntax = Parser.parse(source: code)
        let visitor = RouteVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertNotNil(visitor.paths["/getRoute"]?.get)
        XCTAssertNotNil(visitor.paths["/postRoute"]?.post)
        XCTAssertNotNil(visitor.paths["/putRoute"]?.put)
        XCTAssertNotNil(visitor.paths["/deleteRoute"]?.delete)
        XCTAssertNotNil(visitor.paths["/patchRoute"]?.patch)
        XCTAssertNotNil(visitor.paths["/getOnlyLink"]?.get)
    }
}
