@testable import CDDSwift
import XCTest

final class CyclicTests: XCTestCase {
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
