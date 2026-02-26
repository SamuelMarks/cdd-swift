import Foundation

// MARK: - Root Object
/// Represents an OpenAPI Document.
public struct OpenAPIDocument: Codable, Equatable {
    public let openapi: String
    public let selfRef: String?
    public let info: Info
    public let jsonSchemaDialect: String?
    public let servers: [Server]?
    public let paths: [String: PathItem]?
    public let webhooks: [String: PathItem]?
    public let components: Components?
    public let security: [SecurityRequirement]?
    public let tags: [Tag]?
    public let externalDocs: ExternalDocumentation?
    
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
public struct Info: Codable, Equatable {
    public let title: String
    public let summary: String?
    public let description: String?
    public let termsOfService: String?
    public let contact: Contact?
    public let license: License?
    public let version: String
    
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
public struct Contact: Codable, Equatable {
    public let name: String?
    public let url: String?
    public let email: String?
    
    public init(name: String? = nil, url: String? = nil, email: String? = nil) {
        self.name = name
        self.url = url
        self.email = email
    }
}

// MARK: - License Object
public struct License: Codable, Equatable {
    public let name: String
    public let identifier: String?
    public let url: String?
    
    public init(name: String, identifier: String? = nil, url: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.url = url
    }
}

// MARK: - Server Object
public struct Server: Codable, Equatable {
    public let url: String
    public let description: String?
    public let name: String?
    public let variables: [String: ServerVariable]?
    
    public init(url: String, description: String? = nil, name: String? = nil, variables: [String: ServerVariable]? = nil) {
        self.url = url
        self.description = description
        self.name = name
        self.variables = variables
    }
}

// MARK: - Server Variable Object
public struct ServerVariable: Codable, Equatable {
    public let `enum`: [String]?
    public let `default`: String
    public let description: String?
    
    public init(enum: [String]? = nil, default: String, description: String? = nil) {
        self.enum = `enum`
        self.default = `default`
        self.description = description
    }
}

// MARK: - Components Object
public struct Components: Codable, Equatable {
    public let schemas: [String: Schema]?
    public let responses: [String: Response]?
    public let parameters: [String: Parameter]?
    public let examples: [String: Example]?
    public let requestBodies: [String: RequestBody]?
    public let headers: [String: Header]?
    public let securitySchemes: [String: SecurityScheme]?
    public let links: [String: Link]?
    public let callbacks: [String: Callback]?
    public let pathItems: [String: PathItem]?
    public let mediaTypes: [String: MediaType]?
    
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
public struct PathItem: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let description: String?
    public let get: Operation?
    public let put: Operation?
    public let post: Operation?
    public let delete: Operation?
    public let options: Operation?
    public let head: Operation?
    public let patch: Operation?
    public let trace: Operation?
    public let query: Operation?
    public let additionalOperations: [String: Operation]?
    public let servers: [Server]?
    public let parameters: [Parameter]?
    
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
public struct Operation: Codable, Equatable {
    public let tags: [String]?
    public let summary: String?
    public let description: String?
    public let externalDocs: ExternalDocumentation?
    public let operationId: String?
    public let parameters: [Parameter]?
    public let requestBody: RequestBody?
    public let responses: [String: Response]?
    public let callbacks: [String: Callback]?
    public let deprecated: Bool?
    public let security: [SecurityRequirement]?
    public let servers: [Server]?
    
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
public struct ExternalDocumentation: Codable, Equatable {
    public let description: String?
    public let url: String
    
    public init(description: String? = nil, url: String) {
        self.description = description
        self.url = url
    }
}

// MARK: - Parameter Object
public struct Parameter: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let name: String?
    public let `in`: String?
    public let description: String?
    public let required: Bool?
    public let deprecated: Bool?
    public let allowEmptyValue: Bool?
    public let style: String?
    public let explode: Bool?
    public let allowReserved: Bool?
    public let schema: Schema?
    public let example: AnyCodable?
    public let examples: [String: Example]?
    public let content: [String: MediaType]?
    
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
public struct RequestBody: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let description: String?
    public let content: [String: MediaType]?
    public let required: Bool?
    
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case content
        case required
    }
    
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, content: [String: MediaType]? = nil, required: Bool? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.content = content
        self.required = required
    }
}

// MARK: - Media Type Object
public struct MediaType: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let schema: Schema?
    public let itemSchema: Schema?
    public let example: AnyCodable?
    public let examples: [String: Example]?
    public let encoding: [String: EncodingObject]?
    public let prefixEncoding: [EncodingObject]?
    public let itemEncoding: EncodingObject?
    
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
public struct EncodingObject: Codable, Equatable {
    public let contentType: String?
    public let headers: [String: Header]?
    public let style: String?
    public let explode: Bool?
    public let allowReserved: Bool?
    
    public init(contentType: String? = nil, headers: [String: Header]? = nil, style: String? = nil, explode: Bool? = nil, allowReserved: Bool? = nil) {
        self.contentType = contentType
        self.headers = headers
        self.style = style
        self.explode = explode
        self.allowReserved = allowReserved
    }
}

// MARK: - Response Object
public struct Response: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let description: String?
    public let headers: [String: Header]?
    public let content: [String: MediaType]?
    public let links: [String: Link]?
    
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case headers
        case content
        case links
    }
    
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
public typealias Callback = [String: PathItem]

// MARK: - Example Object
public struct Example: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let description: String?
    public let value: AnyCodable?
    public let externalValue: String?
    
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case value
        case externalValue
    }
    
    public init(ref: String? = nil, summary: String? = nil, description: String? = nil, value: AnyCodable? = nil, externalValue: String? = nil) {
        self.ref = ref
        self.summary = summary
        self.description = description
        self.value = value
        self.externalValue = externalValue
    }
}

// MARK: - Link Object
public struct Link: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let operationRef: String?
    public let operationId: String?
    public let parameters: [String: AnyCodable]?
    public let requestBody: AnyCodable?
    public let description: String?
    public let server: Server?
    
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
public struct Header: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let description: String?
    public let required: Bool?
    public let deprecated: Bool?
    public let allowEmptyValue: Bool?
    public let style: String?
    public let explode: Bool?
    public let allowReserved: Bool?
    public let schema: Schema?
    public let example: AnyCodable?
    public let examples: [String: Example]?
    public let content: [String: MediaType]?
    
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
public struct Tag: Codable, Equatable {
    public let name: String
    public let description: String?
    public let externalDocs: ExternalDocumentation?
    
    public init(name: String, description: String? = nil, externalDocs: ExternalDocumentation? = nil) {
        self.name = name
        self.description = description
        self.externalDocs = externalDocs
    }
}

// MARK: - Security Requirement Object
public typealias SecurityRequirement = [String: [String]]

// MARK: - Security Scheme Object
public struct SecurityScheme: Codable, Equatable {
    public let ref: String?
    public let summary: String?
    public let type: String?
    public let description: String?
    public let name: String?
    public let `in`: String?
    public let scheme: String?
    public let bearerFormat: String?
    public let flows: OAuthFlows?
    public let openIdConnectUrl: String?
    public let oauth2MetadataUrl: String?
    
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
public struct OAuthFlows: Codable, Equatable {
    public let `implicit`: OAuthFlow?
    public let password: OAuthFlow?
    public let clientCredentials: OAuthFlow?
    public let authorizationCode: OAuthFlow?
    public let deviceAuthorization: OAuthFlow?
    
    public init(implicit: OAuthFlow? = nil, password: OAuthFlow? = nil, clientCredentials: OAuthFlow? = nil, authorizationCode: OAuthFlow? = nil, deviceAuthorization: OAuthFlow? = nil) {
        self.implicit = `implicit`
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
        self.deviceAuthorization = deviceAuthorization
    }
}

// MARK: - OAuth Flow Object
public struct OAuthFlow: Codable, Equatable {
    public let authorizationUrl: String?
    public let tokenUrl: String?
    public let refreshUrl: String?
    public let deviceAuthorizationUrl: String?
    public let scopes: [String: String]?
    
    public init(authorizationUrl: String? = nil, tokenUrl: String? = nil, refreshUrl: String? = nil, deviceAuthorizationUrl: String? = nil, scopes: [String: String]? = nil) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.scopes = scopes
    }
}

// MARK: - Schema Object
public struct Schema: Codable, Equatable {
    // Basic types
    public let type: String?
    public let properties: [String: Schema]?
    public let additionalProperties: SchemaItem?
    public let items: SchemaItem?
    public let prefixItems: [Schema]?
    public let required: [String]?
    public let ref: String?
    
    // JSON Schema metadata and validation keywords
    public let title: String?
    public let description: String?
    public let format: String?
    public let default_value: AnyCodable?
    public let const_value: AnyCodable?
    
    public let multipleOf: Double?
    public let maximum: Double?
    public let exclusiveMaximum: Double?
    public let minimum: Double?
    public let exclusiveMinimum: Double?
    
    public let maxLength: Int?
    public let minLength: Int?
    public let pattern: String?
    
    public let maxItems: Int?
    public let minItems: Int?
    public let uniqueItems: Bool?
    public let contains: SchemaItem?
    public let minContains: Int?
    public let maxContains: Int?
    
    public let maxProperties: Int?
    public let minProperties: Int?
    public let dependentRequired: [String: [String]]?
    public let dependentSchemas: [String: Schema]?
    public let propertyNames: SchemaItem?
    public let patternProperties: [String: Schema]?
    public let unevaluatedItems: SchemaItem?
    public let unevaluatedProperties: SchemaItem?
    
    public let enum_values: [AnyCodable]?
    
    // Media type and content encoding
    public let contentEncoding: String?
    public let contentMediaType: String?
    public let contentSchema: SchemaItem?
    
    // Polymorphism
    public let allOf: [Schema]?
    public let oneOf: [Schema]?
    public let anyOf: [Schema]?
    public let not: SchemaItem?
    
    public let if_schema: SchemaItem?
    public let then_schema: SchemaItem?
    public let else_schema: SchemaItem?
    
    // Identifiers and Dialects
    public let id: String?
    public let anchor: String?
    public let dynamicAnchor: String?
    public let vocabulary: [String: Bool]?
    public let dynamicRef: String?
    public let defs: [String: Schema]?
    
    // OpenAPI specific
    public let discriminator: Discriminator?
    public let xml: XML?
    public let externalDocs: ExternalDocumentation?
    public let example: AnyCodable?
    public let deprecated: Bool?
    public let readOnly: Bool?
    public let writeOnly: Bool?

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
public struct Discriminator: Codable, Equatable {
    public let propertyName: String
    public let mapping: [String: String]?
    public let defaultMapping: String?
    
    public init(propertyName: String, mapping: [String: String]? = nil, defaultMapping: String? = nil) {
        self.propertyName = propertyName
        self.mapping = mapping
        self.defaultMapping = defaultMapping
    }
}

// MARK: - XML Object
public struct XML: Codable, Equatable {
    public let name: String?
    public let namespace: String?
    public let prefix: String?
    public let attribute: Bool?
    public let wrapped: Bool?
    public let nodeType: String?
    
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
public struct SchemaItem: Codable, Equatable {
    public let type: String?
    public let ref: String?

    enum CodingKeys: String, CodingKey {
        case type
        case ref = "$ref"
    }
    
    public init(type: String? = nil, ref: String? = nil) {
        self.type = type
        self.ref = ref
    }
}
