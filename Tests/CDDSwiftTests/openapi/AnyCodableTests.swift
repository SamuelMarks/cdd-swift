/// Unit tests for `AnyCodable` and `JSONValue` encoding, decoding, literals, typed accessors, and equality semantics.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `AnyCodable` and `JSONValue` serialization, deserialization, literal conformances, and error handling.
final class AnyCodableTests: XCTestCase {
    /// Verifies encoding, decoding, and typed accessors for `AnyCodable` and `JSONValue`.
    func testAnyCodable() throws {
        let stringValue = AnyCodable("test")
        let intValue = AnyCodable(123)
        let boolValue = AnyCodable(true)
        let doubleValue = AnyCodable(12.34)
        let arrayValue = AnyCodable([1, 2, 3])
        let strArrayValue = AnyCodable(["a", "b"])
        let dictValue = AnyCodable(["key": "value"])
        let intDictValue = AnyCodable(["count": 5])

        XCTAssertEqual(stringValue.stringValue, "test")
        XCTAssertNil(stringValue.intValue)
        XCTAssertNil(stringValue.doubleValue)
        XCTAssertNil(stringValue.boolValue)
        XCTAssertNil(stringValue.arrayValue)
        XCTAssertNil(stringValue.objectValue)
        XCTAssertFalse(stringValue.isNull)
        XCTAssertEqual(stringValue.description, "test")

        XCTAssertEqual(intValue.intValue, 123)
        XCTAssertEqual(intValue.doubleValue, 123.0)
        XCTAssertNil(intValue.stringValue)
        XCTAssertEqual(intValue.description, "123")
        XCTAssertEqual(boolValue.boolValue, true)
        XCTAssertEqual(boolValue.description, "true")
        XCTAssertEqual(doubleValue.doubleValue, 12.34)
        XCTAssertEqual(doubleValue.description, "12.34")
        XCTAssertEqual(arrayValue.arrayValue, [.int(1), .int(2), .int(3)])
        XCTAssertEqual(arrayValue.description, "[1, 2, 3]")
        XCTAssertEqual(strArrayValue.arrayValue, [.string("a"), .string("b")])
        XCTAssertEqual(dictValue.objectValue, ["key": .string("value")])
        XCTAssertEqual(dictValue.description, "{key: value}")
        XCTAssertEqual(intDictValue.objectValue, ["count": .int(5)])

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stringData = try encoder.encode(stringValue)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), #""test""#)
        let intData = try encoder.encode(intValue)
        XCTAssertEqual(String(data: intData, encoding: .utf8), "123")
        let boolData = try encoder.encode(boolValue)
        XCTAssertEqual(String(data: boolData, encoding: .utf8), "true")
        let doubleData = try encoder.encode(doubleValue)
        XCTAssertEqual(String(data: doubleData, encoding: .utf8), "12.34")
        let arrayData = try encoder.encode(arrayValue)
        XCTAssertEqual(String(data: arrayData, encoding: .utf8), "[1,2,3]")

        XCTAssertEqual(try decoder.decode(AnyCodable.self, from: stringData), stringValue)
        XCTAssertEqual(try decoder.decode(AnyCodable.self, from: intData), intValue)
        XCTAssertEqual(try decoder.decode(AnyCodable.self, from: boolData), boolValue)
        XCTAssertEqual(try decoder.decode(AnyCodable.self, from: doubleData), doubleValue)
        XCTAssertEqual(try decoder.decode(AnyCodable.self, from: arrayData), arrayValue)
        XCTAssertNotNil(try decoder.decode(AnyCodable.self, from: encoder.encode(dictValue)).objectValue)
    }

    /// Verifies literal conformances, null values, nested initializers, and embedded Swift source validity.
    func testAnyCodableLiteralsAndCollections() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let nullJV = AnyCodable(jsonValue: .null)
        XCTAssertTrue(nullJV.isNull)
        XCTAssertEqual(nullJV.value, .null)
        XCTAssertEqual(nullJV.description, "null")
        let encodedNull = try encoder.encode(nullJV)
        XCTAssertEqual(String(decoding: encodedNull, as: UTF8.self), "null")
        XCTAssertTrue(try decoder.decode(AnyCodable.self, from: encodedNull).isNull)

        XCTAssertEqual(AnyCodable(jsonValue: .string("direct")).stringValue, "direct")
        XCTAssertEqual(AnyCodable(JSONValue.int(42)).intValue, 42)
        XCTAssertEqual(AnyCodable([JSONValue.string("x")]).arrayValue, [.string("x")])
        XCTAssertEqual(AnyCodable(["k": JSONValue.bool(false)]).objectValue, ["k": .bool(false)])

        let encodedNested = try encoder.encode(AnyCodable(AnyCodable(1)))
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

        let jvStr: JSONValue = "hello"
        let jvInt: JSONValue = 10
        let jvFloat: JSONValue = 3.5
        let jvBool: JSONValue = false
        let jvArr: JSONValue = ["a", 1]
        let jvObj: JSONValue = ["k": "v"]
        let jvNil: JSONValue = nil
        XCTAssertEqual(jvStr.stringValue, "hello")
        XCTAssertEqual(jvInt.intValue, 10)
        XCTAssertEqual(jvFloat.doubleValue, 3.5)
        XCTAssertEqual(jvBool.boolValue, false)
        XCTAssertEqual(jvArr.arrayValue?.count, 2)
        XCTAssertEqual(jvObj.objectValue?["k"], "v")
        XCTAssertTrue(jvNil.isNull)

        let acStr: AnyCodable = "hello"
        let acInt: AnyCodable = 10
        let acFloat: AnyCodable = 3.5
        let acBool: AnyCodable = false
        let acArr: AnyCodable = ["a", 1]
        let acObj: AnyCodable = ["k": "v"]
        let acNil: AnyCodable = nil
        XCTAssertEqual(acStr.stringValue, "hello")
        XCTAssertEqual(acInt.intValue, 10)
        XCTAssertEqual(acFloat.doubleValue, 3.5)
        XCTAssertEqual(acBool.boolValue, false)
        XCTAssertEqual(acArr.arrayValue?.count, 2)
        XCTAssertEqual(acObj.objectValue?["k"], "v")
        XCTAssertTrue(acNil.isNull)

        let embeddedSyntax = Parser.parse(source: AnyCodable.embeddedSwiftSource)
        XCTAssertFalse(embeddedSyntax.hasError)
    }

    /// Mock single-value decoding container that throws `DecodingError.dataCorruptedError` on every decode operation.
    private struct FailingSingleValueDecodingContainer: SingleValueDecodingContainer {
        /// The path of coding keys taken to get to this point in decoding.
        let codingPath: [CodingKey] = []

        /// Returns `false` so decoding proceeds to typed decode methods.
        func decodeNil() -> Bool { false }

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
            FailingSingleValueDecodingContainer()
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

        let explicitDouble = AnyCodable(Double(3.14))
        XCTAssertEqual(explicitDouble.doubleValue, 3.14)
        let explicitBool = AnyCodable(Bool(true))
        XCTAssertEqual(explicitBool.boolValue, true)
        let typedArr: [AnyCodable] = [AnyCodable("a")]
        let explicitArr = AnyCodable(typedArr)
        XCTAssertEqual(explicitArr.arrayValue?.first?.stringValue, "a")
        let typedObj: [String: AnyCodable] = ["k": AnyCodable("v")]
        let explicitObj = AnyCodable(typedObj)
        XCTAssertEqual(explicitObj.objectValue?["k"]?.stringValue, "v")
    }
}
