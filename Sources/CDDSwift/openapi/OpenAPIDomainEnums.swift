/// Strongly-typed OpenAPI 3.2.0 and Swagger 2.0 domain enums (`SchemaType`, `OpenAPIFormat`, `ParameterLocation`, `ParameterStyle`,
/// `SecuritySchemeType`, `HTTPStatusCode`, `ContentType`, `HTTPMethod`).
import Foundation

// MARK: - Domain Enums

/// Standard JSON Schema / OpenAPI data types.
public enum SchemaType: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral {
    /// UTF-8 character string type (`"string"`).
    case string
    /// Floating-point or arbitrary-precision numeric type (`"number"`).
    case number
    /// Integral numeric type (`"integer"`).
    case integer
    /// Boolean truth value type (`"boolean"`).
    case boolean
    /// Ordered list of items type (`"array"`).
    case array
    /// Key-value map / structured object type (`"object"`).
    case object
    /// Explicit null value type (`"null"`).
    case null
    /// Legacy Swagger 2.0 file upload type (`"file"`).
    case file
    /// Custom or extension schema type string.
    case custom(String)

    /// All standard `SchemaType` cases.
    public static var allCases: [SchemaType] {
        return [.string, .number, .integer, .boolean, .array, .object, .null, .file]
    }

    /// Lookup table mapping canonical raw values to standard `SchemaType` cases.
    private static let byRawValue: [String: SchemaType] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the schema type.
    public var rawValue: String {
        switch self {
        case .string: return "string"
        case .number: return "number"
        case .integer: return "integer"
        case .boolean: return "boolean"
        case .array: return "array"
        case .object: return "object"
        case .null: return "null"
        case .file: return "file"
        case let .custom(val): return val
        }
    }

    /// Initializes a `SchemaType` from its raw string representation.
    ///
    /// - Parameter rawValue: The JSON Schema type string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `SchemaType` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `SchemaType` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the underlying value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `SchemaType` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Standard OpenAPI and JSON Schema data format modifiers.
public enum OpenAPIFormat: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral {
    /// Signed 32-bit integer (`"int32"`).
    case int32
    /// Signed 64-bit integer (`"int64"`).
    case int64
    /// Single-precision IEEE 754 floating-point number (`"float"`).
    case float
    /// Double-precision IEEE 754 floating-point number (`"double"`).
    case double
    /// Base64-encoded characters (`"byte"`).
    case byte
    /// Arbitrary binary octet sequence (`"binary"`).
    case binary
    /// RFC 3339 full-date (`"date"`).
    case date
    /// RFC 3339 date-time (`"date-time"`).
    case dateTime
    /// Hint to UIs to obscure input (`"password"`).
    case password
    /// RFC 4122 Universally Unique Identifier (`"uuid"`).
    case uuid
    /// RFC 3986 URI (`"uri"`).
    case uri
    /// RFC 5322 email address (`"email"`).
    case email
    /// Custom or vendor-specific format string.
    case custom(String)

    /// All standard `OpenAPIFormat` cases.
    public static var allCases: [OpenAPIFormat] {
        return [.int32, .int64, .float, .double, .byte, .binary, .date, .dateTime, .password, .uuid, .uri, .email]
    }

    /// Lookup table mapping canonical raw values to standard `OpenAPIFormat` cases.
    private static let byRawValue: [String: OpenAPIFormat] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the format.
    public var rawValue: String {
        switch self {
        case .int32: return "int32"
        case .int64: return "int64"
        case .float: return "float"
        case .double: return "double"
        case .byte: return "byte"
        case .binary: return "binary"
        case .date: return "date"
        case .dateTime: return "date-time"
        case .password: return "password"
        case .uuid: return "uuid"
        case .uri: return "uri"
        case .email: return "email"
        case let .custom(val): return val
        }
    }

    /// Initializes an `OpenAPIFormat` from its raw string representation.
    ///
    /// - Parameter rawValue: The OpenAPI format string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes an `OpenAPIFormat` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes an `OpenAPIFormat` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `OpenAPIFormat` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Locations where an OpenAPI or Swagger parameter may be transmitted in an HTTP request.
public enum ParameterLocation: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// Appended to the URL query string (`"query"`).
    case query
    /// Sent as a custom HTTP request header (`"header"`).
    case header
    /// Interpolated into the URL path template (`"path"`).
    case path
    /// Passed inside the `Cookie` HTTP header (`"cookie"`).
    case cookie
    /// Swagger 2.0 request body payload parameter (`"body"`).
    case body
    /// Swagger 2.0 URL-encoded or multipart form parameter (`"formData"`).
    case formData
    /// Custom or extension parameter location string.
    case custom(String)

    /// All standard `ParameterLocation` cases.
    public static var allCases: [ParameterLocation] {
        return [.query, .header, .path, .cookie, .body, .formData]
    }

    /// Lookup table mapping canonical raw values to standard `ParameterLocation` cases.
    private static let byRawValue: [String: ParameterLocation] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the parameter location.
    public var rawValue: String {
        switch self {
        case .query: return "query"
        case .header: return "header"
        case .path: return "path"
        case .cookie: return "cookie"
        case .body: return "body"
        case .formData: return "formData"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes a `ParameterLocation` from its raw string representation.
    ///
    /// - Parameter rawValue: The location string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `ParameterLocation` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `ParameterLocation` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `ParameterLocation` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Serialization styles defining how OpenAPI parameter values are delimited and formatted.
public enum ParameterStyle: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// Semicolon-prefixed path parameters (`"matrix"`).
    case matrix
    /// Dot-prefixed path parameters (`"label"`).
    case label
    /// Ampersand-separated query or form parameters (`"form"`).
    case form
    /// Comma-separated path or header values (`"simple"`).
    case simple
    /// Space-separated array or object values (`"spaceDelimited"`).
    case spaceDelimited
    /// Pipe-separated array or object values (`"pipeDelimited"`).
    case pipeDelimited
    /// Bracketed nested object query parameters (`"deepObject"`).
    case deepObject
    /// Custom or extension serialization style string.
    case custom(String)

    /// All standard `ParameterStyle` cases.
    public static var allCases: [ParameterStyle] {
        return [.matrix, .label, .form, .simple, .spaceDelimited, .pipeDelimited, .deepObject]
    }

    /// Lookup table mapping canonical raw values to standard `ParameterStyle` cases.
    private static let byRawValue: [String: ParameterStyle] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the parameter style.
    public var rawValue: String {
        switch self {
        case .matrix: return "matrix"
        case .label: return "label"
        case .form: return "form"
        case .simple: return "simple"
        case .spaceDelimited: return "spaceDelimited"
        case .pipeDelimited: return "pipeDelimited"
        case .deepObject: return "deepObject"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes a `ParameterStyle` from its raw string representation.
    ///
    /// - Parameter rawValue: The serialization style string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `ParameterStyle` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `ParameterStyle` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `ParameterStyle` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Strongly-typed HTTP status code or wildcard range key used in OpenAPI `responses` maps.
public enum HTTPStatusCode: RawRepresentable, Codable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral, CustomStringConvertible {
    /// Explicit numeric HTTP status code (e.g. `200`, `404`).
    case status(Int)
    /// Wildcard status code class range (`1` for `"1XX"`, `2` for `"2XX"`, etc.).
    case range(Int)
    /// Default catch-all response key (`"default"`).
    case `default`
    /// Custom status code string key.
    case custom(String)

    /// The canonical OpenAPI string key for this status code.
    public var rawValue: String {
        switch self {
        case let .status(code): return String(code)
        case let .range(cls): return "\(cls)XX"
        case .default: return "default"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes an `HTTPStatusCode` from its raw string representation.
    ///
    /// - Parameter rawValue: The OpenAPI response status key (e.g. `"200"`, `"2XX"`, `"default"`).
    public init(rawValue: String) {
        if rawValue == "default" {
            self = .default
        } else if rawValue.count == 3, rawValue.uppercased().hasSuffix("XX"), let cls = Int(rawValue.prefix(1)), (1 ... 5).contains(cls) {
            self = .range(cls)
        } else if let code = Int(rawValue), (100 ... 599).contains(code) {
            self = .status(code)
        } else {
            self = .custom(rawValue)
        }
    }

    /// Initializes an `HTTPStatusCode` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Initializes an `HTTPStatusCode` from an integer literal.
    ///
    /// - Parameter value: The numeric HTTP status code.
    public init(integerLiteral value: Int) {
        self = .status(value)
    }

    /// Decodes an `HTTPStatusCode` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string or integer.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .status(intVal)
        } else {
            let raw = try container.decode(String.self)
            self.init(rawValue: raw)
        }
    }

    /// Encodes this `HTTPStatusCode` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
