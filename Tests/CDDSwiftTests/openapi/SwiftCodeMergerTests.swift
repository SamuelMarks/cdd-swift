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

    func testMergeFormattingOneNewline() {
        let existing = "struct UserCode {}\n"
        let generated = "struct AutoGen {}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = "struct UserCode {}\n\nstruct AutoGen {}\n"
        XCTAssertEqual(merged, expected)
    }

    func testMergeFormattingNoNewline() {
        let existing = "struct UserCode {}"
        let generated = "struct AutoGen {}"
        let merged = SwiftCodeMerger.merge(generatedCode: generated, into: existing)

        let expected = "struct UserCode {}\n\nstruct AutoGen {}\n"
        XCTAssertEqual(merged, expected)
    }
}
