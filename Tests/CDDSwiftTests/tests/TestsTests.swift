/// Unit tests for XCTest suite emission, dummy value synthesis, and test AST parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitTests`, `generateDummyJSON`, `synthesizeDummyParameterLiteral`, and `TestVisitor`.
final class TestsTests: XCTestCase {
    /// Verifies emitting an empty `APIClientTests` class when `paths` is `nil`.
    func testEmitTests() {
        let emitted = emitTests(paths: nil)
        XCTAssertTrue(emitted.contains("open class APIClientTests: XCTestCase {"))
    }

    /// Verifies emitting test methods for form-urlencoded, multipart/form-data, and octet-stream bodies.
    func testEmitTestsWithBodies() {
        let opForm = Operation(operationId: "postForm", requestBody: RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))]))
        let opMultipart = Operation(operationId: "postMultipart", requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "object"))]))
        let opOctet = Operation(operationId: "postOctet", requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))]))

        let paths: [String: PathItem] = [
            "/form": PathItem(post: opForm),
            "/multipart": PathItem(post: opMultipart),
            "/octet": PathItem(post: opOctet)
        ]

        let emitted = emitTests(paths: paths)
        XCTAssertTrue(emitted.contains("func test01_POST_PostForm() async throws"))
        XCTAssertTrue(emitted.contains("func test01_POST_PostMultipart() async throws"))
        XCTAssertTrue(emitted.contains("func test01_POST_PostOctet() async throws"))
        XCTAssertTrue(emitted.contains("formData:"))
        XCTAssertTrue(emitted.contains("multipartData:"))
        XCTAssertTrue(emitted.contains("fileData:"))
    }

    /// Verifies `generateDummyJSON` handling of cyclic references, missing references, unknown types, arrays, and primitives.
    func testGenerateDummyJSONCyclesAndDefaults() {
        let schema1 = Schema(type: "object", ref: "#/components/schemas/A")
        let schemas = ["A": schema1]
        let visited = Set(["A"])
        let jsonCycle = generateDummyJSON(context: DummyJSONContext(ref: "#/components/schemas/A", schemas: schemas, visited: visited))
        XCTAssertEqual(jsonCycle, "{}")

        let jsonMissingRef = generateDummyJSON(context: DummyJSONContext(ref: "#/components/schemas/Missing", schemas: schemas))
        XCTAssertEqual(jsonMissingRef, "{}")

        let jsonUnknownType = generateDummyJSON(context: DummyJSONContext(type: "unknown"))
        XCTAssertEqual(jsonUnknownType, "{}")

        let jsonEmptyArray = generateDummyJSON(context: DummyJSONContext(type: "array"))
        XCTAssertEqual(jsonEmptyArray, "[]")

        let jsonMissingProp = generateDummyJSON(context: DummyJSONContext(type: "object", required: ["foo"]))
        XCTAssertEqual(jsonMissingProp, #"{"foo": ""}"#)

        let jsonInt = generateDummyJSON(context: DummyJSONContext(type: "integer"))
        XCTAssertEqual(jsonInt, "1")

        let jsonNum = generateDummyJSON(context: DummyJSONContext(type: "number"))
        XCTAssertEqual(jsonNum, "1")

        let jsonBool = generateDummyJSON(context: DummyJSONContext(type: "boolean"))
        XCTAssertEqual(jsonBool, "true")
    }

    /// Verifies `emitTests` with binary data bodies, `HEAD` / `TRACE` methods, and array/object/cyclic schemas.
    func testEmitTestsDummyValueDataAndCombinations() throws {
        let operation = Operation(operationId: "uploadData", requestBody: RequestBody(description: nil, content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))], required: true))
        let pathItem = PathItem(post: operation, head: operation)
        let doc = OpenAPIDocument(openapi: "3.1", info: Info(title: "T", version: "1"), paths: ["/data": pathItem])

        let swiftCode = emitTests(paths: doc.paths, document: doc)
        XCTAssertTrue(swiftCode.contains("test50_UploadData()"))
        XCTAssertTrue(swiftCode.contains(#"fileData: Data("test_data".utf8)"#))

        let opDataOpt = Operation(
            requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))], required: false)
        )
        XCTAssertTrue(emitTests(paths: ["/data": PathItem(post: opDataOpt)]).contains("test01_POST_Post_data"))

        let opCombinations = Operation(
            parameters: [
                Parameter(ref: "#/components/parameters/MyParam", name: nil, in: "query", schema: nil),
                Parameter(name: "status", in: "query", required: true, schema: Schema(type: "array", items: SchemaItem(type: "string"))),
                Parameter(name: "api_key", in: "query", schema: Schema(type: "string")),
                Parameter(name: "pInt", in: "query", required: true, schema: Schema(type: "integer", format: "int64")),
                Parameter(name: "pBool", in: "query", required: true, schema: Schema(type: "boolean")),
                Parameter(name: "pDouble", in: "query", required: true, schema: Schema(type: "number", format: "double")),
                Parameter(name: "pArr", in: "query", required: true, schema: Schema(type: "array", items: SchemaItem(type: "string"))),
                Parameter(name: "name", in: "query", required: false, schema: Schema(type: "string")),
                Parameter(ref: nil, name: nil, in: "query", schema: nil),
                Parameter(name: nil, in: "body", schema: Schema(type: "array", items: SchemaItem(type: "boolean")))
            ],
            responses: ["500": Response(content: ["application/json": MediaType(schema: Schema(type: "string"))])]
        )
        let comboDoc = OpenAPIDocument(
            openapi: "3",
            info: Info(title: "test", version: "1"),
            paths: ["/combos": PathItem(get: opCombinations, trace: opCombinations)],
            components: Components(parameters: ["MyParam": Parameter(name: "MyParam", in: "query", schema: Schema(type: "string"))])
        )
        let emittedCombo = emitTests(paths: comboDoc.paths, document: comboDoc)
        XCTAssertTrue(emittedCombo.contains("pInt: 1"))
        XCTAssertTrue(emittedCombo.contains(#"status: ["available"]"#))

        let cycleDoc = OpenAPIDocument(
            openapi: "3",
            info: Info(title: "test", version: "1"),
            paths: [
                "/cycle": PathItem(
                    get: Operation(responses: ["200": Response(content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/A"))])]),
                    post: Operation(requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object", properties: ["id": Schema(type: "string"), "username": Schema(type: "string")], required: ["missing"]))]))
                )
            ],
            components: Components(schemas: [
                "A": Schema(type: "object", properties: ["b": Schema(ref: "#/components/schemas/B")]),
                "B": Schema(type: "object", properties: ["a": Schema(ref: "#/components/schemas/A")])
            ])
        )
        let cyclePaths = try XCTUnwrap(cycleDoc.paths)
        XCTAssertTrue(emitTests(paths: cyclePaths, document: cycleDoc).contains("test04_GET_Get_cycle"))

        let opBinaryBody = Operation(
            parameters: [
                Parameter(name: "noIn", in: nil, required: true, schema: Schema(type: "string")),
                Parameter(name: "pBody", in: "body", schema: Schema(type: "string", format: "binary"))
            ]
        )
        XCTAssertTrue(emitTests(paths: ["/bin": PathItem(post: opBinaryBody)]).contains("test01_POST_Post_bin"))

        let opStringBody = Operation(
            parameters: [Parameter(name: "strBody", in: "body", schema: Schema(type: "string"))]
        )
        XCTAssertTrue(emitTests(paths: ["/str": PathItem(post: opStringBody)]).contains("test_string"))
    }

    /// Verifies `synthesizeDummyParameterLiteral` and `generateDummyJSON` with examples, enums, and formats.
    func testSynthesizeDummyParameterLiteralsAndFormats() {
        let pExampleStr = Parameter(name: "p1", in: "query", required: true, example: AnyCodable("custom_ex"))
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pExampleStr, swiftType: "String"), #""custom_ex""#)
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pExampleStr, swiftType: "[String]"), #"["custom_ex"]"#)

        let pEnum = Parameter(name: "p2", in: "query", required: true, schema: Schema(type: "string", enum_values: [AnyCodable("pending")]))
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pEnum, swiftType: "String"), #""pending""#)
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pEnum, swiftType: "[String]"), #"["pending"]"#)

        let pSimple = Parameter(name: "p3", in: "query", required: true)
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pSimple, swiftType: "UUID"), "UUID()")
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pSimple, swiftType: "Date"), "Date()")
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pSimple, swiftType: "Data"), #"Data("test_data".utf8)"#)
        XCTAssertEqual(synthesizeDummyParameterLiteral(param: pSimple, swiftType: "[Int]"), "[]")

        XCTAssertEqual(generateDummyJSON(context: DummyJSONContext(type: "string", format: "uuid")), #""00000000-0000-0000-0000-000000000000""#)
        XCTAssertEqual(generateDummyJSON(context: DummyJSONContext(type: "string", format: "date-time")), #""2026-01-01T00:00:00Z""#)
        XCTAssertEqual(generateDummyJSON(context: DummyJSONContext(type: "string", enumValues: [AnyCodable("active")])), #""active""#)
    }

    /// Verifies `TestVisitor` discovery of `test*` methods inside `XCTestCase` subclasses.
    func testTestsParse() {
        let code = """
        class MyTests: XCTestCase {
            let prop = 1
            func helper() {}
            func testSomething() {}
        }
        class NonTestClass {
            func testIgnored() {}
        }
        """
        let syntax = Parser.parse(source: code)
        let visitor = TestVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertEqual(visitor.discoveredTestMethods, ["testSomething"])
    }
}
