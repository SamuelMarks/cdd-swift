/// Unit tests for Swift docstring emission and AST docstring parsing.
@testable import CDDSwift
import SwiftParser
import SwiftSyntax
import XCTest

/// Test suite verifying `emitDocstring` and `parseDocstring`.
final class DocstringsTests: XCTestCase {
    /// Verifies parsing multi-line `///` docstrings from syntax trivia.
    func testParseDocstring() throws {
        let source = """
        /// This is a docstring.
        /// It spans two lines.
        struct Example {}
        """
        let node = try XCTUnwrap(Parser.parse(source: source).statements.first?.item)
        let doc = parseDocstring(from: Syntax(node))
        XCTAssertEqual(doc, ["This is a docstring.", "It spans two lines."].joined(separator: String(UnicodeScalar(10))))
    }

    /// Verifies emitting indented `///` docstrings.
    func testEmitDocstring() {
        let nl = String(UnicodeScalar(10))
        let doc = "Line 1" + nl + "Line 2"
        let emitted = emitDocstring(doc, indent: 4)
        XCTAssertEqual(emitted, "    /// Line 1" + nl + "    /// Line 2" + nl)
    }

    /// Verifies escaping of `*/` sequences inside emitted docstrings.
    func testEmitDocstringSanitization() {
        let nl = String(UnicodeScalar(10))
        let bs = String(UnicodeScalar(92))
        let doc = "Some doc with */ inside it."
        let emitted = emitDocstring(doc, indent: 4)
        XCTAssertEqual(emitted, "    /// Some doc with *" + bs + "/ inside it." + nl)
    }

    /// Verifies `emitDocstring` returns an empty string for `nil` or empty input.
    func testEmitDocstringEmpty() {
        XCTAssertEqual(emitDocstring(nil), "")
        XCTAssertEqual(emitDocstring(""), "")
    }

    /// Verifies parsing `/** ... */` block docstrings and empty docstrings.
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
        let nl = String(UnicodeScalar(10))
        XCTAssertEqual(schemas["MyStruct"]?.description, ["/**", " This is a block comment.", " It spans multiple lines.", " */"].joined(separator: nl))

        let emptyDocsCode = """
        /**  */
        func emptyBlock() {}
        ///
        func emptyLine() {}
        """
        XCTAssertNotNil(try parser.parseDocument(from: emptyDocsCode))
    }
}
