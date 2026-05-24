import XCTest
@testable import CDDSwift

final class CoverageBoosterTests5: XCTestCase {
    func testClassesEmitDiscriminatorMappingFallback() {
        // Line 78 fallback: mappingKey ?? typeName
        let discriminator = Discriminator(propertyName: "type", mapping: ["wrong": "#/definitions/WrongType"])
        let option = Schema(type: "object", ref: "#/components/schemas/TargetType")
        let schema = Schema(
            type: "object",
            oneOf: [option],
            discriminator: discriminator
        )
        let swiftCode = emitModel(name: "Poly", schema: schema)
        XCTAssertTrue(swiftCode.contains("case \"TargetType\":"))
    }

    func testMapTypeArrayItemEmpty() {
        let schema = Schema(type: "array", items: SchemaItem())
        let swiftCode = mapType(schema: schema)
        XCTAssertEqual(swiftCode, "[AnyCodable]")
    }
}
