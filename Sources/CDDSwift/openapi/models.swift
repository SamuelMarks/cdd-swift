import Foundation

// MARK: - Root Object

/// Represents an OpenAPI Document.
public struct OpenAPIDocument: Codable, Equatable {
    /// The `openapi` property.
    public let openapi: String?
    /// The `swagger` property.
    public let swagger: String?
    /// The `selfRef` property.
    public let selfRef: String?
    /// The `info` property.
    public let info: Info
    /// The `jsonSchemaDialect` property.
    public let jsonSchemaDialect: String?
    /// The `servers` property.
    public let servers: [Server]?
    /// The `paths` property.
    public let paths: [String: PathItem]?
    /// The `webhooks` property.
    public let webhooks: [String: PathItem]?
    /// The `components` property.
    public let components: Components?
    /// The `security` property.
    public let security: [SecurityRequirement]?
    /// The `tags` property.
    public let tags: [Tag]?
    /// The `externalDocs` property.
    public let externalDocs: ExternalDocumentation?

    // Swagger 2.0 properties
    /// The `host` property.
    public let host: String?
    /// The `basePath` property.
    public let basePath: String?
    /// The `schemes` property.
    public let schemes: [String]?
    /// The `consumes` property.
    public let consumes: [String]?
    /// The `produces` property.
    public let produces: [String]?
    /// The `definitions` property.
    public let definitions: [String: Schema]?
    /// The `parameters` property.
    public let parameters: [String: Parameter]?
    /// The `responses` property.
    public let responses: [String: Response]?
    /// The `securityDefinitions` property.
    public let securityDefinitions: [String: SecurityScheme]?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case openapi
        case swagger
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
        case host
        case basePath
        case schemes
        case consumes
        case produces
        case definitions
        case parameters
        case responses
        case securityDefinitions
    }

    /// The `initializer` property.
    public init(openapi: String? = nil, swagger: String? = nil, selfRef: String? = nil, info: Info, jsonSchemaDialect: String? = nil, servers: [Server]? = nil, paths: [String: PathItem]? = nil, webhooks: [String: PathItem]? = nil, components: Components? = nil, security: [SecurityRequirement]? = nil, tags: [Tag]? = nil, externalDocs: ExternalDocumentation? = nil, host: String? = nil, basePath: String? = nil, schemes: [String]? = nil, consumes: [String]? = nil, produces: [String]? = nil, definitions: [String: Schema]? = nil, parameters: [String: Parameter]? = nil, responses: [String: Response]? = nil, securityDefinitions: [String: SecurityScheme]? = nil) {
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

/// The `Info` property.
public struct Info: Codable, Equatable {
    /// The `title` property.
    public let title: String
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `termsOfService` property.
    public let termsOfService: String?
    /// The `contact` property.
    public let contact: Contact?
    /// The `license` property.
    public let license: License?
    /// The `version` property.
    public let version: String

    /// The `initializer` property.
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

/// The `Contact` property.
public struct Contact: Codable, Equatable {
    /// The `name` property.
    public let name: String?
    /// The `url` property.
    public let url: String?
    /// The `email` property.
    public let email: String?

    /// The `initializer` property.
    public init(name: String? = nil, url: String? = nil, email: String? = nil) {
        self.name = name
        self.url = url
        self.email = email
    }
}

// MARK: - License Object

/// The `License` property.
public struct License: Codable, Equatable {
    /// The `name` property.
    public let name: String
    /// The `identifier` property.
    public let identifier: String?
    /// The `url` property.
    public let url: String?

    /// The `initializer` property.
    public init(name: String, identifier: String? = nil, url: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.url = url
    }
}

// MARK: - Server Object

/// The `Server` property.
public struct Server: Codable, Equatable {
    /// The `url` property.
    public let url: String
    /// The `description` property.
    public let description: String?
    /// The `name` property.
    public let name: String?
    /// The `variables` property.
    public let variables: [String: ServerVariable]?

    /// The `initializer` property.
    public init(url: String, description: String? = nil, name: String? = nil, variables: [String: ServerVariable]? = nil) {
        self.url = url
        self.description = description
        self.name = name
        self.variables = variables
    }
}

// MARK: - Server Variable Object

/// The `ServerVariable` property.
public struct ServerVariable: Codable, Equatable {
    /// The `enum` property.
    public let `enum`: [String]?
    /// The `default` property.
    public let `default`: String
    /// The `description` property.
    public let description: String?

    /// The `initializer` property.
    public init(enum: [String]? = nil, default: String, description: String? = nil) {
        self.enum = `enum`
        self.default = `default`
        self.description = description
    }
}

// MARK: - Components Object

/// The `Components` property.
public struct Components: Codable, Equatable {
    /// The `schemas` property.
    public let schemas: [String: Schema]?
    /// The `responses` property.
    public let responses: [String: Response]?
    /// The `parameters` property.
    public let parameters: [String: Parameter]?
    /// The `examples` property.
    public let examples: [String: Example]?
    /// The `requestBodies` property.
    public let requestBodies: [String: RequestBody]?
    /// The `headers` property.
    public let headers: [String: Header]?
    /// The `securitySchemes` property.
    public let securitySchemes: [String: SecurityScheme]?
    /// The `links` property.
    public let links: [String: Link]?
    /// The `callbacks` property.
    public let callbacks: [String: Callback]?
    /// The `pathItems` property.
    public let pathItems: [String: PathItem]?
    /// The `mediaTypes` property.
    public let mediaTypes: [String: MediaType]?

    /// The `initializer` property.
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

/// The `PathItem` property.
public struct PathItem: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `get` property.
    public var get: Operation?
    /// The `put` property.
    public var put: Operation?
    /// The `post` property.
    public var post: Operation?
    /// The `delete` property.
    public var delete: Operation?
    /// The `options` property.
    public let options: Operation?
    /// The `head` property.
    public let head: Operation?
    /// The `patch` property.
    public var patch: Operation?
    /// The `trace` property.
    public let trace: Operation?
    /// The `query` property.
    public let query: Operation?
    /// The `additionalOperations` property.
    public let additionalOperations: [String: Operation]?
    /// The `servers` property.
    public let servers: [Server]?
    /// The `parameters` property.
    public let parameters: [Parameter]?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `Operation` property.
public struct Operation: Codable, Equatable {
    /// The `tags` property.
    public let tags: [String]?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `externalDocs` property.
    public let externalDocs: ExternalDocumentation?
    /// The `operationId` property.
    public let operationId: String?
    /// The `parameters` property.
    public let parameters: [Parameter]?
    /// The `requestBody` property.
    public let requestBody: RequestBody?
    /// The `responses` property.
    public let responses: [String: Response]?
    /// The `callbacks` property.
    public let callbacks: [String: Callback]?
    /// The `deprecated` property.
    public let deprecated: Bool?
    /// The `security` property.
    public let security: [SecurityRequirement]?
    /// The `servers` property.
    public let servers: [Server]?

    /// The `initializer` property.
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

/// The `ExternalDocumentation` property.
public struct ExternalDocumentation: Codable, Equatable {
    /// The `description` property.
    public let description: String?
    /// The `url` property.
    public let url: String

    /// The `initializer` property.
    public init(description: String? = nil, url: String) {
        self.description = description
        self.url = url
    }
}

// MARK: - Parameter Object

/// The `Parameter` property.
public struct Parameter: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `name` property.
    public let name: String?
    /// The `in` property.
    public let `in`: String?
    /// The `description` property.
    public let description: String?
    /// The `required` property.
    public let required: Bool?
    /// The `deprecated` property.
    public let deprecated: Bool?
    /// The `allowEmptyValue` property.
    public let allowEmptyValue: Bool?
    /// The `style` property.
    public let style: String?
    /// The `explode` property.
    public let explode: Bool?
    /// The `allowReserved` property.
    public let allowReserved: Bool?
    /// The `schema` property.
    public let schema: Schema?
    /// The `example` property.
    public let example: AnyCodable?
    /// The `examples` property.
    public let examples: [String: Example]?
    /// The `content` property.
    public let content: [String: MediaType]?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `RequestBody` property.
public struct RequestBody: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `content` property.
    public let content: [String: MediaType]?
    /// The `required` property.
    public let required: Bool?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case content
        case required
    }

    /// The `initializer` property.
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, content: [String: MediaType]? = nil, required: Bool? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.content = content
        self.required = required
    }
}

// MARK: - Media Type Object

/// The `MediaType` property.
public struct MediaType: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `schema` property.
    public let schema: Schema?
    /// The `itemSchema` property.
    public let itemSchema: Schema?
    /// The `example` property.
    public let example: AnyCodable?
    /// The `examples` property.
    public let examples: [String: Example]?
    /// The `encoding` property.
    public let encoding: [String: EncodingObject]?
    /// The `prefixEncoding` property.
    public let prefixEncoding: [EncodingObject]?
    /// The `itemEncoding` property.
    public let itemEncoding: EncodingObject?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `EncodingObject` property.
public final class EncodingObject: Codable, Equatable {
    /// The `contentType` property.
    public let contentType: String?
    /// The `headers` property.
    public let headers: [String: Header]?
    /// The `encoding` property.
    public let encoding: [String: EncodingObject]?
    /// The `prefixEncoding` property.
    public let prefixEncoding: [EncodingObject]?
    /// The `itemEncoding` property.
    public let itemEncoding: EncodingObject?
    /// The `style` property.
    public let style: String?
    /// The `explode` property.
    public let explode: Bool?
    /// The `allowReserved` property.
    public let allowReserved: Bool?

    /// The `initializer` property.
    public init(contentType: String? = nil, headers: [String: Header]? = nil, encoding: [String: EncodingObject]? = nil, prefixEncoding: [EncodingObject]? = nil, itemEncoding: EncodingObject? = nil, style: String? = nil, explode: Bool? = nil, allowReserved: Bool? = nil) {
        self.contentType = contentType
        self.headers = headers
        self.encoding = encoding
        self.prefixEncoding = prefixEncoding
        self.itemEncoding = itemEncoding
        self.style = style
        self.explode = explode
        self.allowReserved = allowReserved
    }

    public static func == (lhs: EncodingObject, rhs: EncodingObject) -> Bool {
        return lhs.contentType == rhs.contentType && lhs.headers == rhs.headers && lhs.encoding == rhs.encoding && lhs.prefixEncoding == rhs.prefixEncoding && lhs.itemEncoding == rhs.itemEncoding && lhs.style == rhs.style && lhs.explode == rhs.explode && lhs.allowReserved == rhs.allowReserved
    }
}

// MARK: - Response Object

/// The `Response` property.
public struct Response: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `headers` property.
    public let headers: [String: Header]?
    /// The `content` property.
    public let content: [String: MediaType]?
    /// The `links` property.
    public let links: [String: Link]?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case headers
        case content
        case links
    }

    /// The `initializer` property.
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

/// The `Callback` property.
public typealias Callback = [String: PathItem]

// MARK: - Example Object

/// The `Example` property.
public struct Example: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `dataValue` property.
    public let dataValue: AnyCodable?
    /// The `serializedValue` property.
    public let serializedValue: String?
    /// The `value` property.
    public let value: AnyCodable?
    /// The `externalValue` property.
    public let externalValue: String?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case dataValue
        case serializedValue
        case value
        case externalValue
    }

    /// The `initializer` property.
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, dataValue: AnyCodable? = nil, serializedValue: String? = nil, value: AnyCodable? = nil, externalValue: String? = nil) {
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

/// The `Link` property.
public struct Link: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `operationRef` property.
    public let operationRef: String?
    /// The `operationId` property.
    public let operationId: String?
    /// The `parameters` property.
    public let parameters: [String: AnyCodable]?
    /// The `requestBody` property.
    public let requestBody: AnyCodable?
    /// The `description` property.
    public let description: String?
    /// The `server` property.
    public let server: Server?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `Header` property.
public struct Header: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?
    /// The `required` property.
    public let required: Bool?
    /// The `deprecated` property.
    public let deprecated: Bool?
    /// The `allowEmptyValue` property.
    public let allowEmptyValue: Bool?
    /// The `style` property.
    public let style: String?
    /// The `explode` property.
    public let explode: Bool?
    /// The `allowReserved` property.
    public let allowReserved: Bool?
    /// The `schema` property.
    public let schema: Schema?
    /// The `example` property.
    public let example: AnyCodable?
    /// The `examples` property.
    public let examples: [String: Example]?
    /// The `content` property.
    public let content: [String: MediaType]?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `Tag` property.
public struct Tag: Codable, Equatable {
    /// The `name` property.
    public let name: String
    /// The `description` property.
    public let description: String?
    /// The `summary` property.
    public let summary: String?
    /// The `parent` property.
    public let parent: String?
    /// The `kind` property.
    public let kind: String?
    /// The `externalDocs` property.
    public let externalDocs: ExternalDocumentation?

    /// The `initializer` property.
    public init(name: String, description: String? = nil, summary: String? = nil, parent: String? = nil, kind: String? = nil, externalDocs: ExternalDocumentation? = nil) {
        self.name = name
        self.description = description
        self.summary = summary
        self.parent = parent
        self.kind = kind
        self.externalDocs = externalDocs
    }
}

// MARK: - Security Requirement Object

/// The `SecurityRequirement` property.
public typealias SecurityRequirement = [String: [String]]

// MARK: - Security Scheme Object

/// The `SecurityScheme` property.
public struct SecurityScheme: Codable, Equatable {
    /// The `ref` property.
    public let ref: String?
    /// The `summary` property.
    public let summary: String?
    /// The `type` property.
    public let type: String?
    /// The `description` property.
    public let description: String?
    /// The `name` property.
    public let name: String?
    /// The `in` property.
    public let `in`: String?
    /// The `scheme` property.
    public let scheme: String?
    /// The `bearerFormat` property.
    public let bearerFormat: String?
    /// The `flows` property.
    public let flows: OAuthFlows?
    /// The `openIdConnectUrl` property.
    public let openIdConnectUrl: String?
    /// The `oauth2MetadataUrl` property.
    public let oauth2MetadataUrl: String?
    /// The `deprecated` property.
    public let deprecated: Bool?

    /// The `CodingKeys` property.
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
        case deprecated
    }

    /// The `initializer` property.
    public init(ref: String? = nil, summary: String? = nil, type: String? = nil, description: String? = nil, name: String? = nil, in location: String? = nil, scheme: String? = nil, bearerFormat: String? = nil, flows: OAuthFlows? = nil, openIdConnectUrl: String? = nil, oauth2MetadataUrl: String? = nil, deprecated: Bool? = nil) {
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

/// The `OAuthFlows` property.
public struct OAuthFlows: Codable, Equatable {
    /// The `implicit` property.
    public let implicit: OAuthFlow?
    /// The `password` property.
    public let password: OAuthFlow?
    /// The `clientCredentials` property.
    public let clientCredentials: OAuthFlow?
    /// The `authorizationCode` property.
    public let authorizationCode: OAuthFlow?
    /// The `deviceAuthorization` property.
    public let deviceAuthorization: OAuthFlow?

    /// The `initializer` property.
    public init(implicit: OAuthFlow? = nil, password: OAuthFlow? = nil, clientCredentials: OAuthFlow? = nil, authorizationCode: OAuthFlow? = nil, deviceAuthorization: OAuthFlow? = nil) {
        self.implicit = implicit
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
        self.deviceAuthorization = deviceAuthorization
    }
}

// MARK: - OAuth Flow Object

/// The `OAuthFlow` property.
public struct OAuthFlow: Codable, Equatable {
    /// The `authorizationUrl` property.
    public let authorizationUrl: String?
    /// The `tokenUrl` property.
    public let tokenUrl: String?
    /// The `refreshUrl` property.
    public let refreshUrl: String?
    /// The `deviceAuthorizationUrl` property.
    public let deviceAuthorizationUrl: String?
    /// The `scopes` property.
    public let scopes: [String: String]?

    /// The `initializer` property.
    public init(authorizationUrl: String? = nil, tokenUrl: String? = nil, refreshUrl: String? = nil, deviceAuthorizationUrl: String? = nil, scopes: [String: String]? = nil) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.scopes = scopes
    }
}

// MARK: - Schema Object

/// The `Schema` property.
public struct Schema: Codable, Equatable {
    // Basic types
    /// The `type` property.
    public let type: String?
    /// The `properties` property.
    public let properties: [String: Schema]?
    /// The `additionalProperties` property.
    public let additionalProperties: SchemaItem?
    /// The `items` property.
    public let items: SchemaItem?
    /// The `prefixItems` property.
    public let prefixItems: [Schema]?
    /// The `required` property.
    public let required: [String]?
    /// The `ref` property.
    public let ref: String?

    // JSON Schema metadata and validation keywords
    /// The `title` property.
    public let title: String?
    /// The `description` property.
    public let description: String?
    /// The `format` property.
    public let format: String?
    /// The `default_value` property.
    public let default_value: AnyCodable?
    /// The `const_value` property.
    public let const_value: AnyCodable?

    /// The `multipleOf` property.
    public let multipleOf: Double?
    /// The `maximum` property.
    public let maximum: Double?
    /// The `exclusiveMaximum` property.
    public let exclusiveMaximum: Double?
    /// The `minimum` property.
    public let minimum: Double?
    /// The `exclusiveMinimum` property.
    public let exclusiveMinimum: Double?

    /// The `maxLength` property.
    public let maxLength: Int?
    /// The `minLength` property.
    public let minLength: Int?
    /// The `pattern` property.
    public let pattern: String?

    /// The `maxItems` property.
    public let maxItems: Int?
    /// The `minItems` property.
    public let minItems: Int?
    /// The `uniqueItems` property.
    public let uniqueItems: Bool?
    /// The `contains` property.
    public let contains: SchemaItem?
    /// The `minContains` property.
    public let minContains: Int?
    /// The `maxContains` property.
    public let maxContains: Int?

    /// The `maxProperties` property.
    public let maxProperties: Int?
    /// The `minProperties` property.
    public let minProperties: Int?
    /// The `dependentRequired` property.
    public let dependentRequired: [String: [String]]?
    /// The `dependentSchemas` property.
    public let dependentSchemas: [String: Schema]?
    /// The `propertyNames` property.
    public let propertyNames: SchemaItem?
    /// The `patternProperties` property.
    public let patternProperties: [String: Schema]?
    /// The `unevaluatedItems` property.
    public let unevaluatedItems: SchemaItem?
    /// The `unevaluatedProperties` property.
    public let unevaluatedProperties: SchemaItem?

    /// The `enum_values` property.
    public let enum_values: [AnyCodable]?

    // Media type and content encoding
    /// The `contentEncoding` property.
    public let contentEncoding: String?
    /// The `contentMediaType` property.
    public let contentMediaType: String?
    /// The `contentSchema` property.
    public let contentSchema: SchemaItem?

    // Polymorphism
    /// The `allOf` property.
    public let allOf: [Schema]?
    /// The `oneOf` property.
    public let oneOf: [Schema]?
    /// The `anyOf` property.
    public let anyOf: [Schema]?
    /// The `not` property.
    public let not: SchemaItem?

    /// The `if_schema` property.
    public let if_schema: SchemaItem?
    /// The `then_schema` property.
    public let then_schema: SchemaItem?
    /// The `else_schema` property.
    public let else_schema: SchemaItem?

    // Identifiers and Dialects
    /// The `id` property.
    public let id: String?
    /// The `anchor` property.
    public let anchor: String?
    /// The `dynamicAnchor` property.
    public let dynamicAnchor: String?
    /// The `vocabulary` property.
    public let vocabulary: [String: Bool]?
    /// The `dynamicRef` property.
    public let dynamicRef: String?
    /// The `defs` property.
    public let defs: [String: Schema]?

    // OpenAPI specific
    /// The `discriminator` property.
    public let discriminator: Discriminator?
    /// The `xml` property.
    public let xml: XML?
    /// The `externalDocs` property.
    public let externalDocs: ExternalDocumentation?
    /// The `example` property.
    public let example: AnyCodable?
    /// The `deprecated` property.
    public let deprecated: Bool?
    /// The `readOnly` property.
    public let readOnly: Bool?
    /// The `writeOnly` property.
    public let writeOnly: Bool?

    /// The `CodingKeys` property.
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

    /// The `initializer` property.
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

/// The `Discriminator` property.
public struct Discriminator: Codable, Equatable {
    /// The `propertyName` property.
    public let propertyName: String
    /// The `mapping` property.
    public let mapping: [String: String]?
    /// The `defaultMapping` property.
    public let defaultMapping: String?

    /// The `initializer` property.
    public init(propertyName: String, mapping: [String: String]? = nil, defaultMapping: String? = nil) {
        self.propertyName = propertyName
        self.mapping = mapping
        self.defaultMapping = defaultMapping
    }
}

// MARK: - XML Object

/// The `XML` property.
public struct XML: Codable, Equatable {
    /// The `name` property.
    public let name: String?
    /// The `namespace` property.
    public let namespace: String?
    /// The `prefix` property.
    public let prefix: String?
    /// The `attribute` property.
    public let attribute: Bool?
    /// The `wrapped` property.
    public let wrapped: Bool?
    /// The `nodeType` property.
    public let nodeType: String?

    /// The `initializer` property.
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

/// The `SchemaItem` property.
public struct SchemaItem: Codable, Equatable {
    /// The `type` property.
    public let type: String?
    /// The `ref` property.
    public let ref: String?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case type
        case ref = "$ref"
    }

    /// The `initializer` property.
    public init(type: String? = nil, ref: String? = nil) {
        self.type = type
        self.ref = ref
    }
}

// MARK: - Paths Object

/// The `Paths` property.
public typealias Paths = [String: PathItem]

// MARK: - Responses Object

/// The `Responses` property.
public typealias Responses = [String: Response]

// MARK: - Reference Object

/// The `Reference` property.
public struct Reference: Codable, Equatable {
    /// The `ref` property.
    public let ref: String
    /// The `summary` property.
    public let summary: String?
    /// The `description` property.
    public let description: String?

    /// The `CodingKeys` property.
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
    }

    public init(ref: String, summary: String? = nil, description: String? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
    }
}
