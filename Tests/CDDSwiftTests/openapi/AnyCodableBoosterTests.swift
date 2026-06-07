import XCTest
@testable import CDDSwift

final class AnyCodableBoosterTests: XCTestCase {
    func testAnyCodableEquality() {
        let arr1 = AnyCodable([AnyCodable(1), AnyCodable("two")])
        let arr2 = AnyCodable([AnyCodable(1), AnyCodable("two")])
        print("arr1.value type: \(type(of: arr1.value))")
        print("arr1 == arr2: \(arr1 == arr2)")
        let arr3 = AnyCodable([AnyCodable(1)])

        XCTAssertEqual(arr1, arr2)
        XCTAssertNotEqual(arr1, arr3)

        let dict1 = AnyCodable(["a": AnyCodable(1)])
        let dict2 = AnyCodable(["a": AnyCodable(1)])
        let dict3 = AnyCodable(["b": AnyCodable(2)])

        XCTAssertEqual(dict1, dict2)
        XCTAssertNotEqual(dict1, dict3)

        XCTAssertNotEqual(arr1, dict1)
    }

    private struct MockSingleValueDecodingContainer: SingleValueDecodingContainer {
        var codingPath: [CodingKey] = []
        func decodeNil() -> Bool { return false }
        func decode(_: Bool.Type) throws -> Bool { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: String.Type) throws -> String { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Double.Type) throws -> Double { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Float.Type) throws -> Float { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Int.Type) throws -> Int { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Int8.Type) throws -> Int8 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Int16.Type) throws -> Int16 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Int32.Type) throws -> Int32 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: Int64.Type) throws -> Int64 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: UInt.Type) throws -> UInt { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: UInt8.Type) throws -> UInt8 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: UInt16.Type) throws -> UInt16 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: UInt32.Type) throws -> UInt32 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode(_: UInt64.Type) throws -> UInt64 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
        func decode<T: Decodable>(_: T.Type) throws -> T { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
    }

    private struct MockDecoder: Decoder {
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey: Any] = [:]
        func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "fail"))
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "fail"))
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return MockSingleValueDecodingContainer()
        }
    }

    func testAnyCodableNativeEquality() {
        let arr1 = AnyCodable([AnyCodable(1), AnyCodable(2)])
        let arr2 = AnyCodable([AnyCodable(1), AnyCodable(2)])
        XCTAssertEqual(arr1, arr2)

        let dict1 = AnyCodable(["a": AnyCodable(1)])
        let dict2 = AnyCodable(["a": AnyCodable(1)])
        XCTAssertEqual(dict1, dict2)
    }

    func testAnyCodableDecodeFailure() {
        let decoder = MockDecoder()
        XCTAssertThrowsError(try AnyCodable(from: decoder)) { error in
            if let decError = error as? DecodingError {
                switch decError {
                case let .dataCorrupted(context):
                    XCTAssertEqual(context.debugDescription, "AnyCodable value cannot be decoded")
                default:
                    XCTFail("Wrong error")
                }
            } else {
                XCTFail("Wrong error")
            }
        }
    }
}
