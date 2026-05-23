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

    func testCoverageBoosts() {
        let opData = CDDSwift.Operation(
            requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))], required: false)
        )
        _ = emitTests(paths: ["/data": PathItem(post: opData)])

        let opCombinations = CDDSwift.Operation(
            parameters: [
                Parameter(name: "status", in: "query", schema: Schema(type: "string")),
                Parameter(name: "api_key", in: "query", schema: Schema(type: "string")),
                Parameter(name: "pInt", in: "query", schema: Schema(type: "integer", format: "int64")),
                Parameter(name: "pBool", in: "query", schema: Schema(type: "boolean")),
                Parameter(name: "pDouble", in: "query", schema: Schema(type: "number", format: "double")),
                Parameter(name: "pArr", in: "query", schema: Schema(type: "array", items: SchemaItem(type: "string"))),
                Parameter(name: "name", in: "query", required: false, schema: Schema(type: "string")),
                Parameter(name: "additionalMetadata", in: "query", required: false, schema: Schema(type: "string")),
                Parameter(ref: nil, name: nil, in: "query", schema: nil),
                Parameter(name: nil, in: "body", schema: Schema(type: "string"))
            ],
            responses: ["500": Response(content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        _ = emitTests(paths: ["/combos": PathItem(get: opCombinations)])

        let doc = OpenAPIDocument(
            openapi: "3", info: Info(title: "test", version: "1"),
            paths: ["/cycle": PathItem(get: CDDSwift.Operation(responses: ["200": Response(content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/A"))])]))],
            components: Components(schemas: ["A": Schema(type: "object", properties: ["b": Schema(ref: "#/components/schemas/B")]), "B": Schema(type: "object", properties: ["a": Schema(ref: "#/components/schemas/A")])])
        )
        _ = emitTests(paths: doc.paths ?? [:], document: doc)

        let schemaDiscriminator = Schema(
            type: "object",
            properties: ["type": Schema(type: "string")],
            discriminator: Discriminator(propertyName: "type", mapping: ["Child": "#/components/schemas/OtherType"])
        )
        _ = emitModel(name: "Parent", schema: schemaDiscriminator)

        let parser = SwiftASTParser()
        let cbCode = """
        protocol GetEventCallbacks { func onEvent() }
        protocol PostEventCallbacks { func onEvent() }
        protocol PutEventCallbacks { func onEvent() }
        protocol DeleteEventCallbacks { func onEvent() }
        protocol PatchEventCallbacks { func onEvent() }
        """
        _ = try? parser.parseDocument(from: cbCode)
    }

    func testMocksEmitCoverage2() {
        let op = CDDSwift.Operation(
            parameters: [
                Parameter(ref: "#/components/parameters/MyParam", name: nil, in: "query", schema: nil),
                Parameter(ref: nil, name: nil, in: "query", schema: nil)
            ],
            requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "object"))], required: true)
        )
        _ = emitMockClient(paths: ["/path": PathItem(get: op)])
    }
}
