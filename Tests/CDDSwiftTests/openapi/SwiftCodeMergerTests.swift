/// Unit tests for `SwiftCodeMerger` AST-preserving Swift source merging.
@testable import CDDSwift
import XCTest

/// Test suite verifying `SwiftCodeMerger`.
final class SwiftCodeMergerTests: XCTestCase {
    /// Verifies appending newly generated structs when they do not exist in the target file.
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

    /// Verifies replacing an existing struct while preserving its leading documentation comments.
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

    /// Verifies merging enum and protocol declarations while preserving unchanged types and comments.
    func testMergeEnumsAndProtocols() {
        let existing = """
        /// Old Enum Doc
        enum MyEnum {
            case a
        }

        /// Old Protocol Doc
        protocol MyProto {
            func doThing()
        }

        enum UnchangedEnum {}
        protocol UnchangedProto {}
        """

        let generated = """
        enum MyEnum {
            case a
            case b
        }

        protocol MyProto {
            func doThing()
            func doAnother()
        }
        """

        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        XCTAssertTrue(merged.contains("case b"))
        XCTAssertTrue(merged.contains("func doAnother()"))
        XCTAssertTrue(merged.contains("UnchangedEnum"))
        XCTAssertTrue(merged.contains("UnchangedProto"))
        XCTAssertTrue(merged.contains("/// Old Enum Doc"))
        XCTAssertTrue(merged.contains("/// Old Protocol Doc"))
    }

    /// Verifies newline formatting when the existing source ends with a single newline.
    func testMergeFormattingOneNewline() {
        let existing = "struct UserCode {}\n"
        let generated = "struct AutoGen {}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = "struct UserCode {}\n\nstruct AutoGen {}\n"
        XCTAssertEqual(merged, expected)
    }

    /// Verifies newline formatting when the existing source does not end with a newline.
    func testMergeFormattingNoNewline() {
        let existing = "struct UserCode {}"
        let generated = "struct AutoGen {}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = "struct UserCode {}\n\nstruct AutoGen {}\n"
        XCTAssertEqual(merged, expected)
    }
}
