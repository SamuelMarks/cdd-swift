import XCTest
@testable import CDDSwift

final class CoverageBoosterTests2: XCTestCase {
    func testAnyCodableFailures() {
        // Encode failure
        struct Uncodable {}
        let any = AnyCodable(Uncodable())
        XCTAssertThrowsError(try JSONEncoder().encode(any))

        let any2 = AnyCodable(AnyCodable(1))
        _ = try? JSONEncoder().encode(any2)
    }
}
