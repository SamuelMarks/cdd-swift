/// OpenAPI 3.2.0 and Swagger 2.0 header, tag, reference, security scheme, and OAuth 2.0 flow models.
import Foundation

// MARK: - Header Object

/// Describes an HTTP header returned in a response or part of a multipart encoding.
public struct Header: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable header component.
    public let ref: String?
    /// Optional short summary of the header.
    public let summary: String?
    /// Brief description of the header.
    public let description: String?
    /// Determines whether this header is mandatory.
    public let required: Bool?
    /// Specifies that a header is deprecated.
    public let deprecated: Bool?
    /// Sets the ability to pass empty-valued headers.
    public let allowEmptyValue: Bool?
    /// Describes how the header value will be serialized.
    public let style: ParameterStyle?
    /// When `true`, header values of type `"array"` or `"object"` generate separate parameters.
    public let explode: Bool?
    /// Determines whether the header value SHOULD allow reserved characters.
    public let allowReserved: Bool?
    /// Schema defining the type used for the header.
    public let schema: Schema?
    /// Example of the header's potential value.
    public let example: AnyCodable?
    /// Map of examples of the header's potential value.
    public let examples: [String: Example]?
    /// Map containing the representations for the header.
    public let content: [String: MediaType]?

    /// Coding keys mapping OpenAPI JSON properties to `Header` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
        /// Key for `required`.
        case required
        /// Key for `deprecated`.
        case deprecated
        /// Key for `allowEmptyValue`.
        case allowEmptyValue
        /// Key for `style`.
        case style
        /// Key for `explode`.
        case explode
        /// Key for `allowReserved`.
        case allowReserved
        /// Key for `schema`.
        case schema
        /// Key for `example`.
        case example
        /// Key for `examples`.
        case examples
        /// Key for `content`.
        case content
    }

    /// Initializes a `Header`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - description: Optional header description.
    ///   - required: Optional required flag.
    ///   - deprecated: Optional deprecation flag.
    ///   - allowEmptyValue: Optional empty value flag.
    ///   - style: Optional serialization style.
    ///   - explode: Optional explode flag.
    ///   - allowReserved: Optional reserved character flag.
    ///   - schema: Optional header `Schema`.
    ///   - example: Optional single example value.
    ///   - examples: Optional map of named `Example` objects.
    ///   - content: Optional map of MIME types to `MediaType` descriptors.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        required: Bool? = nil,
        deprecated: Bool? = nil,
        allowEmptyValue: Bool? = nil,
        style: ParameterStyle? = nil,
        explode: Bool? = nil,
        allowReserved: Bool? = nil,
        schema: Schema? = nil,
        example: AnyCodable? = nil,
        examples: [String: Example]? = nil,
        content: [String: MediaType]? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.required = required
        self.deprecated = deprecated
        self.allowEmptyValue = allowEmptyValue
        self.style = style
        self.explode = explode
        self.allowReserved = allowReserved
        self.schema = schema
        self.example = example
        self.examples = examples
        self.content = content
    }
}

// MARK: - Tag Object

/// Adds metadata to a single tag that is used by the `Operation` Object.
public struct Tag: Codable, Equatable, Sendable {
    /// Name of the tag.
    public let name: String
    /// Short description for the tag.
    public let description: String?
    /// Short summary of the tag (OpenAPI 3.2.0).
    public let summary: String?
    /// Name of a parent tag for hierarchical tag organization (OpenAPI 3.2.0).
    public let parent: String?
    /// Classification kind of the tag (OpenAPI 3.2.0).
    public let kind: String?
    /// Additional external documentation for this tag.
    public let externalDocs: ExternalDocumentation?

    /// Initializes a `Tag`.
    ///
    /// - Parameters:
    ///   - name: Required tag name.
    ///   - description: Optional tag description.
    ///   - summary: Optional short summary.
    ///   - parent: Optional parent tag name.
    ///   - kind: Optional tag kind classification.
    ///   - externalDocs: Optional `ExternalDocumentation` reference.
    public init(
        name: String,
        description: String? = nil,
        summary: String? = nil,
        parent: String? = nil,
        kind: String? = nil,
        externalDocs: ExternalDocumentation? = nil
    ) {
        self.name = name
        self.description = description
        self.summary = summary
        self.parent = parent
        self.kind = kind
        self.externalDocs = externalDocs
    }
}

// MARK: - Reference Object

/// Simple object to allow referencing other components in the OpenAPI specification, internally and externally.
public struct Reference: Codable, Equatable, Sendable {
    /// Required reference identifier string (`$ref`).
    public let ref: String
    /// Short summary which by default SHOULD override that of the referenced component.
    public let summary: String?
    /// Description which by default SHOULD override that of the referenced component.
    public let description: String?

    /// Coding keys mapping OpenAPI JSON properties to `Reference` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
    }

    /// Initializes a `Reference` object.
    ///
    /// - Parameters:
    ///   - ref: The `$ref` URI string.
    ///   - summary: Optional summary override.
    ///   - description: Optional description override.
    public init(ref: String, summary: String? = nil, description: String? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
    }
}

// MARK: - Security Scheme Object

/// Authentication scheme types supported by OpenAPI 3.2.0 and Swagger 2.0.
public enum SecuritySchemeType: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// API key passed in a header, query parameter, or cookie (`"apiKey"`).
    case apiKey
    /// HTTP authentication scheme such as Bearer or Basic (`"http"`).
    case http
    /// Client certificate mutual TLS authentication (`"mutualTLS"`).
    case mutualTLS
    /// OAuth 2.0 authorization flows (`"oauth2"`).
    case oauth2
    /// OpenID Connect Discovery authentication (`"openIdConnect"`).
    case openIdConnect
    /// Legacy Swagger 2.0 HTTP Basic authentication (`"basic"`).
    case basic
    /// Custom or extension security scheme type string.
    case custom(String)

    /// All standard `SecuritySchemeType` cases.
    public static var allCases: [SecuritySchemeType] {
        return [.apiKey, .http, .mutualTLS, .oauth2, .openIdConnect, .basic]
    }

    /// Lookup table mapping canonical raw values to standard `SecuritySchemeType` cases.
    private static let byRawValue: [String: SecuritySchemeType] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the security scheme type.
    public var rawValue: String {
        switch self {
        case .apiKey: return "apiKey"
        case .http: return "http"
        case .mutualTLS: return "mutualTLS"
        case .oauth2: return "oauth2"
        case .openIdConnect: return "openIdConnect"
        case .basic: return "basic"
        case let .custom(val): return val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        return rawValue
    }

    /// Initializes a `SecuritySchemeType` from its raw string representation.
    ///
    /// - Parameter rawValue: The security scheme type string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `SecuritySchemeType` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `SecuritySchemeType` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `SecuritySchemeType` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Defines a security scheme that can be used by the operations.
public struct SecurityScheme: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable security scheme component.
    public let ref: String?
    /// Optional short summary of the security scheme.
    public let summary: String?
    /// Type of the security scheme (`"apiKey"`, `"http"`, `"mutualTLS"`, `"oauth2"`, `"openIdConnect"`).
    public let type: SecuritySchemeType?
    /// Short description for security scheme.
    public let description: String?
    /// Name of the header, query, or cookie parameter to be used when `type` is `"apiKey"`.
    public let name: String?
    /// Location of the API key (`"query"`, `"header"`, or `"cookie"`).
    public let `in`: ParameterLocation?
    /// Name of the HTTP Authorization scheme to be used in the Authorization header as defined in RFC7235.
    public let scheme: String?
    /// Hint to the client to identify how the bearer token is formatted (e.g. `"JWT"`).
    public let bearerFormat: String?
    /// Configuration information for the flow types supported for `"oauth2"`.
    public let flows: OAuthFlows?
    /// OpenID Connect URL to discover OAuth2 configuration values.
    public let openIdConnectUrl: String?
    /// OAuth 2.0 Authorization Server Metadata URL (OpenAPI 3.2.0).
    public let oauth2MetadataUrl: String?
    /// Specifies that the security scheme is deprecated (OpenAPI 3.2.0).
    public let deprecated: Bool?

    /// Strongly-typed security scheme type enum derived from `type`.
    public var schemeType: SecuritySchemeType? {
        return type
    }

    /// Strongly-typed API key parameter location derived from `in`.
    public var keyLocation: ParameterLocation? {
        return self.in
    }

    /// Coding keys mapping OpenAPI JSON properties to `SecurityScheme` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `type`.
        case type
        /// Key for `description`.
        case description
        /// Key for `name`.
        case name
        /// Key for `in`.
        case `in`
        /// Key for `scheme`.
        case scheme
        /// Key for `bearerFormat`.
        case bearerFormat
        /// Key for `flows`.
        case flows
        /// Key for `openIdConnectUrl`.
        case openIdConnectUrl
        /// Key for `oauth2MetadataUrl`.
        case oauth2MetadataUrl
        /// Key for `deprecated`.
        case deprecated
    }

    /// Initializes a `SecurityScheme`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - type: Optional security scheme type.
    ///   - description: Optional description string.
    ///   - name: Optional header/query/cookie parameter name.
    ///   - location: Optional API key location (`"header"`, `"query"`, `"cookie"`).
    ///   - scheme: Optional HTTP auth scheme name (`"bearer"`, `"basic"`).
    ///   - bearerFormat: Optional bearer token format hint.
    ///   - flows: Optional `OAuthFlows` configuration.
    ///   - openIdConnectUrl: Optional OpenID Connect discovery URL.
    ///   - oauth2MetadataUrl: Optional OAuth 2.0 metadata URL.
    ///   - deprecated: Optional deprecation flag.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        type: SecuritySchemeType? = nil,
        description: String? = nil,
        name: String? = nil,
        in location: ParameterLocation? = nil,
        scheme: String? = nil,
        bearerFormat: String? = nil,
        flows: OAuthFlows? = nil,
        openIdConnectUrl: String? = nil,
        oauth2MetadataUrl: String? = nil,
        deprecated: Bool? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.type = type
        self.description = description
        self.name = name
        self.in = location
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.flows = flows
        self.openIdConnectUrl = openIdConnectUrl
        self.oauth2MetadataUrl = oauth2MetadataUrl
        self.deprecated = deprecated
    }
}

// MARK: - OAuth Flows Object

/// Allows configuration of the supported OAuth Flows.
public struct OAuthFlows: Codable, Equatable, Sendable {
    /// Configuration for the OAuth Implicit flow.
    public let implicit: OAuthFlow?
    /// Configuration for the OAuth Resource Owner Password flow.
    public let password: OAuthFlow?
    /// Configuration for the OAuth Client Credentials flow.
    public let clientCredentials: OAuthFlow?
    /// Configuration for the OAuth Authorization Code flow.
    public let authorizationCode: OAuthFlow?
    /// Configuration for the OAuth 2.0 Device Authorization flow (OpenAPI 3.2.0).
    public let deviceAuthorization: OAuthFlow?

    /// Initializes `OAuthFlows`.
    ///
    /// - Parameters:
    ///   - implicit: Optional Implicit flow configuration.
    ///   - password: Optional Resource Owner Password flow configuration.
    ///   - clientCredentials: Optional Client Credentials flow configuration.
    ///   - authorizationCode: Optional Authorization Code flow configuration.
    ///   - deviceAuthorization: Optional Device Authorization flow configuration.
    public init(
        implicit: OAuthFlow? = nil,
        password: OAuthFlow? = nil,
        clientCredentials: OAuthFlow? = nil,
        authorizationCode: OAuthFlow? = nil,
        deviceAuthorization: OAuthFlow? = nil
    ) {
        self.implicit = implicit
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
        self.deviceAuthorization = deviceAuthorization
    }
}

// MARK: - OAuth Flow Object

/// Configuration details for a supported OAuth Flow.
public struct OAuthFlow: Codable, Equatable, Sendable {
    /// Authorization URL to be used for this flow.
    public let authorizationUrl: String?
    /// Token URL to be used for this flow.
    public let tokenUrl: String?
    /// URL to be used for obtaining refresh tokens.
    public let refreshUrl: String?
    /// Device authorization URL to be used for device flow (OpenAPI 3.2.0).
    public let deviceAuthorizationUrl: String?
    /// Available scopes for the OAuth2 security scheme mapping scope names to descriptions.
    public let scopes: [String: String]?

    /// Initializes an `OAuthFlow`.
    ///
    /// - Parameters:
    ///   - authorizationUrl: Optional authorization endpoint URL.
    ///   - tokenUrl: Optional token endpoint URL.
    ///   - refreshUrl: Optional token refresh URL.
    ///   - deviceAuthorizationUrl: Optional device authorization URL.
    ///   - scopes: Optional map of scope names to human-readable descriptions.
    public init(
        authorizationUrl: String? = nil,
        tokenUrl: String? = nil,
        refreshUrl: String? = nil,
        deviceAuthorizationUrl: String? = nil,
        scopes: [String: String]? = nil
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.scopes = scopes
    }
}
