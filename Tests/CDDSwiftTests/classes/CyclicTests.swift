/// Unit tests for parsing recursive/cyclic Swift `Codable` structs into OpenAPI `$ref` schemas.
@testable import CDDSwift
import XCTest

/// Test suite verifying recursive struct AST parsing.
final class CyclicTests: XCTestCase {
    /// Verifies that a struct referencing itself produces a `#/components/schemas/Node` reference.
    func testCyclicModels() throws {
        let source = """
        struct Node: Codable {
            let value: String
            let next: Node?
        }
        """
        let parser = SwiftASTParser()
        let models = try parser.parseModels(from: source)

        let schema = models["Node"]
        XCTAssertEqual(schema?.type, "object")
        XCTAssertEqual(schema?.properties?["next"]?.ref, "#/components/schemas/Node")
    }
}
