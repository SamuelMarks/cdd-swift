import XCTest
import SwiftParser
@testable import CDDSwift

final class ClassesParseBoosterTests: XCTestCase {
    func testClassesParseCoverageBoosts() throws {
        let swiftCode = """
        enum MySimpleEnum: String {
            case one
            case two = "TWO"
            case three = 3
        }

        enum EmptyAssocEnum: Codable {
            case empty()
        }

        struct EmptyStruct: Codable {
        }

        struct ArrayOfRef: Codable {
            var arr: [EmptyStruct]
        }

        struct TupleAndUnknown: Codable {
            var tuple: ()
            var unknown: SomeUnknownClass
            var floatVal: Float
            var funcVal: () -> Void
        }
        """

        let parser = SwiftASTParser()
        let schemas = try parser.parseModels(from: swiftCode)

        XCTAssertNotNil(schemas["MySimpleEnum"])
        XCTAssertNotNil(schemas["EmptyAssocEnum"])
        XCTAssertNotNil(schemas["EmptyStruct"])
        XCTAssertNotNil(schemas["ArrayOfRef"])
        XCTAssertNotNil(schemas["TupleAndUnknown"])
    }
}
