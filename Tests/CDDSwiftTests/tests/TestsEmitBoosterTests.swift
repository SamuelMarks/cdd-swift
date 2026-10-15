import XCTest
@testable import CDDSwift

final class TestsEmitBoosterTests: XCTestCase {
    func testGenerateDummyJSONCyclesAndDefaults() {
        // Cyclic ref
        let schema1 = Schema(type: "object", ref: "#/components/schemas/A")
        let schemas = ["A": schema1]
        let visited = Set(["A"])
        let jsonCycle = generateDummyJSON(context: DummyJSONContext(ref: "#/components/schemas/A", schemas: schemas, visited: visited))
        XCTAssertEqual(jsonCycle, "{}")

        // Missing ref from schemas map
        let jsonMissingRef = generateDummyJSON(context: DummyJSONContext(ref: "#/components/schemas/Missing", schemas: schemas))
        XCTAssertEqual(jsonMissingRef, "{}")

        // Unknown type
        let jsonUnknownType = generateDummyJSON(context: DummyJSONContext(type: "unknown"))
        XCTAssertEqual(jsonUnknownType, "{}")

        // Array without items
        let jsonEmptyArray = generateDummyJSON(context: DummyJSONContext(type: "array"))
        XCTAssertEqual(jsonEmptyArray, "[]")

        // Object missing property
        let jsonMissingProp = generateDummyJSON(context: DummyJSONContext(type: "object", required: ["foo"]))
        XCTAssertEqual(jsonMissingProp, "{\"foo\": \"\"}")

        // Integer
        let jsonInt = generateDummyJSON(context: DummyJSONContext(type: "integer"))
        XCTAssertEqual(jsonInt, "1")

        // Number
        let jsonNum = generateDummyJSON(context: DummyJSONContext(type: "number"))
        XCTAssertEqual(jsonNum, "1")

        let jsonBool = generateDummyJSON(context: DummyJSONContext(type: "boolean"))
        XCTAssertEqual(jsonBool, "true")
    }

    func testEmitTestsDummyValueData() {
        // Test bodyType == Data fallback in emitTests
        let operation = Operation(operationId: "uploadData", requestBody: RequestBody(description: nil, content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))], required: true))
        let pathItem = PathItem(post: operation, head: operation)
        let doc = OpenAPIDocument(openapi: "3.1", info: Info(title: "T", version: "1"), paths: ["/data": pathItem])

        let swiftCode = emitTests(paths: doc.paths, document: doc)
        XCTAssertTrue(swiftCode.contains("test50_UploadData()")) // HEAD triggers default: testPrefix = "50_"
        XCTAssertTrue(swiftCode.contains("fileData: Data(\"test_data\".utf8)"))
    }

    func testEmitTestsStatusArrayDummy() {
        let param = Parameter(name: "status", in: "query", description: nil, required: true, deprecated: false, allowEmptyValue: false, style: nil, explode: nil, schema: Schema(type: "array", items: SchemaItem(type: "string")))
        let operation = Operation(operationId: "getStatus", parameters: [param])
        let pathItem = PathItem(get: operation)
        let doc = OpenAPIDocument(openapi: "3.1", info: Info(title: "T", version: "1"), paths: ["/status": pathItem])

        let swiftCode = emitTests(paths: doc.paths, document: doc)
        XCTAssertTrue(swiftCode.contains("status: [\"available\"]"))
    }
}
