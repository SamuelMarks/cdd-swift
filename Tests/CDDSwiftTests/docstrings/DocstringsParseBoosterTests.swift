import XCTest
import SwiftParser
@testable import CDDSwift

final class DocstringsParseBoosterTests: XCTestCase {
    func testParseBlockDocstring() throws {
        let swiftCode = """
        /**
         This is a block comment.
         It spans multiple lines.
         */
        struct MyStruct: Codable {}
        """
        let parser = SwiftASTParser()
        let schemas = try parser.parseModels(from: swiftCode)

        XCTAssertEqual(schemas["MyStruct"]?.description, "/**\n This is a block comment.\n It spans multiple lines.\n */")
    }
}
