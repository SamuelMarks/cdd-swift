/// Unit tests for `AnyCodable`, `OpenAPIToSwiftGenerator`, and `OpenAPIDocumentBuilder`.
@testable import CDDSwift
import XCTest

/// Root test suite verifying core `CDDSwift` serialization and generation workflows.
final class CDDSwiftTests: XCTestCase {
    // MARK: - AnyCodable Tests

    /// Verifies encoding and decoding a dictionary of heterogeneous `AnyCodable` values.
    func testAnyCodableEncodingDecoding() throws {
        let original: [String: AnyCodable] = [
            "string": AnyCodable("test"),
            "int": AnyCodable(123),
            "double": AnyCodable(45.6),
            "bool": AnyCodable(true),
            "null": AnyCodable(),
            "array": AnyCodable([1, 2]),
            "dict": AnyCodable(["key": "value"])
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)

        XCTAssertEqual(decoded["string"], AnyCodable("test"))
        XCTAssertEqual(decoded["int"], AnyCodable(123))
        XCTAssertEqual(decoded["double"], AnyCodable(45.6))
        XCTAssertEqual(decoded["bool"], AnyCodable(true))
        XCTAssertEqual(decoded["null"], AnyCodable())
        XCTAssertEqual(decoded["array"], AnyCodable([1, 2]))
        XCTAssertEqual(decoded["dict"], AnyCodable(["key": "value"]))

        // Equatable Edge Cases
        XCTAssertNotEqual(AnyCodable("test"), AnyCodable(123))
        XCTAssertEqual(AnyCodable(), AnyCodable(.null))
    }

    // MARK: - OpenAPI Models and Generator Tests

    /// Returns a sample multi-schema OpenAPI 3.2.0 JSON string for generator testing.
    ///
    /// - Returns: The raw OpenAPI JSON string.
    private func sampleOpenAPIJSON() -> String {
        return """
        {
          "openapi": "3.2.0",
          "info": { "title": "Test API", "version": "1.0.0" },
          "components": {
            "securitySchemes": { "api_key": { "type": "apiKey", "name": "X-API-Key", "in": "header" } },
            "schemas": {
              "PetType": { "type": "string", "enum": ["Cat", "Dog", "Bird"] },
              "BasePet": {
                "type": "object",
                "properties": {
                  "id": { "type": "string", "format": "uuid" },
                  "type": { "$ref": "#/components/schemas/PetType" }
                },
                "required": ["id", "type"]
              },
              "Dog": {
                "allOf": [
                  { "$ref": "#/components/schemas/BasePet" },
                  { "type": "object", "properties": { "barkVolume": { "type": "integer" } }, "required": ["barkVolume"] }
                ]
              },
              "AnyPet": { "anyOf": [{ "$ref": "#/components/schemas/Dog" }] }
            }
          },
          "paths": {
            "/pets/{id}": {
              "get": {
                "operationId": "getPet",
                "parameters": [
                  { "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } },
                  { "name": "verbose", "in": "query", "schema": { "type": "boolean" } }
                ],
                "responses": {
                  "200": {
                    "description": "A pet",
                    "content": { "application/json": { "schema": { "$ref": "#/components/schemas/AnyPet" } } }
                  }
                }
              },
              "post": {
                "operationId": "updatePetImage",
                "requestBody": {
                  "content": {
                    "multipart/form-data": {
                      "schema": { "type": "object", "properties": { "file": { "type": "string", "format": "binary" } } }
                    }
                  }
                },
                "responses": { "200": { "description": "OK" } }
              }
            }
          }
        }
        """
    }

    /// Verifies end-to-end Swift code generation from a multi-schema OpenAPI 3.2.0 specification.
    func testOpenAPIToSwiftGeneration() throws {
        let json = sampleOpenAPIJSON()
        let decoder = JSONDecoder()
        let document = try decoder.decode(OpenAPIDocument.self, from: Data(json.utf8))

        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)

        XCTAssertTrue(swiftCode.contains("public enum PetType: String, Codable, Equatable, CaseIterable, Sendable {"))
        XCTAssertTrue(swiftCode.contains(#"case cat = "Cat""#))
        XCTAssertTrue(swiftCode.contains("public struct BasePet: Codable, Equatable, Sendable {"))
        XCTAssertTrue(swiftCode.contains("public var id: UUID"))
        XCTAssertTrue(swiftCode.contains("public struct Dog: Codable, Equatable, Sendable {"))
        XCTAssertTrue(swiftCode.contains("public var barkVolume: Int"))
        XCTAssertTrue(swiftCode.contains("public enum AnyPet: Codable, Equatable, Sendable {"))
        XCTAssertTrue(swiftCode.contains("case option1(Dog)"))
        XCTAssertTrue(swiftCode.contains("public struct APIClient {"))
        XCTAssertTrue(swiftCode.contains("public let api_keyToken: String?"))
        XCTAssertTrue(swiftCode.contains("public func getPet(id: UUID, verbose: Bool? = nil) async throws -> AnyPet {"))
        XCTAssertTrue(swiftCode.contains("public func updatePetImage(multipartData: AnyCodable? = nil) async throws -> Void {"))
        XCTAssertTrue(swiftCode.contains("multipart/form-data; boundary="))
    }

    // MARK: - Swift to OpenAPI Builder Tests

    /// Verifies building and serializing an `OpenAPIDocument` using `OpenAPIDocumentBuilder`.
    func testSwiftToOpenAPIGeneration() throws {
        let builder = OpenAPIDocumentBuilder(title: "Sample CDD API", version: "1.0.0")
            .addPath("/test", item: PathItem(
                get: Operation(
                    summary: "Get Test",
                    operationId: "getTest",
                    responses: ["200": Response(description: "OK")]
                )
            ))
            .addSchema("TestModel", schema: Schema(
                type: "object",
                properties: ["key": Schema(type: "string")],
                required: ["key"]
            ))

        let document = builder.build()
        XCTAssertEqual(document.info.title, "Sample CDD API")
        XCTAssertNotNil(document.paths?["/test"])
        XCTAssertNotNil(document.components?.schemas?["TestModel"])

        let jsonString = try builder.serialize()
        XCTAssertTrue(jsonString.contains("Sample CDD API"))
        XCTAssertTrue(jsonString.contains("getTest"))
        XCTAssertTrue(jsonString.contains("TestModel"))
    }
}
