/// Unit tests for Vapor/Fluent server emission and Vapor route AST parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitServer`, `emitServerFiles`, `mapFluentFieldType`, and `ServerVisitor`.
final class ServerEmitTests: XCTestCase {
    /// Verifies emitting basic Vapor routes from an `OpenAPIDocument`.
    func testServerEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"), post: Operation(operationId: nil))])
        let code = emitServer(document: doc)
        XCTAssertTrue(code.contains(#"app.get("users")"#))
    }

    /// Verifies emitting Fluent models, DAOs, migrations, and seeders for component schemas.
    func testServerEmitWithSchemas() {
        let schema = Schema(type: "object", properties: ["id": Schema(type: "string")])
        let components = Components(schemas: ["User": schema])
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: nil, webhooks: nil, components: components)
        let code = emitServer(document: doc, testsMocks: true)
        XCTAssertTrue(code.contains("extension User: Content, @unchecked Sendable {}"))
        XCTAssertTrue(code.contains("public protocol UserDAO"))
        XCTAssertTrue(code.contains("public struct StubUserDAO"))
        XCTAssertTrue(code.contains("public final class FluentUser: Model"))
        XCTAssertTrue(code.contains("public struct ConcreteUserDAO"))
        XCTAssertTrue(code.contains("public struct CreateUser: AsyncMigration"))
        XCTAssertTrue(code.contains("app.migrations.add(CreateUser())"))

        let stringSchema = Schema(type: "string", format: nil)
        XCTAssertEqual(mapFluentFieldType(schema: stringSchema), "String")
        let unknownSchema = Schema(type: "unknown", format: nil)
        XCTAssertEqual(mapFluentFieldType(schema: unknownSchema), "String")
    }

    /// Verifies server emission with diverse property formats (`uuid`, `date-time`, `binary`, `int64`, `float`, arrays, refs) and CRUD routes.
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
        let otherSchema = Schema(
            type: "object",
            properties: [
                "id": Schema(type: "integer"),
                "optProp": Schema(type: "string"),
                "reqUuid": Schema(type: "string", format: "uuid"),
                "reqData": Schema(type: "string", format: "binary"),
                "reqRef": Schema(ref: "#/components/schemas/User")
            ],
            required: ["id", "reqUuid", "reqData", "reqRef"]
        )
        let emptySchema = Schema(type: "object")
        let components = Components(schemas: ["User": schema, "Other": otherSchema, "Empty": emptySchema])

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
                    operationId: "updateUser",
                    responses: [
                        "200": Response(
                            description: "Updated",
                            content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/User"))]
                        )
                    ]
                ),
                post: Operation(
                    operationId: "createUser",
                    responses: [
                        "201": Response(
                            description: "Created",
                            content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/User"))]
                        )
                    ]
                ),
                delete: Operation(operationId: "deleteUser")
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

    /// Verifies `ServerVisitor` parsing of Vapor route registrations (`app.get`, `app.post`, etc.) and filtering of internal mock/auth routes.
    func testServerParse() {
        let code = """
        let x = 1 + 2
        otherFunc()
        app.unknownMethod("x")
        otherObj.get("x")
        app.get("")
        app.get("hello") { req in return "world" }
        app.post("users", ":id") { req in return "ok" }
        app.put("users", ":id") { req in return "ok" }
        app.delete("users", ":id") { req in return "ok" }
        app.patch("users", ":id") { req in return "ok" }
        app.options("users") { req in return "ok" }
        app.head("users") { req in return "ok" }
        app.post("_mock", "trigger-webhook", ":name") { req in return "ok" }
        app.post("auth", "login") { req in return "ok" }
        """
        let syntax = Parser.parse(source: code)
        let visitor = ServerVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertNotNil(visitor.paths["/hello"]?.get)
        XCTAssertNotNil(visitor.paths["/users/{id}"]?.post)
        XCTAssertNotNil(visitor.paths["/users/{id}"]?.put)
        XCTAssertNotNil(visitor.paths["/users/{id}"]?.delete)
        XCTAssertNotNil(visitor.paths["/users/{id}"]?.patch)
        XCTAssertNotNil(visitor.paths["/users"]?.options)
        XCTAssertNotNil(visitor.paths["/users"]?.head)
        XCTAssertNil(visitor.paths["/_mock/trigger-webhook/{name}"])
        XCTAssertNil(visitor.paths["/auth/login"])
    }
}
