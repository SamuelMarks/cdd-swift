/// Type-safe, `Sendable`, `Equatable`, `Hashable`, and `Codable` JSON value representation (`JSONValue` and `AnyCodable`).
import Foundation

/// Strongly-typed recursive JSON value enum with full `Sendable`, `Equatable`, `Hashable`, and `Codable` support.
public enum JSONValue: Codable, Equatable, Hashable, Sendable {
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

    /// Converts this `JSONValue` into its native Swift value (`Bool`, `Int`, `Double`, `String`, `[Any]`, `[String: Any]`, or `NSNull`).
    public var untypedValue: Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(b):
            return b
        case let .int(i):
            return i
        case let .double(d):
            return d
        case let .string(s):
            return s
        case let .array(arr):
            return arr.map { $0.untypedValue }
        case let .object(dict):
            return dict.mapValues { $0.untypedValue }
        }
    }
}

/// A `Sendable`, `Equatable`, `Hashable`, `Codable` wrapper around `JSONValue` providing ergonomic dynamic JSON handling.
public struct AnyCodable: Codable, Equatable, Hashable, Sendable {
    /// Canonical Swift source code template for embedding `AnyCodable` inside generated client SDK packages.
    public static let embeddedSwiftSource: String = """
    /// A type-erased `Codable` value.
    public struct AnyCodable: Codable, Equatable, @unchecked Sendable {
        /// The type-erased value.
        public let value: Any

        /// Initializes an `AnyCodable` wrapping the given value.
        public init(_ value: Any) {
            self.value = value
        }

        /// Decodes an `AnyCodable` from a single-value container.
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else if container.decodeNil() {
                value = NSNull()
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
            }
        }

        /// Encodes this value into the given encoder.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch value {
            case let anyCodable as AnyCodable:
                try anyCodable.encode(to: encoder)
            case let bool as Bool:
                try container.encode(bool)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let string as String:
                try container.encode(string)
            case let array as [Any]:
                try container.encode(array.map { AnyCodable($0) })
            case let dict as [String: Any]:
                try container.encode(dict.mapValues { AnyCodable($0) })
            case is NSNull:
                try container.encodeNil()
            default:
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
            }
        }

        /// Compares two `AnyCodable` instances for equality.
        public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
            switch (lhs.value, rhs.value) {
            case is (Void, Void), is (NSNull, NSNull): return true
            case let (l as AnyCodable, r as AnyCodable): return l == r
            case let (l as Bool, r as Bool): return l == r
            case let (l as Int, r as Int): return l == r
            case let (l as Double, r as Double): return l == r
            case let (l as String, r as String): return l == r
            case let (l as [Any], r as [Any]): return l.map { AnyCodable($0) } == r.map { AnyCodable($0) }
            case let (l as [String: Any], r as [String: Any]): return l.mapValues { AnyCodable($0) } == r.mapValues { AnyCodable($0) }
            default: return false
            }
        }
    }
    """

    /// The strongly-typed `JSONValue` backing store, or `nil` when constructed with an unencodable value.
    public let jsonValue: JSONValue?

    /// Returns the underlying value as a native Swift type (`String`, `Int`, `Double`, `Bool`, `[Any]`, `[String: Any]`, or `NSNull`).
    public var value: Any {
        return jsonValue?.untypedValue ?? NSNull()
    }

    /// Initializes an `AnyCodable` directly from a strongly-typed `JSONValue`.
    ///
    /// - Parameter jsonValue: The `JSONValue` to wrap.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Initializes an `AnyCodable` instance wrapping the provided Swift value.
    ///
    /// - Parameter value: The underlying value to convert into a `JSONValue`.
    public init(_ value: Any) {
        jsonValue = Self.convertToJSONValue(value)
    }

    /// Recursively converts an arbitrary Swift value into a `JSONValue`, or `nil` if unsupported.
    ///
    /// - Parameter raw: The raw Swift value to convert.
    /// - Returns: The corresponding `JSONValue`, or `nil` if the type is not JSON-compatible.
    private static func convertToJSONValue(_ raw: Any) -> JSONValue? {
        switch raw {
        case let anyCodable as AnyCodable:
            return anyCodable.jsonValue
        case let jv as JSONValue:
            return jv
        case is NSNull, is Void:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            var converted: [JSONValue] = []
            for element in array {
                guard let item = convertToJSONValue(element) else { return nil }
                converted.append(item)
            }
            return .array(converted)
        case let dict as [String: Any]:
            var converted: [String: JSONValue] = [:]
            for (k, v) in dict {
                guard let item = convertToJSONValue(v) else { return nil }
                converted[k] = item
            }
            return .object(converted)
        default:
            return nil
        }
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
    /// - Throws: `EncodingError.invalidValue` if the wrapped value is not JSON-encodable.
    public func encode(to encoder: Encoder) throws {
        let container = encoder.singleValueContainer()
        guard let jv = jsonValue else {
            throw EncodingError.invalidValue(
                "unencodable",
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            )
        }
        try jv.encode(to: encoder)
    }

    /// Compares two `AnyCodable` instances for structural equality.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `AnyCodable` value.
    ///   - rhs: The right-hand side `AnyCodable` value.
    /// - Returns: `true` if both wrapped values are valid `JSONValue` instances and equal, `false` otherwise.
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        guard let l = lhs.jsonValue, let r = rhs.jsonValue else {
            return false
        }
        return l == r
    }
}
