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

        let boolData = try encoder.encode(boolValue)
        XCTAssertEqual(String(data: boolData, encoding: .utf8), "true")

        let doubleData = try encoder.encode(doubleValue)
        XCTAssertEqual(String(data: doubleData, encoding: .utf8), "12.34")

        let arrayData = try encoder.encode(arrayValue)
        XCTAssertEqual(String(data: arrayData, encoding: .utf8), "[1,2,3]")

        let decoder = JSONDecoder()

        let decodedString = try decoder.decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(decodedString.value as? String, "test")
        XCTAssertEqual(decodedString, stringValue)

        let decodedInt = try decoder.decode(AnyCodable.self, from: intData)
        XCTAssertEqual(decodedInt.value as? Int, 123)
        XCTAssertEqual(decodedInt, intValue)

        let decodedBool = try decoder.decode(AnyCodable.self, from: boolData)
        XCTAssertEqual(decodedBool.value as? Bool, true)
        XCTAssertEqual(decodedBool, boolValue)

        let decodedDouble = try decoder.decode(AnyCodable.self, from: doubleData)
        XCTAssertEqual(decodedDouble.value as? Double, 12.34)
        XCTAssertEqual(decodedDouble, doubleValue)

        let decodedArray = try decoder.decode(AnyCodable.self, from: arrayData)
        XCTAssertNotNil(decodedArray.value as? [Int])
        XCTAssertEqual(decodedArray, arrayValue)

        let decodedDict = try decoder.decode(AnyCodable.self, from: encoder.encode(dictValue))
        XCTAssertNotNil(decodedDict.value as? [String: String])
    }
}
