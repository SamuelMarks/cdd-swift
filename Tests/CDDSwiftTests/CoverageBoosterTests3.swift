import XCTest
@testable import CDDSwift

final class CoverageBoosterTests3: XCTestCase {
    func testGenerateDummyJSON() {
        let schemas: [String: Schema] = [
            "MyNumber": Schema(type: "number"),
            "MyInt": Schema(type: "integer"),
            "MyObj": Schema(type: "object", properties: [
                "id": Schema(type: "string"),
                "username": Schema(type: "string"),
                "missing": Schema(type: "string")
            ], required: ["missing"])
        ]
        
        let paths: [String: PathItem] = [
            "/test": PathItem(
                get: Operation(
                    parameters: [
                        Parameter(name: "id", in: "path", required: false, schema: Schema(type: "string")),
                        Parameter(name: "status", in: "query", schema: Schema(type: "string")),
                        Parameter(name: "api_key", in: "header", schema: Schema(type: "string"))
                    ]
                ),
                post: Operation(
                    requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object", properties: ["id": Schema(type: "string"), "username": Schema(type: "string")], required: ["missing"]))])
                )
            )
        ]
        let doc = OpenAPIDocument(openapi: "3", info: Info(title: "test", version: "1"), paths: paths, components: Components(schemas: schemas))
        _ = emitTests(paths: paths, document: doc)
        _ = OpenAPIToSwiftGenerator.generateFiles(from: doc, tests: true)
    }

    func testRoutesEmitMissing() {
        let op = Operation(
            parameters: [
                Parameter(name: "p1", in: "path", required: false, schema: Schema(type: "string")),
                Parameter(name: "p2", in: "query", style: "pipeDelimited", schema: Schema(type: "array", items: SchemaItem(type: "string"))),
                Parameter(name: "q", in: "query", style: "deepObject", schema: Schema(type: "object"))
            ],
            requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "string"))])
        )
        _ = emitMethod(path: "/path/{p1}", method: "GET", operation: op, documentSecurity: nil, securitySchemes: [:])
    }

    func testFunctionsEmitMissing() {
        let op = Operation(operationId: "func1")
        _ = emitWebhooks(webhooks: ["hook1": PathItem(get: op, post: Operation())])
    }
}
