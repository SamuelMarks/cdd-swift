import XCTest
@testable import CDDSwift

final class FinalCoverageBoosterTests: XCTestCase {
    func testServerEmitMissing() {
        let stringSchema = Schema(type: "string", format: nil)
        XCTAssertEqual(mapFluentFieldType(schema: stringSchema), "String")

        let unknownSchema = Schema(type: "unknown", format: nil)
        XCTAssertEqual(mapFluentFieldType(schema: unknownSchema), "String")
    }
}
