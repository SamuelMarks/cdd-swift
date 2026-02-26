import XCTest
@testable import CDDSwift

final class MocksTests: XCTestCase {
    func testEmitMockClient() {
        let emitted = emitMockClient(paths: nil)
        XCTAssertTrue(emitted.contains("public class MockAPIClient {"))
    }
}
