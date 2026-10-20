/// Unit tests for `AnyCodable` encoding, decoding, and equality semantics.
@testable import CDDSwift
import XCTest

/// Test suite verifying `AnyCodable` serialization, deserialization, and error handling.
final class AnyCodableTests: XCTestCase {
    /// Verifies encoding, decoding, and equality comparisons for `AnyCodable` values.
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

        let nullJV = AnyCodable(jsonValue: .null)
        XCTAssertTrue(nullJV.value is NSNull)

        let jv = AnyCodable(jsonValue: .string("direct"))
        XCTAssertEqual(jv.value as? String, "direct")
        let fromJV = AnyCodable(JSONValue.int(42))
        XCTAssertEqual(fromJV.value as? Int, 42)

        struct Unencodable {}
        let bad = AnyCodable(Unencodable())
        XCTAssertTrue(bad.value is NSNull)
        XCTAssertNotEqual(bad, AnyCodable("test"))
        XCTAssertNotEqual(bad, bad)

        let badArr = AnyCodable([Unencodable()])
        XCTAssertNil(badArr.jsonValue)
        let badDict = AnyCodable(["k": Unencodable()])
        XCTAssertNil(badDict.jsonValue)

        XCTAssertThrowsError(try JSONEncoder().encode(bad))
        let nested = AnyCodable(AnyCodable(1))
        let encodedNested = try JSONEncoder().encode(nested)
        XCTAssertEqual(String(decoding: encodedNested, as: UTF8.self), "1")

        let arr1 = AnyCodable([AnyCodable(1), AnyCodable("two")])
        let arr2 = AnyCodable([AnyCodable(1), AnyCodable("two")])
        let arr3 = AnyCodable([AnyCodable(1)])
        XCTAssertEqual(arr1, arr2)
        XCTAssertNotEqual(arr1, arr3)

        let dict1 = AnyCodable(["a": AnyCodable(1)])
        let dict2 = AnyCodable(["a": AnyCodable(1)])
        let dict3 = AnyCodable(["b": AnyCodable(2)])
        XCTAssertEqual(dict1, dict2)
        XCTAssertNotEqual(dict1, dict3)
        XCTAssertNotEqual(arr1, dict1)

        let void1 = AnyCodable(())
        let void2 = AnyCodable(())
        XCTAssertEqual(void1, void2)
        let encodedVoid = try JSONEncoder().encode(void1)
        XCTAssertEqual(String(decoding: encodedVoid, as: UTF8.self), "null")
    }

    /// Mock single-value decoding container that throws `DecodingError.dataCorruptedError` on every decode operation.
    private struct FailingSingleValueDecodingContainer: SingleValueDecodingContainer {
        /// The path of coding keys taken to get to this point in decoding.
        let codingPath: [CodingKey] = []

        /// Returns `false` so decoding proceeds to typed decode methods.
        func decodeNil() -> Bool { return false }

        /// Throws a data-corrupted error when attempting to decode a `Bool`.
        /// - Parameter type: The `Bool` type to decode.
        func decode(_: Bool.Type) throws -> Bool { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `String`.
        /// - Parameter type: The `String` type to decode.
        func decode(_: String.Type) throws -> String { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `Double`.
        /// - Parameter type: The `Double` type to decode.
        func decode(_: Double.Type) throws -> Double { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `Float`.
        /// - Parameter type: The `Float` type to decode.
        func decode(_: Float.Type) throws -> Float { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode an `Int`.
        /// - Parameter type: The `Int` type to decode.
        func decode(_: Int.Type) throws -> Int { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode an `Int8`.
        /// - Parameter type: The `Int8` type to decode.
        func decode(_: Int8.Type) throws -> Int8 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode an `Int16`.
        /// - Parameter type: The `Int16` type to decode.
        func decode(_: Int16.Type) throws -> Int16 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode an `Int32`.
        /// - Parameter type: The `Int32` type to decode.
        func decode(_: Int32.Type) throws -> Int32 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode an `Int64`.
        /// - Parameter type: The `Int64` type to decode.
        func decode(_: Int64.Type) throws -> Int64 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `UInt`.
        /// - Parameter type: The `UInt` type to decode.
        func decode(_: UInt.Type) throws -> UInt { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `UInt8`.
        /// - Parameter type: The `UInt8` type to decode.
        func decode(_: UInt8.Type) throws -> UInt8 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `UInt16`.
        /// - Parameter type: The `UInt16` type to decode.
        func decode(_: UInt16.Type) throws -> UInt16 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `UInt32`.
        /// - Parameter type: The `UInt32` type to decode.
        func decode(_: UInt32.Type) throws -> UInt32 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode a `UInt64`.
        /// - Parameter type: The `UInt64` type to decode.
        func decode(_: UInt64.Type) throws -> UInt64 { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }

        /// Throws a data-corrupted error when attempting to decode any generic `Decodable` type.
        /// - Parameter type: The generic `Decodable` type to decode.
        func decode<T: Decodable>(_: T.Type) throws -> T { throw DecodingError.dataCorruptedError(in: self, debugDescription: "fail") }
    }

    /// Mock decoder that returns `FailingSingleValueDecodingContainer` to exercise `AnyCodable` decoding failure paths.
    private struct FailingDecoder: Decoder {
        /// The path of coding keys taken to get to this point in decoding.
        let codingPath: [CodingKey] = []

        /// Contextual user-provided information for use during decoding.
        let userInfo: [CodingUserInfoKey: Any] = [:]

        /// Throws a data-corrupted error when requesting a keyed decoding container.
        /// - Parameter type: The coding key type for the container.
        func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "fail"))
        }

        /// Throws a data-corrupted error when requesting an unkeyed decoding container.
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "fail"))
        }

        /// Returns a `FailingSingleValueDecodingContainer` that throws on all decode attempts.
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return FailingSingleValueDecodingContainer()
        }
    }

    /// Verifies that `AnyCodable(from:)` throws a `DecodingError` when all underlying container decode calls fail.
    func testAnyCodableDecodeFailure() throws {
        let decoder = FailingDecoder()
        XCTAssertTrue(decoder.codingPath.isEmpty)
        XCTAssertTrue(decoder.userInfo.isEmpty)
        enum DummyKey: CodingKey { case a }
        XCTAssertThrowsError(try decoder.container(keyedBy: DummyKey.self))
        XCTAssertThrowsError(try decoder.unkeyedContainer())

        let svc = try decoder.singleValueContainer()
        XCTAssertTrue(svc.codingPath.isEmpty)
        XCTAssertThrowsError(try svc.decode(Float.self))
        XCTAssertThrowsError(try svc.decode(Int8.self))
        XCTAssertThrowsError(try svc.decode(Int16.self))
        XCTAssertThrowsError(try svc.decode(Int32.self))
        XCTAssertThrowsError(try svc.decode(Int64.self))
        XCTAssertThrowsError(try svc.decode(UInt.self))
        XCTAssertThrowsError(try svc.decode(UInt8.self))
        XCTAssertThrowsError(try svc.decode(UInt16.self))
        XCTAssertThrowsError(try svc.decode(UInt32.self))
        XCTAssertThrowsError(try svc.decode(UInt64.self))

        XCTAssertThrowsError(try AnyCodable(from: decoder)) { error in
            XCTAssertNotNil(error as? DecodingError)
        }
    }
}
