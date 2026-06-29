@testable import CDDSwift
import XCTest

final class ServerEmitBoosterTests: XCTestCase {
    func testServerEmitWithComplexSchemas() {
        let schema = Schema(
            type: "object",
            properties: [
                "id": Schema(type: "string", format: "uuid"),
                "someUuid": Schema(type: "string", format: "uuid"),
                "date": Schema(type: "string", format: "date-time"),
                "data": Schema(type: "string", format: "binary"),
                "count": Schema(type: "integer", format: "int64"),
                "price": Schema(type: "number", format: "float"),
                "rating": Schema(type: "number"),
                "isActive": Schema(type: "boolean"),
                "tags": Schema(type: "array", items: SchemaItem(type: "string")),
                "meta": Schema(type: "object"),
                "unknownVal": Schema(type: "unknown"),
                "refVal": Schema(ref: "#/components/schemas/Other")
            ],
            required: ["id", "date"]
        )
        let otherSchema = Schema(type: "object", properties: ["optProp": Schema(type: "string")])
        let components = Components(schemas: ["User": schema, "Other": otherSchema])

        let paths: [String: PathItem] = [
            "/admin": PathItem(get: Operation(operationId: "getAdmin")),
            "/users": PathItem(
                get: Operation(
                    operationId: "getUsers",
                    responses: [
                        "200": Response(
                            description: "OK",
                            content: ["application/json": MediaType(schema: Schema(type: "array", items: SchemaItem(ref: "#/components/schemas/User")))]
                        )
                    ]
                ),
                put: Operation(
                    operationId: "updateUser"
                ),
                post: Operation(
                    operationId: "createUser",
                    responses: [
                        "201": Response(
                            description: "Created",
                            content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/User"))]
                        )
                    ]
                )
            )
        ]

        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: paths, components: components)
        let code = emitServer(document: doc, testsMocks: true)

        XCTAssertTrue(code.contains("Float"))
        XCTAssertTrue(code.contains("Int64"))
        XCTAssertTrue(code.contains("UUID"))
        XCTAssertTrue(code.contains("Date"))
        XCTAssertTrue(code.contains("Bool"))
        XCTAssertTrue(code.contains("faker.name.name()"))
    }
}
