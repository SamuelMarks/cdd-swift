/// OpenAPI 3.2.0 and Swagger 2.0 operation, parameter, request/response, header, tag, and security models.
import Foundation

// MARK: - Operation Object

/// Describes a single API operation on a path.
public struct Operation: Codable, Equatable, Sendable {
    /// List of tags for API documentation control and logical grouping.
    public let tags: [String]?
    /// Short summary of what the operation does.
    public let summary: String?
    /// Verbose explanation of the operation behavior.
    public let description: String?
    /// Additional external documentation for this operation.
    public let externalDocs: ExternalDocumentation?
    /// Unique string used to identify the operation across the API.
    public let operationId: String?
    /// List of parameters that are applicable for this operation.
    public let parameters: [Parameter]?
    /// Request body applicable for this operation.
    public let requestBody: RequestBody?
    /// Map of expected HTTP status code responses for this operation.
    public let responses: [String: Response]?
    /// Map of possible out-of-band callbacks related to the parent operation.
    public let callbacks: [String: Callback]?
    /// Declares this operation to be deprecated.
    public let deprecated: Bool?
    /// Declaration of which security mechanisms can be used for this operation.
    public let security: [SecurityRequirement]?
    /// Alternative `Server` array to service this operation.
    public let servers: [Server]?

    /// Initializes an `Operation`.
    ///
    /// - Parameters:
    ///   - tags: Optional list of grouping tags.
    ///   - summary: Optional short summary.
    ///   - description: Optional detailed description.
    ///   - externalDocs: Optional external documentation link.
    ///   - operationId: Optional unique operation identifier.
    ///   - parameters: Optional list of operation parameters.
    ///   - requestBody: Optional request body specification.
    ///   - responses: Optional map of HTTP status codes to `Response` definitions.
    ///   - callbacks: Optional map of callback definitions.
    ///   - deprecated: Optional deprecation flag.
    ///   - security: Optional operation-specific security requirements.
    ///   - servers: Optional operation-specific server overrides.
    public init(
        tags: [String]? = nil,
        summary: String? = nil,
        description: String? = nil,
        externalDocs: ExternalDocumentation? = nil,
        operationId: String? = nil,
        parameters: [Parameter]? = nil,
        requestBody: RequestBody? = nil,
        responses: [String: Response]? = nil,
        callbacks: [String: Callback]? = nil,
        deprecated: Bool? = nil,
        security: [SecurityRequirement]? = nil,
        servers: [Server]? = nil
    ) {
        self.tags = tags
        self.summary = summary
        self.description = description
        self.externalDocs = externalDocs
        self.operationId = operationId
        self.parameters = parameters
        self.requestBody = requestBody
        self.responses = responses
        self.callbacks = callbacks
        self.deprecated = deprecated
        self.security = security
        self.servers = servers
    }
}

// MARK: - External Documentation Object

/// Allows referencing an external resource for extended documentation.
public struct ExternalDocumentation: Codable, Equatable, Sendable {
    /// Short description of the target documentation.
    public let description: String?
    /// Target URL for the external documentation.
    public let url: String

    /// Initializes an `ExternalDocumentation` reference.
    ///
    /// - Parameters:
    ///   - description: Optional description of the external resource.
    ///   - url: Required URL pointing to the external documentation.
    public init(description: String? = nil, url: String) {
        self.description = description
        self.url = url
    }
}

// MARK: - Parameter Object

/// Describes a single operation parameter in `query`, `header`, `path`, `cookie`, or Swagger 2.0 `formData`/`body`.
public struct Parameter: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable parameter component.
    public let ref: String?
    /// Optional short summary of the referenced parameter.
    public let summary: String?
    /// Name of the parameter.
    public let name: String?
    /// Location of the parameter (`"query"`, `"header"`, `"path"`, `"cookie"`, `"formData"`, `"body"`).
    public let `in`: String?
    /// Brief description of the parameter.
    public let description: String?
    /// Determines whether this parameter is mandatory.
    public let required: Bool?
    /// Specifies that a parameter is deprecated and should be transitioned out of usage.
    public let deprecated: Bool?
    /// Sets the ability to pass empty-valued parameters.
    public let allowEmptyValue: Bool?
    /// Describes how the parameter value will be serialized (`"matrix"`, `"label"`, `"form"`, `"simple"`, `"spaceDelimited"`, `"pipeDelimited"`, `"deepObject"`).
    public let style: String?
    /// When `true`, parameter values of type `"array"` or `"object"` generate separate parameters for each value.
    public let explode: Bool?
    /// Determines whether the parameter value SHOULD allow reserved characters (`:/?#[]@!$&'()*+,;=`).
    public let allowReserved: Bool?
    /// Schema defining the type used for the parameter.
    public let schema: Schema?
    /// Example of the parameter's potential value.
    public let example: AnyCodable?
    /// Map of examples of the parameter's potential value.
    public let examples: [String: Example]?
    /// Map containing the representations for the parameter keyed by media type.
    public let content: [String: MediaType]?

    /// Strongly-typed parameter location enum derived from `in`.
    public var location: ParameterLocation? {
        guard let loc = self.in else { return nil }
        return ParameterLocation(rawValue: loc)
    }

    /// Strongly-typed parameter serialization style enum derived from `style`.
    public var parameterStyle: ParameterStyle? {
        guard let st = style else { return nil }
        return ParameterStyle(rawValue: st)
    }

    /// Coding keys mapping OpenAPI JSON properties to `Parameter` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `name`.
        case name
        /// Key for `in`.
        case `in`
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

    /// Initializes a `Parameter`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - name: Optional parameter name.
    ///   - location: Optional parameter location (`"query"`, `"path"`, `"header"`, `"cookie"`).
    ///   - description: Optional parameter description.
    ///   - required: Optional required flag.
    ///   - deprecated: Optional deprecation flag.
    ///   - allowEmptyValue: Optional flag allowing empty query values.
    ///   - style: Optional serialization style string.
    ///   - explode: Optional explode flag.
    ///   - allowReserved: Optional flag allowing RFC 3986 reserved characters.
    ///   - schema: Optional parameter `Schema`.
    ///   - example: Optional single example value.
    ///   - examples: Optional map of named `Example` objects.
    ///   - content: Optional map of media types to `MediaType` definitions.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        name: String? = nil,
        in location: String? = nil,
        description: String? = nil,
        required: Bool? = nil,
        deprecated: Bool? = nil,
        allowEmptyValue: Bool? = nil,
        style: String? = nil,
        explode: Bool? = nil,
        allowReserved: Bool? = nil,
        schema: Schema? = nil,
        example: AnyCodable? = nil,
        examples: [String: Example]? = nil,
        content: [String: MediaType]? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.name = name
        self.in = location
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

// MARK: - Request Body Object

/// Describes a single HTTP request body payload.
public struct RequestBody: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable request body component.
    public let ref: String?
    /// Optional short summary of the referenced request body.
    public let summary: String?
    /// Brief description of the request body.
    public let description: String?
    /// Content descriptors of the request body keyed by media type (e.g. `"application/json"`).
    public let content: [String: MediaType]?
    /// Determines if the request body is required in the request.
    public let required: Bool?

    /// Coding keys mapping OpenAPI JSON properties to `RequestBody` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
        /// Key for `content`.
        case content
        /// Key for `required`.
        case required
    }

    /// Initializes a `RequestBody`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - description: Optional request body description.
    ///   - content: Optional map of MIME types to `MediaType` descriptors.
    ///   - required: Optional flag indicating whether the body is mandatory.
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, content: [String: MediaType]? = nil, required: Bool? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.content = content
        self.required = required
    }
}

// MARK: - Media Type Object

/// Provides schema, example, and encoding semantics for a specific MIME media type.
public struct MediaType: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable media type component (OpenAPI 3.2.0).
    public let ref: String?
    /// Optional short summary of the media type.
    public let summary: String?
    /// Schema defining the complete content of the request, response, or parameter.
    public let schema: Schema?
    /// Schema defining individual items within a streaming or sequential media type (OpenAPI 3.2.0).
    public let itemSchema: Schema?
    /// Example of the media type's potential value.
    public let example: AnyCodable?
    /// Map of examples of the media type's potential value.
    public let examples: [String: Example]?
    /// Map between a property name and its encoding information.
    public let encoding: [String: EncodingObject]?
    /// Positional array of encoding objects for `multipart` prefix items (OpenAPI 3.2.0).
    public let prefixEncoding: [EncodingObject]?
    /// Encoding object applied to streaming/array items (OpenAPI 3.2.0).
    public let itemEncoding: EncodingObject?

    /// Coding keys mapping OpenAPI JSON properties to `MediaType` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `schema`.
        case schema
        /// Key for `itemSchema`.
        case itemSchema
        /// Key for `example`.
        case example
        /// Key for `examples`.
        case examples
        /// Key for `encoding`.
        case encoding
        /// Key for `prefixEncoding`.
        case prefixEncoding
        /// Key for `itemEncoding`.
        case itemEncoding
    }

    /// Initializes a `MediaType`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - schema: Optional `Schema` describing the payload.
    ///   - itemSchema: Optional `Schema` describing streaming items.
    ///   - example: Optional single example payload.
    ///   - examples: Optional map of named `Example` objects.
    ///   - encoding: Optional map of property names to `EncodingObject` descriptors.
    ///   - prefixEncoding: Optional positional array of `EncodingObject` descriptors.
    ///   - itemEncoding: Optional item `EncodingObject` descriptor.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        schema: Schema? = nil,
        itemSchema: Schema? = nil,
        example: AnyCodable? = nil,
        examples: [String: Example]? = nil,
        encoding: [String: EncodingObject]? = nil,
        prefixEncoding: [EncodingObject]? = nil,
        itemEncoding: EncodingObject? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.schema = schema
        self.itemSchema = itemSchema
        self.example = example
        self.examples = examples
        self.encoding = encoding
        self.prefixEncoding = prefixEncoding
        self.itemEncoding = itemEncoding
    }
}

// MARK: - Encoding Object

/// Single encoding definition applied to a single schema property or multipart part.
public final class EncodingObject: Codable, Equatable, Sendable {
    /// Content-Type for encoding a specific property (e.g. `"application/json"`, `"image/png"`).
    public let contentType: String?
    /// Map allowing additional information to be provided as headers.
    public let headers: [String: Header]?
    /// Nested property encoding map for structured multipart payloads (OpenAPI 3.2.0).
    public let encoding: [String: EncodingObject]?
    /// Positional encoding array for tuple/prefix multipart items (OpenAPI 3.2.0).
    public let prefixEncoding: [EncodingObject]?
    /// Encoding rules for array/stream items in multipart payloads (OpenAPI 3.2.0).
    public let itemEncoding: EncodingObject?
    /// Describes how a specific property value will be serialized depending on its type.
    public let style: String?
    /// When `true`, property values of type `"array"` or `"object"` generate separate parameters.
    public let explode: Bool?
    /// Determines whether the parameter value SHOULD allow reserved characters.
    public let allowReserved: Bool?

    /// Initializes an `EncodingObject`.
    ///
    /// - Parameters:
    ///   - contentType: Optional MIME Content-Type string.
    ///   - headers: Optional map of header names to `Header` descriptors.
    ///   - encoding: Optional nested property encoding map.
    ///   - prefixEncoding: Optional positional array of `EncodingObject` descriptors.
    ///   - itemEncoding: Optional item `EncodingObject` descriptor.
    ///   - style: Optional serialization style string.
    ///   - explode: Optional explode flag.
    ///   - allowReserved: Optional reserved character flag.
    public init(
        contentType: String? = nil,
        headers: [String: Header]? = nil,
        encoding: [String: EncodingObject]? = nil,
        prefixEncoding: [EncodingObject]? = nil,
        itemEncoding: EncodingObject? = nil,
        style: String? = nil,
        explode: Bool? = nil,
        allowReserved: Bool? = nil
    ) {
        self.contentType = contentType
        self.headers = headers
        self.encoding = encoding
        self.prefixEncoding = prefixEncoding
        self.itemEncoding = itemEncoding
        self.style = style
        self.explode = explode
        self.allowReserved = allowReserved
    }

    /// Compares two `EncodingObject` instances for structural equality.
    ///
    /// - Parameters:
    ///   - lhs: Left-hand side `EncodingObject`.
    ///   - rhs: Right-hand side `EncodingObject`.
    /// - Returns: `true` if all properties are equal, `false` otherwise.
    public static func == (lhs: EncodingObject, rhs: EncodingObject) -> Bool {
        return lhs.contentType == rhs.contentType && lhs.headers == rhs.headers && lhs.encoding == rhs.encoding && lhs.prefixEncoding == rhs.prefixEncoding && lhs.itemEncoding == rhs.itemEncoding && lhs.style == rhs.style && lhs.explode == rhs.explode && lhs.allowReserved == rhs.allowReserved
    }
}

// MARK: - Response Object

/// Describes a single response from an API Operation.
public struct Response: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable response component.
    public let ref: String?
    /// Optional short summary of the response.
    public let summary: String?
    /// Description of the response.
    public let description: String?
    /// Maps a header name to its definition.
    public let headers: [String: Header]?
    /// Map containing descriptions of potential response payloads keyed by media type.
    public let content: [String: MediaType]?
    /// Map of operations links that can be followed from the response.
    public let links: [String: Link]?

    /// Coding keys mapping OpenAPI JSON properties to `Response` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
        /// Key for `headers`.
        case headers
        /// Key for `content`.
        case content
        /// Key for `links`.
        case links
    }

    /// Initializes a `Response`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional summary string.
    ///   - description: Optional response description.
    ///   - headers: Optional map of response headers.
    ///   - content: Optional map of MIME types to `MediaType` payloads.
    ///   - links: Optional map of follow-up operation `Link` objects.
    public init(
        ref: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        headers: [String: Header]? = nil,
        content: [String: MediaType]? = nil,
        links: [String: Link]? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.headers = headers
        self.content = content
        self.links = links
    }
}

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
    public let style: String?
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
    ///   - style: Optional serialization style string.
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
        style: String? = nil,
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
    public init(name: String, description: String? = nil, summary: String? = nil, parent: String? = nil, kind: String? = nil, externalDocs: ExternalDocumentation? = nil) {
        self.name = name
        self.description = description
        self.summary = summary
        self.parent = parent
        self.kind = kind
        self.externalDocs = externalDocs
    }
}

// MARK: - Security Scheme Object

/// Defines a security scheme that can be used by the operations.
public struct SecurityScheme: Codable, Equatable, Sendable {
    /// Optional `$ref` pointer to a reusable security scheme component.
    public let ref: String?
    /// Optional short summary of the security scheme.
    public let summary: String?
    /// Type of the security scheme (`"apiKey"`, `"http"`, `"mutualTLS"`, `"oauth2"`, `"openIdConnect"`).
    public let type: String?
    /// Short description for security scheme.
    public let description: String?
    /// Name of the header, query, or cookie parameter to be used when `type` is `"apiKey"`.
    public let name: String?
    /// Location of the API key (`"query"`, `"header"`, or `"cookie"`).
    public let `in`: String?
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
        guard let t = type else { return nil }
        return SecuritySchemeType(rawValue: t)
    }

    /// Strongly-typed API key parameter location derived from `in`.
    public var keyLocation: ParameterLocation? {
        guard let loc = self.in else { return nil }
        return ParameterLocation(rawValue: loc)
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
    ///   - type: Optional security scheme type string.
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
        type: String? = nil,
        description: String? = nil,
        name: String? = nil,
        in location: String? = nil,
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
    public init(implicit: OAuthFlow? = nil, password: OAuthFlow? = nil, clientCredentials: OAuthFlow? = nil, authorizationCode: OAuthFlow? = nil, deviceAuthorization: OAuthFlow? = nil) {
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
    public init(authorizationUrl: String? = nil, tokenUrl: String? = nil, refreshUrl: String? = nil, deviceAuthorizationUrl: String? = nil, scopes: [String: String]? = nil) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.scopes = scopes
    }
}
