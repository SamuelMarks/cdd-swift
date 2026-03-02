@testable import CDDSwift
import XCTest

final class AnyCodableTests: XCTestCase {
    func testAnyCodable() throws {
        let stringValue = AnyCodable("test")
        let intValue = AnyCodable(123)
        let boolValue = AnyCodable(true)
        let doubleValue = AnyCodable(12.34)
        let arrayValue = AnyCodable([1, 2, 3])
        let dictValue = AnyCodable(["key": "value"])

        let encoder = JSONEncoder()

        let stringData = try encoder.encode(stringValue)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), "\"test\"")

        let intData = try encoder.encode(intValue)
        XCTAssertEqual(String(data: intData, encoding: .utf8), "123")

        let decoder = JSONDecoder()

        let decodedString = try decoder.decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(decodedString.value as? String, "test")
        XCTAssertEqual(decodedString, stringValue)

        let decodedInt = try decoder.decode(AnyCodable.self, from: intData)
        XCTAssertEqual(decodedInt.value as? Int, 123)
        XCTAssertEqual(decodedInt, intValue)

        let decodedDict = try decoder.decode(AnyCodable.self, from: encoder.encode(dictValue))
        XCTAssertNotNil(decodedDict.value as? [String: String])
    }
}
