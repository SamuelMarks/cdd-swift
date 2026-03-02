@testable import CDDSwift
import XCTest

final class ClassesTests: XCTestCase {
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

    func testEmitModel() {
        let schema = Schema(
            type: "object",
            properties: [
                "aString": Schema(type: "string", description: "A string prop"),
            ],
            required: ["aString"],
            description: "Test schema"
        )
        let emitted = emitModel(name: "TestSchema", schema: schema)
        XCTAssertTrue(emitted.contains("/// Test schema"))
        XCTAssertTrue(emitted.contains("public struct TestSchema: Codable, Equatable {"))
        XCTAssertTrue(emitted.contains("/// A string prop"))
        XCTAssertTrue(emitted.contains("public var aString: String\n"))
    }

    func testMapType() {
        XCTAssertEqual(mapType(schema: Schema(type: "string")), "String")
        XCTAssertEqual(mapType(schema: Schema(type: "integer")), "Int")
        XCTAssertEqual(mapType(schema: Schema(type: "boolean")), "Bool")
        XCTAssertEqual(mapType(schema: Schema(type: "number")), "Double")
    }

    func testEmitPolymorphicModelWithDiscriminator() {
        let schema = Schema(
            oneOf: [
                Schema(ref: "#/components/schemas/Dog"),
                Schema(ref: "#/components/schemas/Cat"),
            ],
            discriminator: Discriminator(propertyName: "petType", mapping: [
                "dog": "#/components/schemas/Dog",
                "cat": "#/components/schemas/Cat",
            ])
        )
        let emitted = emitModel(name: "Pet", schema: schema)
        XCTAssertTrue(emitted.contains("public enum Pet: Codable, Equatable {"))
        XCTAssertTrue(emitted.contains("case dog(Dog)"))
        XCTAssertTrue(emitted.contains("case cat(Cat)"))
        XCTAssertTrue(emitted.contains("let type = try container.decode(String.self, forKey: .petType)"))
        XCTAssertTrue(emitted.contains("case \"dog\":"))
        XCTAssertTrue(emitted.contains("self = .dog(try singleContainer.decode(Dog.self))"))
    }

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
}
