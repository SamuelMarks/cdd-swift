import Foundation

// MARK: - Root Object

/// Represents an OpenAPI Document.
public struct OpenAPIDocument: Codable, Equatable {
    /// Documentation for openapi
    public let openapi: String
    /// Documentation for selfRef
    public let selfRef: String?
    /// Documentation for info
    public let info: Info
    /// Documentation for jsonSchemaDialect
    public let jsonSchemaDialect: String?
    /// Documentation for servers
    public let servers: [Server]?
    /// Documentation for paths
    public let paths: [String: PathItem]?
    /// Documentation for webhooks
    public let webhooks: [String: PathItem]?
    /// Documentation for components
    public let components: Components?
    /// Documentation for security
    public let security: [SecurityRequirement]?
    /// Documentation for tags
    public let tags: [Tag]?
    /// Documentation for externalDocs
    public let externalDocs: ExternalDocumentation?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case openapi
        case selfRef = "$self"
        case info
        case jsonSchemaDialect
        case servers
        case paths
        case webhooks
        case components
        case security
        case tags
        case externalDocs
    }

    /// Documentation for initializer
    public init(openapi: String, selfRef: String? = nil, info: Info, jsonSchemaDialect: String? = nil, servers: [Server]? = nil, paths: [String: PathItem]? = nil, webhooks: [String: PathItem]? = nil, components: Components? = nil, security: [SecurityRequirement]? = nil, tags: [Tag]? = nil, externalDocs: ExternalDocumentation? = nil) {
        self.openapi = openapi
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
    }
}

// MARK: - Info Object

/// Documentation for Info
public struct Info: Codable, Equatable {
    /// Documentation for title
    public let title: String
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for termsOfService
    public let termsOfService: String?
    /// Documentation for contact
    public let contact: Contact?
    /// Documentation for license
    public let license: License?
    /// Documentation for version
    public let version: String

    /// Documentation for initializer
    public init(title: String, summary: String? = nil, description: String? = nil, termsOfService: String? = nil, contact: Contact? = nil, license: License? = nil, version: String) {
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

/// Documentation for Contact
public struct Contact: Codable, Equatable {
    /// Documentation for name
    public let name: String?
    /// Documentation for url
    public let url: String?
    /// Documentation for email
    public let email: String?

    /// Documentation for initializer
    public init(name: String? = nil, url: String? = nil, email: String? = nil) {
        self.name = name
        self.url = url
        self.email = email
    }
}

// MARK: - License Object

/// Documentation for License
public struct License: Codable, Equatable {
    /// Documentation for name
    public let name: String
    /// Documentation for identifier
    public let identifier: String?
    /// Documentation for url
    public let url: String?

    /// Documentation for initializer
    public init(name: String, identifier: String? = nil, url: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.url = url
    }
}

// MARK: - Server Object

/// Documentation for Server
public struct Server: Codable, Equatable {
    /// Documentation for url
    public let url: String
    /// Documentation for description
    public let description: String?
    /// Documentation for name
    public let name: String?
    /// Documentation for variables
    public let variables: [String: ServerVariable]?

    /// Documentation for initializer
    public init(url: String, description: String? = nil, name: String? = nil, variables: [String: ServerVariable]? = nil) {
        self.url = url
        self.description = description
        self.name = name
        self.variables = variables
    }
}

// MARK: - Server Variable Object

/// Documentation for ServerVariable
public struct ServerVariable: Codable, Equatable {
    /// Documentation for enum
    public let `enum`: [String]?
    /// Documentation for default
    public let `default`: String
    /// Documentation for description
    public let description: String?

    /// Documentation for initializer
    public init(enum: [String]? = nil, default: String, description: String? = nil) {
        self.enum = `enum`
        self.default = `default`
        self.description = description
    }
}

// MARK: - Components Object

/// Documentation for Components
public struct Components: Codable, Equatable {
    /// Documentation for schemas
    public let schemas: [String: Schema]?
    /// Documentation for responses
    public let responses: [String: Response]?
    /// Documentation for parameters
    public let parameters: [String: Parameter]?
    /// Documentation for examples
    public let examples: [String: Example]?
    /// Documentation for requestBodies
    public let requestBodies: [String: RequestBody]?
    /// Documentation for headers
    public let headers: [String: Header]?
    /// Documentation for securitySchemes
    public let securitySchemes: [String: SecurityScheme]?
    /// Documentation for links
    public let links: [String: Link]?
    /// Documentation for callbacks
    public let callbacks: [String: Callback]?
    /// Documentation for pathItems
    public let pathItems: [String: PathItem]?
    /// Documentation for mediaTypes
    public let mediaTypes: [String: MediaType]?

    /// Documentation for initializer
    public init(schemas: [String: Schema]? = nil, responses: [String: Response]? = nil, parameters: [String: Parameter]? = nil, examples: [String: Example]? = nil, requestBodies: [String: RequestBody]? = nil, headers: [String: Header]? = nil, securitySchemes: [String: SecurityScheme]? = nil, links: [String: Link]? = nil, callbacks: [String: Callback]? = nil, pathItems: [String: PathItem]? = nil, mediaTypes: [String: MediaType]? = nil) {
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

/// Documentation for PathItem
public struct PathItem: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for get
    public var get: Operation?
    /// Documentation for put
    public var put: Operation?
    /// Documentation for post
    public var post: Operation?
    /// Documentation for delete
    public var delete: Operation?
    /// Documentation for options
    public let options: Operation?
    /// Documentation for head
    public let head: Operation?
    /// Documentation for patch
    public var patch: Operation?
    /// Documentation for trace
    public let trace: Operation?
    /// Documentation for query
    public let query: Operation?
    /// Documentation for additionalOperations
    public let additionalOperations: [String: Operation]?
    /// Documentation for servers
    public let servers: [Server]?
    /// Documentation for parameters
    public let parameters: [Parameter]?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case get
        case put
        case post
        case delete
        case options
        case head
        case patch
        case trace
        case query
        case additionalOperations
        case servers
        case parameters
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, get: Operation? = nil, put: Operation? = nil, post: Operation? = nil, delete: Operation? = nil, options: Operation? = nil, head: Operation? = nil, patch: Operation? = nil, trace: Operation? = nil, query: Operation? = nil, additionalOperations: [String: Operation]? = nil, servers: [Server]? = nil, parameters: [Parameter]? = nil) {
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
}

// MARK: - Operation Object

/// Documentation for Operation
public struct Operation: Codable, Equatable {
    /// Documentation for tags
    public let tags: [String]?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for externalDocs
    public let externalDocs: ExternalDocumentation?
    /// Documentation for operationId
    public let operationId: String?
    /// Documentation for parameters
    public let parameters: [Parameter]?
    /// Documentation for requestBody
    public let requestBody: RequestBody?
    /// Documentation for responses
    public let responses: [String: Response]?
    /// Documentation for callbacks
    public let callbacks: [String: Callback]?
    /// Documentation for deprecated
    public let deprecated: Bool?
    /// Documentation for security
    public let security: [SecurityRequirement]?
    /// Documentation for servers
    public let servers: [Server]?

    /// Documentation for initializer
    public init(tags: [String]? = nil, summary: String? = nil, description: String? = nil, externalDocs: ExternalDocumentation? = nil, operationId: String? = nil, parameters: [Parameter]? = nil, requestBody: RequestBody? = nil, responses: [String: Response]? = nil, callbacks: [String: Callback]? = nil, deprecated: Bool? = nil, security: [SecurityRequirement]? = nil, servers: [Server]? = nil) {
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

/// Documentation for ExternalDocumentation
public struct ExternalDocumentation: Codable, Equatable {
    /// Documentation for description
    public let description: String?
    /// Documentation for url
    public let url: String

    /// Documentation for initializer
    public init(description: String? = nil, url: String) {
        self.description = description
        self.url = url
    }
}

// MARK: - Parameter Object

/// Documentation for Parameter
public struct Parameter: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for name
    public let name: String?
    /// Documentation for in
    public let `in`: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for required
    public let required: Bool?
    /// Documentation for deprecated
    public let deprecated: Bool?
    /// Documentation for allowEmptyValue
    public let allowEmptyValue: Bool?
    /// Documentation for style
    public let style: String?
    /// Documentation for explode
    public let explode: Bool?
    /// Documentation for allowReserved
    public let allowReserved: Bool?
    /// Documentation for schema
    public let schema: Schema?
    /// Documentation for example
    public let example: AnyCodable?
    /// Documentation for examples
    public let examples: [String: Example]?
    /// Documentation for content
    public let content: [String: MediaType]?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case name
        case `in`
        case description
        case required
        case deprecated
        case allowEmptyValue
        case style
        case explode
        case allowReserved
        case schema
        case example
        case examples
        case content
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, name: String? = nil, in location: String? = nil, description: String? = nil, required: Bool? = nil, deprecated: Bool? = nil, allowEmptyValue: Bool? = nil, style: String? = nil, explode: Bool? = nil, allowReserved: Bool? = nil, schema: Schema? = nil, example: AnyCodable? = nil, examples: [String: Example]? = nil, content: [String: MediaType]? = nil) {
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

/// Documentation for RequestBody
public struct RequestBody: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for content
    public let content: [String: MediaType]?
    /// Documentation for required
    public let required: Bool?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case content
        case required
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, content: [String: MediaType]? = nil, required: Bool? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.content = content
        self.required = required
    }
}

// MARK: - Media Type Object

/// Documentation for MediaType
public struct MediaType: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for schema
    public let schema: Schema?
    /// Documentation for itemSchema
    public let itemSchema: Schema?
    /// Documentation for example
    public let example: AnyCodable?
    /// Documentation for examples
    public let examples: [String: Example]?
    /// Documentation for encoding
    public let encoding: [String: EncodingObject]?
    /// Documentation for prefixEncoding
    public let prefixEncoding: [EncodingObject]?
    /// Documentation for itemEncoding
    public let itemEncoding: EncodingObject?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case schema
        case itemSchema
        case example
        case examples
        case encoding
        case prefixEncoding
        case itemEncoding
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, schema: Schema? = nil, itemSchema: Schema? = nil, example: AnyCodable? = nil, examples: [String: Example]? = nil, encoding: [String: EncodingObject]? = nil, prefixEncoding: [EncodingObject]? = nil, itemEncoding: EncodingObject? = nil) {
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

/// Documentation for EncodingObject
public struct EncodingObject: Codable, Equatable {
    /// Documentation for contentType
    public let contentType: String?
    /// Documentation for headers
    public let headers: [String: Header]?
    /// Documentation for style
    public let style: String?
    /// Documentation for explode
    public let explode: Bool?
    /// Documentation for allowReserved
    public let allowReserved: Bool?

    /// Documentation for initializer
    public init(contentType: String? = nil, headers: [String: Header]? = nil, style: String? = nil, explode: Bool? = nil, allowReserved: Bool? = nil) {
        self.contentType = contentType
        self.headers = headers
        self.style = style
        self.explode = explode
        self.allowReserved = allowReserved
    }
}

// MARK: - Response Object

/// Documentation for Response
public struct Response: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for headers
    public let headers: [String: Header]?
    /// Documentation for content
    public let content: [String: MediaType]?
    /// Documentation for links
    public let links: [String: Link]?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case headers
        case content
        case links
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, headers: [String: Header]? = nil, content: [String: MediaType]? = nil, links: [String: Link]? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.headers = headers
        self.content = content
        self.links = links
    }
}

// MARK: - Callback Object

/// Documentation for Callback
public typealias Callback = [String: PathItem]

// MARK: - Example Object

/// Documentation for Example
public struct Example: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for value
    public let value: AnyCodable?
    /// Documentation for externalValue
    public let externalValue: String?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case value
        case externalValue
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, value: AnyCodable? = nil, externalValue: String? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.value = value
        self.externalValue = externalValue
    }
}

// MARK: - Link Object

/// Documentation for Link
public struct Link: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for operationRef
    public let operationRef: String?
    /// Documentation for operationId
    public let operationId: String?
    /// Documentation for parameters
    public let parameters: [String: AnyCodable]?
    /// Documentation for requestBody
    public let requestBody: AnyCodable?
    /// Documentation for description
    public let description: String?
    /// Documentation for server
    public let server: Server?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case operationRef
        case operationId
        case parameters
        case requestBody
        case description
        case server
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, operationRef: String? = nil, operationId: String? = nil, parameters: [String: AnyCodable]? = nil, requestBody: AnyCodable? = nil, description: String? = nil, server: Server? = nil) {
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

/// Documentation for Header
public struct Header: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for required
    public let required: Bool?
    /// Documentation for deprecated
    public let deprecated: Bool?
    /// Documentation for allowEmptyValue
    public let allowEmptyValue: Bool?
    /// Documentation for style
    public let style: String?
    /// Documentation for explode
    public let explode: Bool?
    /// Documentation for allowReserved
    public let allowReserved: Bool?
    /// Documentation for schema
    public let schema: Schema?
    /// Documentation for example
    public let example: AnyCodable?
    /// Documentation for examples
    public let examples: [String: Example]?
    /// Documentation for content
    public let content: [String: MediaType]?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case required
        case deprecated
        case allowEmptyValue
        case style
        case explode
        case allowReserved
        case schema
        case example
        case examples
        case content
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, required: Bool? = nil, deprecated: Bool? = nil, allowEmptyValue: Bool? = nil, style: String? = nil, explode: Bool? = nil, allowReserved: Bool? = nil, schema: Schema? = nil, example: AnyCodable? = nil, examples: [String: Example]? = nil, content: [String: MediaType]? = nil) {
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

/// Documentation for Tag
public struct Tag: Codable, Equatable {
    /// Documentation for name
    public let name: String
    /// Documentation for description
    public let description: String?
    /// Documentation for externalDocs
    public let externalDocs: ExternalDocumentation?

    /// Documentation for initializer
    public init(name: String, description: String? = nil, externalDocs: ExternalDocumentation? = nil) {
        self.name = name
        self.description = description
        self.externalDocs = externalDocs
    }
}

// MARK: - Security Requirement Object

/// Documentation for SecurityRequirement
public typealias SecurityRequirement = [String: [String]]

// MARK: - Security Scheme Object

/// Documentation for SecurityScheme
public struct SecurityScheme: Codable, Equatable {
    /// Documentation for ref
    public let ref: String?
    /// Documentation for summary
    public let summary: String?
    /// Documentation for type
    public let type: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for name
    public let name: String?
    /// Documentation for in
    public let `in`: String?
    /// Documentation for scheme
    public let scheme: String?
    /// Documentation for bearerFormat
    public let bearerFormat: String?
    /// Documentation for flows
    public let flows: OAuthFlows?
    /// Documentation for openIdConnectUrl
    public let openIdConnectUrl: String?
    /// Documentation for oauth2MetadataUrl
    public let oauth2MetadataUrl: String?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case type
        case description
        case name
        case `in`
        case scheme
        case bearerFormat
        case flows
        case openIdConnectUrl
        case oauth2MetadataUrl
    }

    /// Documentation for initializer
    public init(ref: String? = nil, summary: String? = nil, type: String? = nil, description: String? = nil, name: String? = nil, in location: String? = nil, scheme: String? = nil, bearerFormat: String? = nil, flows: OAuthFlows? = nil, openIdConnectUrl: String? = nil, oauth2MetadataUrl: String? = nil) {
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
    }
}

// MARK: - OAuth Flows Object

/// Documentation for OAuthFlows
public struct OAuthFlows: Codable, Equatable {
    /// Documentation for implicit
    public let implicit: OAuthFlow?
    /// Documentation for password
    public let password: OAuthFlow?
    /// Documentation for clientCredentials
    public let clientCredentials: OAuthFlow?
    /// Documentation for authorizationCode
    public let authorizationCode: OAuthFlow?
    /// Documentation for deviceAuthorization
    public let deviceAuthorization: OAuthFlow?

    /// Documentation for initializer
    public init(implicit: OAuthFlow? = nil, password: OAuthFlow? = nil, clientCredentials: OAuthFlow? = nil, authorizationCode: OAuthFlow? = nil, deviceAuthorization: OAuthFlow? = nil) {
        self.implicit = implicit
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
        self.deviceAuthorization = deviceAuthorization
    }
}

// MARK: - OAuth Flow Object

/// Documentation for OAuthFlow
public struct OAuthFlow: Codable, Equatable {
    /// Documentation for authorizationUrl
    public let authorizationUrl: String?
    /// Documentation for tokenUrl
    public let tokenUrl: String?
    /// Documentation for refreshUrl
    public let refreshUrl: String?
    /// Documentation for deviceAuthorizationUrl
    public let deviceAuthorizationUrl: String?
    /// Documentation for scopes
    public let scopes: [String: String]?

    /// Documentation for initializer
    public init(authorizationUrl: String? = nil, tokenUrl: String? = nil, refreshUrl: String? = nil, deviceAuthorizationUrl: String? = nil, scopes: [String: String]? = nil) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.scopes = scopes
    }
}

// MARK: - Schema Object

/// Documentation for Schema
public struct Schema: Codable, Equatable {
    // Basic types
    /// Documentation for type
    public let type: String?
    /// Documentation for properties
    public let properties: [String: Schema]?
    /// Documentation for additionalProperties
    public let additionalProperties: SchemaItem?
    /// Documentation for items
    public let items: SchemaItem?
    /// Documentation for prefixItems
    public let prefixItems: [Schema]?
    /// Documentation for required
    public let required: [String]?
    /// Documentation for ref
    public let ref: String?

    // JSON Schema metadata and validation keywords
    /// Documentation for title
    public let title: String?
    /// Documentation for description
    public let description: String?
    /// Documentation for format
    public let format: String?
    /// Documentation for default_value
    public let default_value: AnyCodable?
    /// Documentation for const_value
    public let const_value: AnyCodable?

    /// Documentation for multipleOf
    public let multipleOf: Double?
    /// Documentation for maximum
    public let maximum: Double?
    /// Documentation for exclusiveMaximum
    public let exclusiveMaximum: Double?
    /// Documentation for minimum
    public let minimum: Double?
    /// Documentation for exclusiveMinimum
    public let exclusiveMinimum: Double?

    /// Documentation for maxLength
    public let maxLength: Int?
    /// Documentation for minLength
    public let minLength: Int?
    /// Documentation for pattern
    public let pattern: String?

    /// Documentation for maxItems
    public let maxItems: Int?
    /// Documentation for minItems
    public let minItems: Int?
    /// Documentation for uniqueItems
    public let uniqueItems: Bool?
    /// Documentation for contains
    public let contains: SchemaItem?
    /// Documentation for minContains
    public let minContains: Int?
    /// Documentation for maxContains
    public let maxContains: Int?

    /// Documentation for maxProperties
    public let maxProperties: Int?
    /// Documentation for minProperties
    public let minProperties: Int?
    /// Documentation for dependentRequired
    public let dependentRequired: [String: [String]]?
    /// Documentation for dependentSchemas
    public let dependentSchemas: [String: Schema]?
    /// Documentation for propertyNames
    public let propertyNames: SchemaItem?
    /// Documentation for patternProperties
    public let patternProperties: [String: Schema]?
    /// Documentation for unevaluatedItems
    public let unevaluatedItems: SchemaItem?
    /// Documentation for unevaluatedProperties
    public let unevaluatedProperties: SchemaItem?

    /// Documentation for enum_values
    public let enum_values: [AnyCodable]?

    // Media type and content encoding
    /// Documentation for contentEncoding
    public let contentEncoding: String?
    /// Documentation for contentMediaType
    public let contentMediaType: String?
    /// Documentation for contentSchema
    public let contentSchema: SchemaItem?

    // Polymorphism
    /// Documentation for allOf
    public let allOf: [Schema]?
    /// Documentation for oneOf
    public let oneOf: [Schema]?
    /// Documentation for anyOf
    public let anyOf: [Schema]?
    /// Documentation for not
    public let not: SchemaItem?

    /// Documentation for if_schema
    public let if_schema: SchemaItem?
    /// Documentation for then_schema
    public let then_schema: SchemaItem?
    /// Documentation for else_schema
    public let else_schema: SchemaItem?

    // Identifiers and Dialects
    /// Documentation for id
    public let id: String?
    /// Documentation for anchor
    public let anchor: String?
    /// Documentation for dynamicAnchor
    public let dynamicAnchor: String?
    /// Documentation for vocabulary
    public let vocabulary: [String: Bool]?
    /// Documentation for dynamicRef
    public let dynamicRef: String?
    /// Documentation for defs
    public let defs: [String: Schema]?

    // OpenAPI specific
    /// Documentation for discriminator
    public let discriminator: Discriminator?
    /// Documentation for xml
    public let xml: XML?
    /// Documentation for externalDocs
    public let externalDocs: ExternalDocumentation?
    /// Documentation for example
    public let example: AnyCodable?
    /// Documentation for deprecated
    public let deprecated: Bool?
    /// Documentation for readOnly
    public let readOnly: Bool?
    /// Documentation for writeOnly
    public let writeOnly: Bool?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case additionalProperties
        case items
        case prefixItems
        case required
        case ref = "$ref"

        case title
        case description
        case format
        case default_value = "default"
        case const_value = "const"

        case multipleOf
        case maximum
        case exclusiveMaximum
        case minimum
        case exclusiveMinimum

        case maxLength
        case minLength
        case pattern

        case maxItems
        case minItems
        case uniqueItems
        case contains
        case minContains
        case maxContains

        case maxProperties
        case minProperties
        case dependentRequired
        case dependentSchemas
        case propertyNames
        case patternProperties
        case unevaluatedItems
        case unevaluatedProperties

        case enum_values = "enum"

        case contentEncoding
        case contentMediaType
        case contentSchema

        case allOf
        case oneOf
        case anyOf
        case not

        case if_schema = "if"
        case then_schema = "then"
        case else_schema = "else"

        case id = "$id"
        case anchor = "$anchor"
        case dynamicAnchor = "$dynamicAnchor"
        case vocabulary = "$vocabulary"
        case dynamicRef = "$dynamicRef"
        case defs = "$defs"

        case discriminator
        case xml
        case externalDocs
        case example
        case deprecated
        case readOnly
        case writeOnly
    }

    /// Documentation for initializer
    public init(
        type: String? = nil, properties: [String: Schema]? = nil, additionalProperties: SchemaItem? = nil, items: SchemaItem? = nil, prefixItems: [Schema]? = nil, required: [String]? = nil, ref: String? = nil,
        title: String? = nil, description: String? = nil, format: String? = nil, default_value: AnyCodable? = nil, const_value: AnyCodable? = nil,
        multipleOf: Double? = nil, maximum: Double? = nil, exclusiveMaximum: Double? = nil, minimum: Double? = nil, exclusiveMinimum: Double? = nil,
        maxLength: Int? = nil, minLength: Int? = nil, pattern: String? = nil,
        maxItems: Int? = nil, minItems: Int? = nil, uniqueItems: Bool? = nil, contains: SchemaItem? = nil, minContains: Int? = nil, maxContains: Int? = nil,
        maxProperties: Int? = nil, minProperties: Int? = nil, dependentRequired: [String: [String]]? = nil, dependentSchemas: [String: Schema]? = nil, propertyNames: SchemaItem? = nil, patternProperties: [String: Schema]? = nil, unevaluatedItems: SchemaItem? = nil, unevaluatedProperties: SchemaItem? = nil,
        enum_values: [AnyCodable]? = nil,
        contentEncoding: String? = nil, contentMediaType: String? = nil, contentSchema: SchemaItem? = nil,
        allOf: [Schema]? = nil, oneOf: [Schema]? = nil, anyOf: [Schema]? = nil, not: SchemaItem? = nil,
        if_schema: SchemaItem? = nil, then_schema: SchemaItem? = nil, else_schema: SchemaItem? = nil,
        id: String? = nil, anchor: String? = nil, dynamicAnchor: String? = nil, vocabulary: [String: Bool]? = nil, dynamicRef: String? = nil, defs: [String: Schema]? = nil,
        discriminator: Discriminator? = nil, xml: XML? = nil, externalDocs: ExternalDocumentation? = nil, example: AnyCodable? = nil, deprecated: Bool? = nil, readOnly: Bool? = nil, writeOnly: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.additionalProperties = additionalProperties
        self.items = items
        self.prefixItems = prefixItems
        self.required = required
        self.ref = ref

        self.title = title
        self.description = description
        self.format = format
        self.default_value = default_value
        self.const_value = const_value

        self.multipleOf = multipleOf
        self.maximum = maximum
        self.exclusiveMaximum = exclusiveMaximum
        self.minimum = minimum
        self.exclusiveMinimum = exclusiveMinimum

        self.maxLength = maxLength
        self.minLength = minLength
        self.pattern = pattern

        self.maxItems = maxItems
        self.minItems = minItems
        self.uniqueItems = uniqueItems
        self.contains = contains
        self.minContains = minContains
        self.maxContains = maxContains

        self.maxProperties = maxProperties
        self.minProperties = minProperties
        self.dependentRequired = dependentRequired
        self.dependentSchemas = dependentSchemas
        self.propertyNames = propertyNames
        self.patternProperties = patternProperties
        self.unevaluatedItems = unevaluatedItems
        self.unevaluatedProperties = unevaluatedProperties

        self.enum_values = enum_values

        self.contentEncoding = contentEncoding
        self.contentMediaType = contentMediaType
        self.contentSchema = contentSchema

        self.allOf = allOf
        self.oneOf = oneOf
        self.anyOf = anyOf
        self.not = not

        self.if_schema = if_schema
        self.then_schema = then_schema
        self.else_schema = else_schema

        self.id = id
        self.anchor = anchor
        self.dynamicAnchor = dynamicAnchor
        self.vocabulary = vocabulary
        self.dynamicRef = dynamicRef
        self.defs = defs

        self.discriminator = discriminator
        self.xml = xml
        self.externalDocs = externalDocs
        self.example = example
        self.deprecated = deprecated
        self.readOnly = readOnly
        self.writeOnly = writeOnly
    }
}

// MARK: - Discriminator Object

/// Documentation for Discriminator
public struct Discriminator: Codable, Equatable {
    /// Documentation for propertyName
    public let propertyName: String
    /// Documentation for mapping
    public let mapping: [String: String]?
    /// Documentation for defaultMapping
    public let defaultMapping: String?

    /// Documentation for initializer
    public init(propertyName: String, mapping: [String: String]? = nil, defaultMapping: String? = nil) {
        self.propertyName = propertyName
        self.mapping = mapping
        self.defaultMapping = defaultMapping
    }
}

// MARK: - XML Object

/// Documentation for XML
public struct XML: Codable, Equatable {
    /// Documentation for name
    public let name: String?
    /// Documentation for namespace
    public let namespace: String?
    /// Documentation for prefix
    public let prefix: String?
    /// Documentation for attribute
    public let attribute: Bool?
    /// Documentation for wrapped
    public let wrapped: Bool?
    /// Documentation for nodeType
    public let nodeType: String?

    /// Documentation for initializer
    public init(name: String? = nil, namespace: String? = nil, prefix: String? = nil, attribute: Bool? = nil, wrapped: Bool? = nil, nodeType: String? = nil) {
        self.name = name
        self.namespace = namespace
        self.prefix = prefix
        self.attribute = attribute
        self.wrapped = wrapped
        self.nodeType = nodeType
    }
}

// MARK: - Schema Item Object

/// Documentation for SchemaItem
public struct SchemaItem: Codable, Equatable {
    /// Documentation for type
    public let type: String?
    /// Documentation for ref
    public let ref: String?

    /// Documentation for CodingKeys
    enum CodingKeys: String, CodingKey {
        case type
        case ref = "$ref"
    }

    /// Documentation for initializer
    public init(type: String? = nil, ref: String? = nil) {
        self.type = type
        self.ref = ref
    }
}
