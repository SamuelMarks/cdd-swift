/// Core OpenAPI 3.2.0 and Swagger 2.0 specification root, info, server, component, and path models.
import Foundation

// MARK: - Root Object

/// Represents an OpenAPI 3.x or Swagger 2.0 root document.
public struct OpenAPIDocument: Codable, Equatable, Sendable {
    /// Semantic version string of the OpenAPI specification (e.g. `"3.2.0"`).
    public let openapi: String?
    /// Semantic version string of a legacy Swagger specification (e.g. `"2.0"`).
    public let swagger: String?
    /// Canonical `$self` URI identifying this OpenAPI 3.2.0 document.
    public let selfRef: String?
    /// General metadata about the API (`title`, `version`, `description`, etc.).
    public let info: Info
    /// Default JSON Schema dialect URI for `Schema` objects in the document.
    public let jsonSchemaDialect: String?
    /// Connectivity information for target API servers.
    public let servers: [Server]?
    /// Available endpoint paths and operations for the API.
    public let paths: [String: PathItem]?
    /// Incoming webhooks that may be sent by the API provider.
    public let webhooks: [String: PathItem]?
    /// Reusable components registry (schemas, parameters, responses, securitySchemes, etc.).
    public let components: Components?
    /// Default security requirements applied across the entire API.
    public let security: [SecurityRequirement]?
    /// Metadata tags used to group operations.
    public let tags: [Tag]?
    /// Additional external documentation for the API.
    public let externalDocs: ExternalDocumentation?
    /// Legacy Swagger 2.0 host name or IP address serving the API.
    public let host: String?
    /// Legacy Swagger 2.0 base path prefix on which the API is served.
    public let basePath: String?
    /// Legacy Swagger 2.0 transfer protocols (`"http"`, `"https"`, `"ws"`, `"wss"`).
    public let schemes: [String]?
    /// Legacy Swagger 2.0 default MIME types the API can consume.
    public let consumes: [String]?
    /// Legacy Swagger 2.0 default MIME types the API can produce.
    public let produces: [String]?
    /// Legacy Swagger 2.0 reusable schema definitions.
    public let definitions: [String: Schema]?
    /// Legacy Swagger 2.0 reusable parameter definitions.
    public let parameters: [String: Parameter]?
    /// Legacy Swagger 2.0 reusable response definitions.
    public let responses: [String: Response]?
    /// Legacy Swagger 2.0 security scheme definitions.
    public let securityDefinitions: [String: SecurityScheme]?

    /// Coding keys mapping OpenAPI JSON properties to `OpenAPIDocument` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `openapi`.
        case openapi
        /// Key for `swagger`.
        case swagger
        /// Key for `$self`.
        case selfRef = "$self"
        /// Key for `info`.
        case info
        /// Key for `jsonSchemaDialect`.
        case jsonSchemaDialect
        /// Key for `servers`.
        case servers
        /// Key for `paths`.
        case paths
        /// Key for `webhooks`.
        case webhooks
        /// Key for `components`.
        case components
        /// Key for `security`.
        case security
        /// Key for `tags`.
        case tags
        /// Key for `externalDocs`.
        case externalDocs
        /// Key for `host`.
        case host
        /// Key for `basePath`.
        case basePath
        /// Key for `schemes`.
        case schemes
        /// Key for `consumes`.
        case consumes
        /// Key for `produces`.
        case produces
        /// Key for `definitions`.
        case definitions
        /// Key for `parameters`.
        case parameters
        /// Key for `responses`.
        case responses
        /// Key for `securityDefinitions`.
        case securityDefinitions
    }

    /// Initializes an `OpenAPIDocument`.
    ///
    /// - Parameters:
    ///   - openapi: OpenAPI version string (e.g. `"3.2.0"`).
    ///   - swagger: Legacy Swagger version string (e.g. `"2.0"`).
    ///   - selfRef: Canonical `$self` URI of the document.
    ///   - info: Required `Info` metadata object.
    ///   - jsonSchemaDialect: Optional JSON Schema dialect URI.
    ///   - servers: Optional array of target `Server` descriptors.
    ///   - paths: Optional map of URL path templates to `PathItem` definitions.
    ///   - webhooks: Optional map of webhook names to `PathItem` definitions.
    ///   - components: Optional reusable `Components` container.
    ///   - security: Optional global security requirement declarations.
    ///   - tags: Optional list of API `Tag` objects.
    ///   - externalDocs: Optional `ExternalDocumentation` reference.
    ///   - host: Optional Swagger 2.0 host string.
    ///   - basePath: Optional Swagger 2.0 base path string.
    ///   - schemes: Optional Swagger 2.0 URI schemes list.
    ///   - consumes: Optional Swagger 2.0 request MIME types.
    ///   - produces: Optional Swagger 2.0 response MIME types.
    ///   - definitions: Optional Swagger 2.0 schema definitions map.
    ///   - parameters: Optional Swagger 2.0 parameter definitions map.
    ///   - responses: Optional Swagger 2.0 response definitions map.
    ///   - securityDefinitions: Optional Swagger 2.0 security definitions map.
    public init(
        openapi: String? = nil, swagger: String? = nil, selfRef: String? = nil, info: Info,
        jsonSchemaDialect: String? = nil, servers: [Server]? = nil, paths: [String: PathItem]? = nil,
        webhooks: [String: PathItem]? = nil, components: Components? = nil, security: [SecurityRequirement]? = nil,
        tags: [Tag]? = nil, externalDocs: ExternalDocumentation? = nil, host: String? = nil, basePath: String? = nil,
        schemes: [String]? = nil, consumes: [String]? = nil, produces: [String]? = nil,
        definitions: [String: Schema]? = nil, parameters: [String: Parameter]? = nil,
        responses: [String: Response]? = nil, securityDefinitions: [String: SecurityScheme]? = nil
    ) {
        self.openapi = openapi
        self.swagger = swagger
        self.selfRef = selfRef
        self.info = info
        self.jsonSchemaDialect = jsonSchemaDialect
        self.servers = servers
        self.paths = paths
        self.webhooks = webhooks
        self.components = components
        self.security = security
        self.tags = tags
        self.externalDocs = externalDocs
        self.host = host
        self.basePath = basePath
        self.schemes = schemes
        self.consumes = consumes
        self.produces = produces
        self.definitions = definitions
        self.parameters = parameters
        self.responses = responses
        self.securityDefinitions = securityDefinitions
    }
}

// MARK: - Info Object

/// Metadata about the API described by an `OpenAPIDocument`.
public struct Info: Codable, Equatable, Sendable {
    /// Human-readable title of the API.
    public let title: String
    /// Short summary of the API.
    public let summary: String?
    /// Detailed CommonMark-compatible description of the API.
    public let description: String?
    /// URL to the Terms of Service for the API.
    public let termsOfService: String?
    /// Contact information for the exposed API.
    public let contact: Contact?
    /// License information for the exposed API.
    public let license: License?
    /// Version of the OpenAPI document / API implementation.
    public let version: String

    /// Initializes an `Info` metadata object.
    ///
    /// - Parameters:
    ///   - title: The title of the API.
    ///   - summary: Optional short summary of the API.
    ///   - description: Optional detailed description of the API.
    ///   - termsOfService: Optional URL to the API terms of service.
    ///   - contact: Optional `Contact` details.
    ///   - license: Optional `License` details.
    ///   - version: Semantic version of the API.
    public init(
        title: String, summary: String? = nil, description: String? = nil, termsOfService: String? = nil,
        contact: Contact? = nil, license: License? = nil, version: String
    ) {
        self.title = title
        self.summary = summary
        self.description = description
        self.termsOfService = termsOfService
        self.contact = contact
        self.license = license
        self.version = version
    }
}

// MARK: - Contact Object

/// Contact information for the exposed API.
public struct Contact: Codable, Equatable, Sendable {
    /// Identifying name of the contact person or organization.
    public let name: String?
    /// URL pointing to the contact information.
    public let url: String?
    /// Email address of the contact person or organization.
    public let email: String?

    /// Initializes a `Contact` object.
    ///
    /// - Parameters:
    ///   - name: Optional contact name.
    ///   - url: Optional contact URL.
    ///   - email: Optional contact email address.
    public init(name: String? = nil, url: String? = nil, email: String? = nil) {
        self.name = name
        self.url = url
        self.email = email
    }
}

// MARK: - License Object

/// License information for the exposed API.
public struct License: Codable, Equatable, Sendable {
    /// License name used for the API.
    public let name: String
    /// SPDX license expression for the API (e.g. `"Apache-2.0"`).
    public let identifier: String?
    /// URL to the license used for the API.
    public let url: String?

    /// Initializes a `License` object.
    ///
    /// - Parameters:
    ///   - name: The license display name.
    ///   - identifier: Optional SPDX license identifier.
    ///   - url: Optional URL to the full license text.
    public init(name: String, identifier: String? = nil, url: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.url = url
    }
}

// MARK: - Server Object

/// Represents a target server hosting the API.
public struct Server: Codable, Equatable, Sendable {
    /// Target host URL (may contain `{variable}` substitutions).
    public let url: String
    /// Optional string describing the host designated by the URL.
    public let description: String?
    /// Optional human-readable name for the server (OpenAPI 3.2.0).
    public let name: String?
    /// Map between a variable name and its value for URL template substitution.
    public let variables: [String: ServerVariable]?

    /// Initializes a `Server` descriptor.
    ///
    /// - Parameters:
    ///   - url: Target server URL or URL template.
    ///   - description: Optional description of the server environment.
    ///   - name: Optional server name.
    ///   - variables: Optional map of URL template variables.
    public init(url: String, description: String? = nil, name: String? = nil, variables: [String: ServerVariable]? = nil) {
        self.url = url
        self.description = description
        self.name = name
        self.variables = variables
    }
}

// MARK: - Server Variable Object

/// Represents a Server Variable for server URL template substitution.
public struct ServerVariable: Codable, Equatable, Sendable {
    /// Enumeration of string values to be used if the substitution options are from a limited set.
    public let `enum`: [String]?
    /// Default value to use for substitution if an alternate value is not supplied.
    public let `default`: String
    /// Optional description for the server variable.
    public let description: String?

    /// Initializes a `ServerVariable`.
    ///
    /// - Parameters:
    ///   - enum: Optional allowed string values for the variable.
    ///   - default: Required default substitution value.
    ///   - description: Optional description of the variable.
    public init(enum: [String]? = nil, default: String, description: String? = nil) {
        self.enum = `enum`
        self.default = `default`
        self.description = description
    }
}

// MARK: - Components Object

/// Holds a set of reusable objects for different aspects of the OpenAPI specification.
public struct Components: Codable, Equatable, Sendable {
    /// Reusable `Schema` objects keyed by component name.
    public let schemas: [String: Schema]?
    /// Reusable `Response` objects keyed by component name.
    public let responses: [String: Response]?
    /// Reusable `Parameter` objects keyed by component name.
    public let parameters: [String: Parameter]?
    /// Reusable `Example` objects keyed by component name.
    public let examples: [String: Example]?
    /// Reusable `RequestBody` objects keyed by component name.
    public let requestBodies: [String: RequestBody]?
    /// Reusable `Header` objects keyed by component name.
    public let headers: [String: Header]?
    /// Reusable `SecurityScheme` objects keyed by component name.
    public let securitySchemes: [String: SecurityScheme]?
    /// Reusable `Link` objects keyed by component name.
    public let links: [String: Link]?
    /// Reusable `Callback` objects keyed by component name.
    public let callbacks: [String: Callback]?
    /// Reusable `PathItem` objects keyed by component name.
    public let pathItems: [String: PathItem]?
    /// Reusable `MediaType` objects keyed by component name (OpenAPI 3.2.0).
    public let mediaTypes: [String: MediaType]?

    /// Initializes a `Components` registry.
    ///
    /// - Parameters:
    ///   - schemas: Optional map of reusable schemas.
    ///   - responses: Optional map of reusable responses.
    ///   - parameters: Optional map of reusable parameters.
    ///   - examples: Optional map of reusable examples.
    ///   - requestBodies: Optional map of reusable request bodies.
    ///   - headers: Optional map of reusable headers.
    ///   - securitySchemes: Optional map of reusable security schemes.
    ///   - links: Optional map of reusable links.
    ///   - callbacks: Optional map of reusable callbacks.
    ///   - pathItems: Optional map of reusable path items.
    ///   - mediaTypes: Optional map of reusable media types.
    public init(
        schemas: [String: Schema]? = nil, responses: [String: Response]? = nil, parameters: [String: Parameter]? = nil,
        examples: [String: Example]? = nil, requestBodies: [String: RequestBody]? = nil, headers: [String: Header]? = nil,
        securitySchemes: [String: SecurityScheme]? = nil, links: [String: Link]? = nil, callbacks: [String: Callback]? = nil,
        pathItems: [String: PathItem]? = nil, mediaTypes: [String: MediaType]? = nil
    ) {
        self.schemas = schemas
        self.responses = responses
        self.parameters = parameters
        self.examples = examples
        self.requestBodies = requestBodies
        self.headers = headers
        self.securitySchemes = securitySchemes
        self.links = links
        self.callbacks = callbacks
        self.pathItems = pathItems
        self.mediaTypes = mediaTypes
    }
}

// MARK: - Path Item Object

/// Describes the operations available on a single API path.
public struct PathItem: Codable, Equatable, Sendable {
    /// External or component `$ref` reference for this path item.
    public let ref: String?
    /// Optional short summary intended to apply to all operations in this path.
    public let summary: String?
    /// Optional detailed description intended to apply to all operations in this path.
    public let description: String?
    /// Definition of a `GET` operation on this path.
    public var get: Operation?
    /// Definition of a `PUT` operation on this path.
    public var put: Operation?
    /// Definition of a `POST` operation on this path.
    public var post: Operation?
    /// Definition of a `DELETE` operation on this path.
    public var delete: Operation?
    /// Definition of an `OPTIONS` operation on this path.
    public var options: Operation?
    /// Definition of a `HEAD` operation on this path.
    public var head: Operation?
    /// Definition of a `PATCH` operation on this path.
    public var patch: Operation?
    /// Definition of a `TRACE` operation on this path.
    public var trace: Operation?
    /// Definition of a `QUERY` operation on this path (OpenAPI 3.2.0).
    public var query: Operation?
    /// Map of custom/additional HTTP method names to `Operation` definitions (OpenAPI 3.2.0).
    public let additionalOperations: [String: Operation]?
    /// Alternative `Server` array to service all operations in this path.
    public let servers: [Server]?
    /// List of parameters that are applicable for all the operations described under this path.
    public let parameters: [Parameter]?

    /// Coding keys mapping OpenAPI JSON properties to `PathItem` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `summary`.
        case summary
        /// Key for `description`.
        case description
        /// Key for `get`.
        case get
        /// Key for `put`.
        case put
        /// Key for `post`.
        case post
        /// Key for `delete`.
        case delete
        /// Key for `options`.
        case options
        /// Key for `head`.
        case head
        /// Key for `patch`.
        case patch
        /// Key for `trace`.
        case trace
        /// Key for `query`.
        case query
        /// Key for `additionalOperations`.
        case additionalOperations
        /// Key for `servers`.
        case servers
        /// Key for `parameters`.
        case parameters
    }

    /// Initializes a `PathItem`.
    ///
    /// - Parameters:
    ///   - ref: Optional `$ref` pointer string.
    ///   - summary: Optional path summary.
    ///   - description: Optional path description.
    ///   - get: Optional `GET` operation.
    ///   - put: Optional `PUT` operation.
    ///   - post: Optional `POST` operation.
    ///   - delete: Optional `DELETE` operation.
    ///   - options: Optional `OPTIONS` operation.
    ///   - head: Optional `HEAD` operation.
    ///   - patch: Optional `PATCH` operation.
    ///   - trace: Optional `TRACE` operation.
    ///   - query: Optional `QUERY` operation.
    ///   - additionalOperations: Optional map of custom HTTP verbs to operations.
    ///   - servers: Optional path-level server overrides.
    ///   - parameters: Optional path-level shared parameters.
    public init(
        ref: String? = nil, summary: String? = nil, description: String? = nil,
        get: Operation? = nil, put: Operation? = nil, post: Operation? = nil, delete: Operation? = nil,
        options: Operation? = nil, head: Operation? = nil, patch: Operation? = nil, trace: Operation? = nil,
        query: Operation? = nil, additionalOperations: [String: Operation]? = nil,
        servers: [Server]? = nil, parameters: [Parameter]? = nil
    ) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.get = get
        self.put = put
        self.post = post
        self.delete = delete
        self.options = options
        self.head = head
        self.patch = patch
        self.trace = trace
        self.query = query
        self.additionalOperations = additionalOperations
        self.servers = servers
        self.parameters = parameters
    }

    /// Returns all non-nil standard HTTP operations defined on this `PathItem` in canonical order.
    public var operationsByMethod: [(HTTPMethod, Operation)] {
        let candidates: [(HTTPMethod, Operation?)] = [
            (.get, get), (.put, put), (.post, post), (.delete, delete),
            (.options, options), (.head, head), (.patch, patch), (.trace, trace), (.query, query)
        ]
        return candidates.compactMap { method, op in op.map { (method, $0) } }
    }
}

/// Typealias for a dictionary of endpoint path templates mapped to `PathItem` definitions.
public typealias Paths = [String: PathItem]

/// Typealias for a dictionary of HTTP status codes mapped to `Response` definitions.
public typealias Responses = [String: Response]

/// Typealias for a dictionary of runtime expression URLs mapped to `PathItem` callback definitions.
public typealias Callback = [String: PathItem]

/// Typealias for a security requirement mapping security scheme names to required OAuth2/OIDC scope lists.
public typealias SecurityRequirement = [String: [String]]
