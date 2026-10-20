/// Unit tests for OpenAPI schema model emission and Swift AST model parsing.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite covering `emitModel`, `mapType`, and `ModelVisitor` AST parsing.
final class ClassesTests: XCTestCase {
    /// Verifies parsing of a basic `Codable` struct and its property docstrings.
    func testParseModel() throws {
        let source = """
        /// Test model
        struct TestModel: Codable {
            /// A string property
            let aString: String
        }
        """
        let parser = SwiftASTParser()
        let models = try parser.parseModels(from: source)
        XCTAssertEqual(models["TestModel"]?.type, "object")
        XCTAssertEqual(models["TestModel"]?.description, "Test model")
        XCTAssertEqual(models["TestModel"]?.properties?["aString"]?.type, "string")
        XCTAssertEqual(models["TestModel"]?.properties?["aString"]?.description, "A string property")
    }

    /// Verifies emitting a Swift struct from an OpenAPI object `Schema`.
    func testEmitModel() {
        let schema = Schema(
            type: "object",
            properties: [
                "aString": Schema(type: "string", description: "A string prop")
            ],
            required: ["aString"],
            description: "Test schema"
        )
        let emitted = emitModel(name: "TestSchema", schema: schema)
        XCTAssertTrue(emitted.contains("/// Test schema"))
        XCTAssertTrue(emitted.contains("public struct TestSchema: Codable, Equatable {"))
        XCTAssertTrue(emitted.contains("/// A string prop"))
        XCTAssertTrue(emitted.contains("public var aString: String"))
    }

    /// Verifies primitive, reference, array, dictionary, and fallback type mappings in `mapType`.
    func testMapType() {
        XCTAssertEqual(mapType(schema: Schema(type: "string")), "String")
        XCTAssertEqual(mapType(schema: Schema(type: "integer")), "Int")
        XCTAssertEqual(mapType(schema: Schema(type: "boolean")), "Bool")
        XCTAssertEqual(mapType(schema: Schema(type: "number")), "Double")
        XCTAssertEqual(mapType(schema: Schema(type: "number", format: "float")), "Float")
        XCTAssertEqual(mapType(schema: Schema(type: "unknown_type")), "AnyCodable")
        XCTAssertEqual(mapType(schema: Schema(type: nil)), "AnyCodable")
        XCTAssertEqual(mapType(schema: Schema(ref: "JustString")), "JustString")
        XCTAssertEqual(mapType(schema: Schema(type: "array", items: SchemaItem())), "[AnyCodable]")
        XCTAssertEqual(mapType(schema: Schema(type: "array", items: SchemaItem(type: nil, ref: "#/components/schemas/ArrayRef"))), "[ArrayRef]")
        XCTAssertEqual(mapType(schema: Schema(type: "array", items: SchemaItem(type: nil, ref: "NoSlashesHere"))), "[NoSlashesHere]")
        XCTAssertEqual(mapType(schema: Schema(type: "object", additionalProperties: SchemaItem(ref: nil))), "[String: AnyCodable]")
        XCTAssertEqual(mapType(schema: Schema(type: "object", additionalProperties: SchemaItem(type: nil, ref: "#/components/schemas/DictRef"))), "[String: DictRef]")
        XCTAssertEqual(mapType(schema: Schema(type: "object", additionalProperties: SchemaItem(type: nil, ref: "NoSlashesHereEither"))), "[String: NoSlashesHereEither]")
    }

    /// Verifies emitting polymorphic `oneOf` enums with discriminator mappings and fallback keys.
    func testEmitPolymorphicModelWithDiscriminator() {
        let schema = Schema(
            oneOf: [
                Schema(ref: "#/components/schemas/Dog"),
                Schema(ref: "#/components/schemas/Cat")
            ],
            discriminator: Discriminator(propertyName: "petType", mapping: [
                "dog": "#/components/schemas/Dog",
                "cat": "#/components/schemas/Cat"
            ])
        )
        let emitted = emitModel(name: "Pet", schema: schema)
        XCTAssertTrue(emitted.contains("public enum Pet: Codable, Equatable {"))
        XCTAssertTrue(emitted.contains("case dog(Dog)"))
        XCTAssertTrue(emitted.contains("case cat(Cat)"))
        XCTAssertTrue(emitted.contains("let type = try container.decode(String.self, forKey: .petType)"))
        XCTAssertTrue(emitted.contains(#"case "dog":"#))
        XCTAssertTrue(emitted.contains("self = .dog(try singleContainer.decode(Dog.self))"))

        let discriminatorFallback = Discriminator(propertyName: "type", mapping: ["wrong": "#/definitions/WrongType"])
        let option = Schema(type: "object", ref: "#/components/schemas/TargetType")
        let fallbackSchema = Schema(type: "object", oneOf: [option], discriminator: discriminatorFallback)
        XCTAssertTrue(emitModel(name: "Poly", schema: fallbackSchema).contains(#"case "TargetType":"#))
    }

    /// Verifies emitting structs, typealiases, enums, and validation property wrappers across schema shapes.
    func testEmitModelVariantsAndValidation() {
        let schema1 = Schema(type: "array", prefixItems: [Schema(type: "string")])
        let schema2 = Schema(type: "array")
        let schema3 = Schema(type: "object", additionalProperties: SchemaItem(ref: "#/components/schemas/User"))
        let schema5 = Schema(type: "object", additionalProperties: nil)
        XCTAssertTrue(emitModel(name: "Test1", schema: schema1).contains("(String)"))
        XCTAssertTrue(emitModel(name: "Test2", schema: schema2).contains("[AnyCodable]"))
        XCTAssertTrue(emitModel(name: "Test3", schema: schema3).contains("[String: User]"))
        XCTAssertTrue(emitModel(name: "Test5", schema: schema5).contains("public struct Test5"))

        let schemaEnum = Schema(type: "string", enum_values: [AnyCodable("val1"), AnyCodable("val2")])
        XCTAssertTrue(emitModel(name: "TestEnum", schema: schemaEnum).contains("case val1"))

        let schemaDoc = Schema(maximum: 100, minimum: 0, maxLength: 10, minLength: 5, pattern: "^A")
        let emittedDoc = emitModel(name: "ValidationModel", schema: schemaDoc)
        XCTAssertTrue(emittedDoc.contains("Maximum Length: 10"))
        XCTAssertTrue(emittedDoc.contains("Minimum Length: 5"))

        let schemaArr = Schema(type: "array", items: SchemaItem(type: "string"))
        XCTAssertTrue(emitModel(name: "ArrModel", schema: schemaArr).contains("typealias ArrModel = [String]"))

        let schemaStr = Schema(type: "string")
        XCTAssertTrue(emitModel(name: "StrModel", schema: schemaStr).contains("typealias StrModel = String"))

        let schemaDict = Schema(type: "object", additionalProperties: SchemaItem(type: "string"))
        XCTAssertTrue(emitModel(name: "DictModel", schema: schemaDict).contains("typealias DictModel = [String: String]"))

        let propSchema = Schema(type: "string", maximum: 100, minimum: 0, maxLength: 10, minLength: 1, pattern: "A")
        let schemaObj = Schema(type: "object", properties: ["prop": propSchema])
        XCTAssertTrue(emitModel(name: "ObjValModel", schema: schemaObj).contains("@Pattern"))

        let anySchema = Schema()
        XCTAssertTrue(emitModel(name: "AnyModel", schema: anySchema).contains("public struct AnyModel: Codable, Equatable"))

        let schemaDiscriminator = Schema(
            type: "object",
            properties: ["type": Schema(type: "string")],
            discriminator: Discriminator(propertyName: "type", mapping: ["Child": "#/components/schemas/ChildType"])
        )
        XCTAssertTrue(emitModel(name: "Parent", schema: schemaDiscriminator).contains("public struct Parent"))
    }

    /// Verifies parsing validation property wrappers on struct properties.
    func testParseModelWithValidation() throws {
        let source = """
        struct ValidationModel: Codable {
            @Minimum(10)
            @Maximum(100)
            let age: Int

            @MinLength(5)
            @MaxLength(20)
            @Pattern("^[a-zA-Z]+$")
            let username: String
        }
        """
        let parser = SwiftASTParser()
        let models = try parser.parseModels(from: source)

        let ageSchema = models["ValidationModel"]?.properties?["age"]
        XCTAssertEqual(ageSchema?.minimum, 10)
        XCTAssertEqual(ageSchema?.maximum, 100)

        let usernameSchema = models["ValidationModel"]?.properties?["username"]
        XCTAssertEqual(usernameSchema?.minLength, 5)
        XCTAssertEqual(usernameSchema?.maxLength, 20)
        XCTAssertEqual(usernameSchema?.pattern, "^[a-zA-Z]+$")
    }

    /// Verifies AST parsing of enums, typealiases, nested CodingKeys, tuples, closures, and special types.
    func testParseModelEdgeCases() throws {
        let swiftCode = """
        /// Test model doc
        struct TestModelWithCodingKeys {
            enum CodingKeys: String, CodingKey { case a }
        }

        enum MySimpleEnum: String {
            case one
            case two = "TWO"
            case three = 3
        }

        enum StringEnumFallback: Int {
            case A = 1
        }

        enum EmptyAssocEnum: Codable {
            case empty()
        }

        enum EmptyOneOf {}

        struct EmptyStruct: Codable {}

        struct ArrayOfRef: Codable {
            var arr: [EmptyStruct]
        }

        struct TupleAndUnknown: Codable {
            var tuple: ()
            var intProp: Integer
            var unknown: SomeUnknownClass
            var floatVal: Float
            var dataVal: Data
            var anyVal: AnyCodable
            var funcVal: () -> Void
        }

        /// MyDictDoc
        typealias MyDict = [String: String]
        typealias MyArr = [String]
        """

        let parser = SwiftASTParser()
        let schemas = try parser.parseModels(from: swiftCode)

        XCTAssertNil(schemas["TestModelWithCodingKeys"])
        XCTAssertNotNil(schemas["MySimpleEnum"])
        XCTAssertNil(schemas["StringEnumFallback"])
        XCTAssertNotNil(schemas["EmptyAssocEnum"])
        XCTAssertNil(schemas["EmptyOneOf"])
        XCTAssertNotNil(schemas["EmptyStruct"])
        XCTAssertNotNil(schemas["ArrayOfRef"])
        XCTAssertNotNil(schemas["TupleAndUnknown"])
        XCTAssertEqual(schemas["TupleAndUnknown"]?.properties?["dataVal"]?.format, "binary")
        XCTAssertEqual(schemas["TupleAndUnknown"]?.properties?["anyVal"]?.type, "object")
        XCTAssertNotNil(schemas["MyDict"])
        XCTAssertNotNil(schemas["MyArr"])
    }
}
