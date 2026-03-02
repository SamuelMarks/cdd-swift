@testable import CDDSwift
import XCTest

final class SwiftCodeMergerTests: XCTestCase {
    func testMergeAppendsIfNew() {
        let existing = "struct UserCode {}"
        let generated = "struct AutoGen {}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = """
        struct UserCode {}

        struct AutoGen {}

        """

        XCTAssertEqual(merged, expected)
    }

    func testMergeReplacesAndPreservesComments() {
        let existing = """
        struct UserCode {}

        /// My custom doc comment
        struct AutoGen {
            let oldField: String
        }

        struct MoreUserCode {}
        """

        let generated = "struct AutoGen {\n    let newField: Int\n}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = """
        struct UserCode {}

        /// My custom doc comment
        struct AutoGen {
            let newField: Int
        }

        struct MoreUserCode {}
        """

        XCTAssertEqual(merged, expected)
    }
}
