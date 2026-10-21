/// OpenAPI 3.2.0 and Swagger 2.0 example, link, discriminator, XML, and schema item metadata models.
import Foundation

// MARK: - Example Object

/// Represents an example value for an operation parameter, request body, or response media type.
public struct Example: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable example component.
    public let ref: String?
    /// Short description for the example.
    public let summary: String?
    /// Long description for the example.
    public let description: String?
    /// Structured data example value (OpenAPI 3.2.0).
    public let dataValue: AnyCodable?
    /// Serialized wire-format representation of the example (OpenAPI 3.2.0).
    public let serializedValue: String?
    /// Embedded literal example value.
    public let value: AnyCodable?
    /// URI that points to the literal example.
    public let externalValue: String?

    /// Coding keys mapping OpenAPI JSON properties to `Example` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
        /// Key for `dataValue`.
        case dataValue
        /// Key for `serializedValue`.
        case serializedValue
        /// Key for `value`.
        case value
        /// Key for `externalValue`.
        case externalValue
    }

    /// Initializes an `Example`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional short summary.
    ///   - description: Optional detailed description.
    ///   - dataValue: Optional structured data value.
    ///   - serializedValue: Optional pre-serialized string value.
    ///   - value: Optional literal example value.
    ///   - externalValue: Optional external URI string.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        dataValue: AnyCodable? = nil,
        serializedValue: String? = nil,
        value: AnyCodable? = nil,
        externalValue: String? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.dataValue = dataValue
        self.serializedValue = serializedValue
        self.value = value
        self.externalValue = externalValue
    }
}

// MARK: - Link Object

/// Represents a possible design-time link for a response.
public struct Link: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable link component.
    public let ref: String?
    /// Optional short summary of the link.
    public let summary: String?
    /// Relative or absolute URI reference to an OAS operation.
    public let operationRef: String?
    /// Name of an existing, resolvable OAS operation, as defined with a unique `operationId`.
    public let operationId: String?
    /// Map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`.
    public let parameters: [String: AnyCodable]?
    /// Literal value or `{expression}` to use as a request body when calling the target operation.
    public let requestBody: AnyCodable?
    /// Description of the link.
    public let description: String?
    /// Server object to be used by the target operation.
    public let server: Server?

    /// Coding keys mapping OpenAPI JSON properties to `Link` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `operationRef`.
        case operationRef
        /// Key for `operationId`.
        case operationId
        /// Key for `parameters`.
        case parameters
        /// Key for `requestBody`.
        case requestBody
        /// Key for `description`.
        case description
        /// Key for `server`.
        case server
    }

    /// Initializes a `Link`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - operationRef: Optional URI reference to an operation.
    ///   - operationId: Optional target `operationId`.
    ///   - parameters: Optional parameter expressions map.
    ///   - requestBody: Optional request body expression or literal.
    ///   - description: Optional link description.
    ///   - server: Optional target `Server` override.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        operationRef: String? = nil,
        operationId: String? = nil,
        parameters: [String: AnyCodable]? = nil,
        requestBody: AnyCodable? = nil,
        description: String? = nil,
        server: Server? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.operationRef = operationRef
        self.operationId = operationId
        self.parameters = parameters
        self.requestBody = requestBody
        self.description = description
        self.server = server
    }
}

// MARK: - Discriminator Object

/// Aids in serialization, deserialization, and validation of polymorphic `oneOf` / `anyOf` / `allOf` schemas.
public struct Discriminator: Codable, Equatable, Sendable {
    /// Name of the property in the payload that will hold the discriminating value.
    public let propertyName: String
    /// Map between payload property values and schema references or names.
    public let mapping: [String: String]?
    /// Default schema reference when the discriminating property is absent or unmapped (OpenAPI 3.2.0).
    public let defaultMapping: String?

    /// Initializes a `Discriminator`.
    ///
    /// - Parameters:
    ///   - propertyName: The discriminating payload field name.
    ///   - mapping: Optional map of discriminator values to schema references.
    ///   - defaultMapping: Optional fallback schema reference.
    public init(propertyName: String, mapping: [String: String]? = nil, defaultMapping: String? = nil) {
        self.propertyName = propertyName
        self.mapping = mapping
        self.defaultMapping = defaultMapping
    }
}

// MARK: - XML Object

/// Node type classification for XML serialization in OpenAPI 3.2.0.
public enum XMLNodeType: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// Serialized as an XML attribute (`"attribute"`).
    case attribute
    /// Serialized as an XML element (`"element"`).
    case element
    /// Serialized as XML text content (`"text"`).
    case text
    /// Serialized as a CDATA section (`"cdata"`).
    case cdata
    /// Omitted from XML wrapper element (`"none"`).
    case none
    /// Custom or extension XML node type string.
    case custom(String)

    /// All standard `XMLNodeType` cases.
    public static var allCases: [XMLNodeType] {
        return [.attribute, .element, .text, .cdata, .none]
    }

    /// Lookup table mapping canonical raw values to standard `XMLNodeType` cases.
    private static let byRawValue: [String: XMLNodeType] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the XML node type.
    public var rawValue: String {
        switch self {
        case .attribute: return "attribute"
        case .element: return "element"
        case .text: return "text"
        case .cdata: return "cdata"
        case .none: return "none"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes an `XMLNodeType` from its raw string representation.
    ///
    /// - Parameter rawValue: The XML node type string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes an `XMLNodeType` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes an `XMLNodeType` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `XMLNodeType` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Metadata object that allows for more fine-tuned XML model definitions.
public struct XML: Codable, Equatable, Sendable {
    /// Replaces the name of the element/attribute used for the described schema property.
    public let name: String?
    /// URI of the namespace definition.
    public let namespace: String?
    /// Prefix to be used for the `name`.
    public let prefix: String?
    /// Declares whether the property definition translates to an XML attribute instead of an element.
    public let attribute: Bool?
    /// Signifies whether the array is wrapped (e.g. `<books><book/></books>`).
    public let wrapped: Bool?
    /// XML node type classification (`"element"`, `"attribute"`, `"text"`, `"cdata"`, `"none"`, OpenAPI 3.2.0).
    public let nodeType: XMLNodeType?

    /// Initializes an `XML` metadata descriptor.
    ///
    /// - Parameters:
    ///   - name: Optional XML element or attribute name override.
    ///   - namespace: Optional XML namespace URI.
    ///   - prefix: Optional XML namespace prefix.
    ///   - attribute: Optional flag indicating attribute serialization.
    ///   - wrapped: Optional flag indicating wrapped array serialization.
    ///   - nodeType: Optional OpenAPI 3.2.0 XML node type.
    public init(
        name: String? = nil,
        namespace: String? = nil,
        prefix: String? = nil,
        attribute: Bool? = nil,
        wrapped: Bool? = nil,
        nodeType: XMLNodeType? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.prefix = prefix
        self.attribute = attribute
        self.wrapped = wrapped
        self.nodeType = nodeType
    }
}

// MARK: - Schema Item Object

/// Lightweight schema reference or primitive type descriptor used in recursive `Schema` positions (`items`, `additionalProperties`, `not`,
/// etc.).
public struct SchemaItem: Codable, Equatable, Sendable {
    /// Primitive JSON Schema type name (e.g. `"string"`, `"integer"`).
    public let type: String?
    /// `$ref` pointer to a reusable schema component.
    public let ref: String?
    /// Optional format modifier (e.g. `"int32"`, `"int64"`, `"date-time"`, `"uuid"`).
    public let format: String?

    /// Strongly-typed `SchemaType` enum derived from `type`.
    public var schemaType: SchemaType? {
        guard let t = type else { return nil }
        return SchemaType(rawValue: t)
    }

    /// Strongly-typed `OpenAPIFormat` enum derived from `format`.
    public var openAPIFormat: OpenAPIFormat? {
        guard let f = format else { return nil }
        return OpenAPIFormat(rawValue: f)
    }

    /// Coding keys mapping OpenAPI JSON properties to `SchemaItem` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `type`.
        case type
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `format`.
        case format
    }

    /// Initializes a `SchemaItem`.
    ///
    /// - Parameters:
    ///   - type: Optional JSON Schema type string.
    ///   - ref: Optional `$ref` pointer string.
    ///   - format: Optional format string.
    public init(type: String? = nil, ref: String? = nil, format: String? = nil) {
        self.type = type
        self.ref = ref
        self.format = format
    }
}

/// Standard MIME content types used across OpenAPI media type maps.
public enum ContentType: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// JSON payload (`"application/json"`).
    case applicationJson
    /// Multipart form data payload (`"multipart/form-data"`).
    case multipartFormData
    /// URL-encoded form payload (`"application/x-www-form-urlencoded"`).
    case formUrlEncoded
    /// Raw binary stream (`"application/octet-stream"`).
    case octetStream
    /// Plain UTF-8 text (`"text/plain"`).
    case textPlain
    /// Custom or vendor MIME media type string.
    case custom(String)

    /// All standard `ContentType` cases.
    public static var allCases: [ContentType] {
        return [.applicationJson, .multipartFormData, .formUrlEncoded, .octetStream, .textPlain]
    }

    /// Lookup table mapping canonical raw values to standard `ContentType` cases.
    private static let byRawValue: [String: ContentType] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The canonical MIME media type string.
    public var rawValue: String {
        switch self {
        case .applicationJson: return "application/json"
        case .multipartFormData: return "multipart/form-data"
        case .formUrlEncoded: return "application/x-www-form-urlencoded"
        case .octetStream: return "application/octet-stream"
        case .textPlain: return "text/plain"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes a `ContentType` from its raw MIME string.
    ///
    /// - Parameter rawValue: The MIME media type string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `ContentType` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `ContentType` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `ContentType` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Standard HTTP request methods supported by OpenAPI 3.2.0 `PathItem` definitions.
public enum HTTPMethod: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// HTTP `GET` method.
    case get
    /// HTTP `PUT` method.
    case put
    /// HTTP `POST` method.
    case post
    /// HTTP `DELETE` method.
    case delete
    /// HTTP `OPTIONS` method.
    case options
    /// HTTP `HEAD` method.
    case head
    /// HTTP `PATCH` method.
    case patch
    /// HTTP `TRACE` method.
    case trace
    /// HTTP `QUERY` method introduced in OpenAPI 3.2.0.
    case query
}
