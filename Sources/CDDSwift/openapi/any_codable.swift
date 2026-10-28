/// Type-safe, `Sendable`, `Equatable`, `Hashable`, and `Codable` JSON value representation (`JSONValue` and `AnyCodable`).

/// Strongly-typed recursive JSON value enum with full `Sendable`, `Equatable`, `Hashable`, and `Codable` support.
public enum JSONValue: Codable, Equatable, Hashable, Sendable, CustomStringConvertible,
    ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral,
    ExpressibleByNilLiteral {
    /// JSON `null` literal.
    case null
    /// JSON boolean literal (`true` or `false`).
    case bool(Bool)
    /// JSON integer number.
    case int(Int)
    /// JSON floating-point number.
    case double(Double)
    /// JSON UTF-8 string.
    case string(String)
    /// JSON ordered array of `JSONValue` elements.
    case array([JSONValue])
    /// JSON key-value object mapping string keys to `JSONValue` values.
    case object([String: JSONValue])

    /// Returns the wrapped `String` if this value is `.string`, otherwise `nil`.
    public var stringValue: String? {
        guard case let .string(val) = self else { return nil }
        return val
    }

    /// Returns the wrapped `Int` if this value is `.int`, otherwise `nil`.
    public var intValue: Int? {
        guard case let .int(val) = self else { return nil }
        return val
    }

    /// Returns the wrapped `Double` if this value is `.double`, or converts `.int` to `Double`, otherwise `nil`.
    public var doubleValue: Double? {
        switch self {
        case let .double(val): val
        case let .int(val): Double(val)
        default: nil
        }
    }

    /// Returns the wrapped `Bool` if this value is `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        guard case let .bool(val) = self else { return nil }
        return val
    }

    /// Returns the wrapped `[JSONValue]` array if this value is `.array`, otherwise `nil`.
    public var arrayValue: [JSONValue]? {
        guard case let .array(val) = self else { return nil }
        return val
    }

    /// Returns the wrapped `[String: JSONValue]` dictionary if this value is `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        guard case let .object(val) = self else { return nil }
        return val
    }

    /// Returns `true` if this value is `.null`, otherwise `false`.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// Human-readable string representation of the JSON value.
    public var description: String {
        switch self {
        case .null:
            return "null"
        case let .bool(b):
            return String(b)
        case let .int(i):
            return String(i)
        case let .double(d):
            return String(d)
        case let .string(s):
            return s
        case let .array(arr):
            return "[" + arr.map(\.description).joined(separator: ", ") + "]"
        case let .object(dict):
            let pairs = dict.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value.description)" }
            return "{" + pairs.joined(separator: ", ") + "}"
        }
    }

    /// Initializes a `.string` `JSONValue` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self = .string(value)
    }

    /// Initializes an `.int` `JSONValue` from an integer literal.
    ///
    /// - Parameter value: The integer literal value.
    public init(integerLiteral value: Int) {
        self = .int(value)
    }

    /// Initializes a `.double` `JSONValue` from a floating-point literal.
    ///
    /// - Parameter value: The floating-point literal value.
    public init(floatLiteral value: Double) {
        self = .double(value)
    }

    /// Initializes a `.bool` `JSONValue` from a boolean literal.
    ///
    /// - Parameter value: The boolean literal value.
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    /// Initializes an `.array` `JSONValue` from an array literal.
    ///
    /// - Parameter elements: The `JSONValue` array elements.
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }

    /// Initializes an `.object` `JSONValue` from a dictionary literal.
    ///
    /// - Parameter elements: The key-value pairs for the JSON object.
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var dict: [String: JSONValue] = [:]
        for (k, v) in elements {
            dict[k] = v
        }
        self = .object(dict)
    }

    /// Initializes a `.null` `JSONValue` from `nil`.
    ///
    /// - Parameter nilLiteral: The `nil` literal tuple.
    public init(nilLiteral _: ()) {
        self = .null
    }

    /// Decodes a `JSONValue` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the token is not a valid JSON value.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: JSONValue].self) {
            self = .object(dict)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    /// Encodes this `JSONValue` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying value cannot be encoded.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(bool):
            try container.encode(bool)
        case let .int(int):
            try container.encode(int)
        case let .double(double):
            try container.encode(double)
        case let .string(string):
            try container.encode(string)
        case let .array(array):
            try container.encode(array)
        case let .object(dict):
            try container.encode(dict)
        }
    }
}

/// A `Sendable`, `Equatable`, `Hashable`, `Codable` wrapper around `JSONValue` providing ergonomic dynamic JSON handling.
public struct AnyCodable: Codable, Equatable, Hashable, Sendable, CustomStringConvertible,
    ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral,
    ExpressibleByNilLiteral {
    /// The strongly-typed `JSONValue` backing store.
    public let jsonValue: JSONValue

    /// Strongly-typed `JSONValue` representation of this `AnyCodable`.
    public var value: JSONValue {
        jsonValue
    }

    /// Returns the wrapped `String` if this value is `.string`, otherwise `nil`.
    public var stringValue: String? {
        jsonValue.stringValue
    }

    /// Returns the wrapped `Int` if this value is `.int`, otherwise `nil`.
    public var intValue: Int? {
        jsonValue.intValue
    }

    /// Returns the wrapped `Double` if this value is `.double` or `.int`, otherwise `nil`.
    public var doubleValue: Double? {
        jsonValue.doubleValue
    }

    /// Returns the wrapped `Bool` if this value is `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        jsonValue.boolValue
    }

    /// Returns the wrapped `[JSONValue]` array if this value is `.array`, otherwise `nil`.
    public var arrayValue: [JSONValue]? {
        jsonValue.arrayValue
    }

    /// Returns the wrapped `[String: JSONValue]` dictionary if this value is `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        jsonValue.objectValue
    }

    /// Returns `true` if this value is `.null`, otherwise `false`.
    public var isNull: Bool {
        jsonValue.isNull
    }

    /// Human-readable string representation of the wrapped `JSONValue`.
    public var description: String {
        jsonValue.description
    }

    /// Initializes an `AnyCodable` directly from a strongly-typed `JSONValue`.
    ///
    /// - Parameter jsonValue: The `JSONValue` to wrap.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Initializes an `AnyCodable` directly from a `JSONValue`.
    ///
    /// - Parameter value: The `JSONValue` to wrap.
    public init(_ value: JSONValue = .null) {
        jsonValue = value
    }

    /// Initializes an `AnyCodable` wrapping another `AnyCodable`.
    ///
    /// - Parameter other: The `AnyCodable` to copy.
    public init(_ other: AnyCodable) {
        jsonValue = other.jsonValue
    }

    /// Initializes an `AnyCodable` from a `String`.
    ///
    /// - Parameter value: The `String` value.
    public init(_ value: String) {
        jsonValue = .string(value)
    }

    /// Initializes an `AnyCodable` from an `Int`.
    ///
    /// - Parameter value: The `Int` value.
    public init(_ value: Int) {
        jsonValue = .int(value)
    }

    /// Initializes an `AnyCodable` from a `Double`.
    ///
    /// - Parameter value: The `Double` value.
    public init(_ value: Double) {
        jsonValue = .double(value)
    }

    /// Initializes an `AnyCodable` from a `Bool`.
    ///
    /// - Parameter value: The `Bool` value.
    public init(_ value: Bool) {
        jsonValue = .bool(value)
    }

    /// Initializes an `AnyCodable` from an array of `JSONValue` elements.
    ///
    /// - Parameter value: The `[JSONValue]` array.
    public init(_ value: [JSONValue]) {
        jsonValue = .array(value)
    }

    /// Initializes an `AnyCodable` from an array of `AnyCodable` elements.
    ///
    /// - Parameter value: The `[AnyCodable]` array.
    @_disfavoredOverload
    public init(_ value: [AnyCodable]) {
        jsonValue = .array(value.map(\.jsonValue))
    }

    /// Initializes an `AnyCodable` from an array of `String` elements.
    ///
    /// - Parameter value: The `[String]` array.
    public init(_ value: [String]) {
        jsonValue = .array(value.map { .string($0) })
    }

    /// Initializes an `AnyCodable` from an array of `Int` elements.
    ///
    /// - Parameter value: The `[Int]` array.
    public init(_ value: [Int]) {
        jsonValue = .array(value.map { .int($0) })
    }

    /// Initializes an `AnyCodable` from a dictionary of `JSONValue` values.
    ///
    /// - Parameter value: The `[String: JSONValue]` dictionary.
    public init(_ value: [String: JSONValue]) {
        jsonValue = .object(value)
    }

    /// Initializes an `AnyCodable` from a dictionary of `AnyCodable` values.
    ///
    /// - Parameter value: The `[String: AnyCodable]` dictionary.
    @_disfavoredOverload
    public init(_ value: [String: AnyCodable]) {
        jsonValue = .object(value.mapValues { $0.jsonValue })
    }

    /// Initializes an `AnyCodable` from a dictionary of `String` values.
    ///
    /// - Parameter value: The `[String: String]` dictionary.
    public init(_ value: [String: String]) {
        jsonValue = .object(value.mapValues { .string($0) })
    }

    /// Initializes an `AnyCodable` from a dictionary of `Int` values.
    ///
    /// - Parameter value: The `[String: Int]` dictionary.
    public init(_ value: [String: Int]) {
        jsonValue = .object(value.mapValues { .int($0) })
    }

    /// Initializes a `.string` `AnyCodable` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        jsonValue = .string(value)
    }

    /// Initializes an `.int` `AnyCodable` from an integer literal.
    ///
    /// - Parameter value: The integer literal value.
    public init(integerLiteral value: Int) {
        jsonValue = .int(value)
    }

    /// Initializes a `.double` `AnyCodable` from a floating-point literal.
    ///
    /// - Parameter value: The floating-point literal value.
    public init(floatLiteral value: Double) {
        jsonValue = .double(value)
    }

    /// Initializes a `.bool` `AnyCodable` from a boolean literal.
    ///
    /// - Parameter value: The boolean literal value.
    public init(booleanLiteral value: Bool) {
        jsonValue = .bool(value)
    }

    /// Initializes an `.array` `AnyCodable` from an array literal.
    ///
    /// - Parameter elements: The `AnyCodable` array elements.
    public init(arrayLiteral elements: AnyCodable...) {
        jsonValue = .array(elements.map(\.jsonValue))
    }

    /// Initializes an `.object` `AnyCodable` from a dictionary literal.
    ///
    /// - Parameter elements: The key-value pairs for the JSON object.
    public init(dictionaryLiteral elements: (String, AnyCodable)...) {
        var dict: [String: JSONValue] = [:]
        for (k, v) in elements {
            dict[k] = v.jsonValue
        }
        jsonValue = .object(dict)
    }

    /// Initializes a `.null` `AnyCodable` from `nil`.
    ///
    /// - Parameter nilLiteral: The `nil` literal tuple.
    public init(nilLiteral _: ()) {
        jsonValue = .null
    }

    /// Decodes an `AnyCodable` instance from a single-value container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the underlying value cannot be decoded.
    public init(from decoder: Decoder) throws {
        jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes this value into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the wrapped value cannot be encoded.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}
