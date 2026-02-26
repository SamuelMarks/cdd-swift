import XCTest
import SwiftSyntax
import SwiftParser
@testable import CDDSwift

final class DocstringsTests: XCTestCase {
    func testParseDocstring() {
        let source = """
        /// This is a docstring.
        /// It spans two lines.
        struct Example {}
        """
        let node = Parser.parse(source: source).statements.first!.item
        let doc = parseDocstring(from: Syntax(node))
        XCTAssertEqual(doc, "This is a docstring.\nIt spans two lines.")
    }
    
    func testEmitDocstring() {
        let doc = "Line 1\nLine 2"
        let emitted = emitDocstring(doc, indent: 4)
        XCTAssertEqual(emitted, "    /// Line 1\n    /// Line 2\n")
    }
    
    func testEmitDocstringSanitization() {
        let doc = "Some doc with */ inside it."
        let emitted = emitDocstring(doc, indent: 4)
        XCTAssertEqual(emitted, "    /// Some doc with *\\/ inside it.\n")
    }
    
    func testEmitDocstringEmpty() {
        XCTAssertEqual(emitDocstring(nil), "")
        XCTAssertEqual(emitDocstring(""), "")
    }
}
