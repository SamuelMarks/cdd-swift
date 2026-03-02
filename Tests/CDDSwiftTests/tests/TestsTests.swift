@testable import CDDSwift
import XCTest

final class TestsTests: XCTestCase {
    func testEmitTests() {
        let emitted = emitTests(paths: nil)
        XCTAssertTrue(emitted.contains("final class APIClientTests: XCTestCase {"))
    }
}
