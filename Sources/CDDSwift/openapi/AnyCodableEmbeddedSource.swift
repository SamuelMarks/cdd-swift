/// Embedded Swift source code template for `JSONValue` and `AnyCodable` used by generated client SDK packages.

public extension AnyCodable {
    /// Canonical Swift source code template for embedding `AnyCodable` inside generated client SDK packages.
    static let embeddedSwiftSource: String = """
    /// Strongly-typed recursive JSON value enum with full `Sendable`, `Equatable`, `Hashable`, and `Codable` support.
    public indirect enum JSONValue: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])

        /// Textual description of the JSON value.
        public var description: String {
            switch self {
            case .null: return "null"
            case let .bool(b): return String(b)
            case let .int(i): return String(i)
            case let .double(d): return String(d)
            case let .string(s): return s
            case let .array(arr): return "[" + arr.map { $0.description }.joined(separator: ", ") + "]"
            case let .object(dict):
                let pairs = dict.keys.sorted().compactMap { k -> String? in
                    guard let v = dict[k] else { return nil }
                    return k + ": " + v.description
                }
                return "{" + pairs.joined(separator: ", ") + "}"
            }
        }

        /// Decodes a `JSONValue` from a single-value JSON container.
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
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .null: try container.encodeNil()
            case let .bool(bool): try container.encode(bool)
            case let .int(int): try container.encode(int)
            case let .double(double): try container.encode(double)
            case let .string(string): try container.encode(string)
            case let .array(array): try container.encode(array)
            case let .object(dict): try container.encode(dict)
            }
        }
    }

    /// A `Sendable`, `Equatable`, `Hashable`, `Codable` dynamic JSON value wrapper.
    public struct AnyCodable: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
        /// The underlying strongly-typed JSON value.
        public let value: JSONValue

        /// Textual description of the wrapped value.
        public var description: String { return value.description }

        /// Initializes an `AnyCodable` from a `JSONValue`.
        public init(_ value: JSONValue = .null) {
            self.value = value
        }

        /// Initializes an `AnyCodable` from a `String`.
        public init(_ string: String) {
            self.value = .string(string)
        }

        /// Initializes an `AnyCodable` from an `Int`.
        public init(_ int: Int) {
            self.value = .int(int)
        }

        /// Initializes an `AnyCodable` from a `Double`.
        public init(_ double: Double) {
            self.value = .double(double)
        }

        /// Initializes an `AnyCodable` from a `Bool`.
        public init(_ bool: Bool) {
            self.value = .bool(bool)
        }

        /// Initializes an `AnyCodable` from a `[JSONValue]` array.
        public init(_ array: [JSONValue]) {
            self.value = .array(array)
        }

        /// Initializes an `AnyCodable` from a `[String: JSONValue]` dictionary.
        public init(_ object: [String: JSONValue]) {
            self.value = .object(object)
        }

        /// Decodes an `AnyCodable` from a single-value container.
        public init(from decoder: Decoder) throws {
            self.value = try JSONValue(from: decoder)
        }

        /// Encodes this value into the given encoder.
        public func encode(to encoder: Encoder) throws {
            try value.encode(to: encoder)
        }
    }
    """
}
