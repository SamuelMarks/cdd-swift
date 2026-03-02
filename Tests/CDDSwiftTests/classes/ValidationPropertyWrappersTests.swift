@testable import CDDSwift
import XCTest

final class ValidationPropertyWrappersTests: XCTestCase {
    struct TestModel: Codable, Equatable {
        @Minimum(10) var minVal: Int = 15
        @Maximum(100) var maxVal: Int = 50
        @MinLength(5) var minLen: String = "hello"
        @MaxLength(10) var maxLen: String = "world"
        @CDDSwift.Pattern("^[a-z]+$") var pat: String = "abc"
    }

    func testValidationWrappers() throws {
        let model = TestModel()
        XCTAssertEqual(model.minVal, 15)
        XCTAssertEqual(model.maxVal, 50)
        XCTAssertEqual(model.minLen, "hello")
        XCTAssertEqual(model.maxLen, "world")
        XCTAssertEqual(model.pat, "abc")

        let encoder = JSONEncoder()
        let data = try encoder.encode(model)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestModel.self, from: data)

        XCTAssertEqual(decoded, model)
        XCTAssertEqual(decoded.minVal, 15)
        XCTAssertEqual(decoded.maxVal, 50)
        XCTAssertEqual(decoded.minLen, "hello")
        XCTAssertEqual(decoded.maxLen, "world")
        XCTAssertEqual(decoded.pat, "abc")
    }
}
