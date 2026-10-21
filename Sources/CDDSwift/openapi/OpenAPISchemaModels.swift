/// OpenAPI 3.2.0 and JSON Schema Draft 2020-12 `Schema` model.
import Foundation

// MARK: - Schema Object

/// Defines the input and output data types in an OpenAPI 3.2.0 or Swagger 2.0 specification.
public struct Schema: Codable, Equatable, Sendable {
    /// Primary JSON Schema data type (`"string"`, `"number"`, `"integer"`, `"boolean"`, `"array"`, `"object"`, `"null"`).
    public let type: String?
    /// Child property schemas keyed by property name for `"object"` schemas.
    public let properties: [String: Schema]?
    /// Schema describing additional dynamic dictionary properties on an `"object"` schema.
    public let additionalProperties: SchemaItem?
    /// Schema describing the elements of an `"array"` schema.
    public let items: SchemaItem?
    /// Positional schemas for tuple validation in an `"array"` schema.
    public let prefixItems: [Schema]?
    /// Names of properties that must be present on an `"object"` instance.
    public let required: [String]?
    /// `$ref` URI reference pointing to a reusable schema definition.
    public let ref: String?
    /// Short human-readable title of the schema.
    public let title: String?
    /// CommonMark-compatible explanation of the purpose of the schema.
    public let description: String?
    /// Fine-grained data format modifier (e.g. `"int32"`, `"int64"`, `"float"`, `"double"`, `"date-time"`, `"uuid"`, `"binary"`).
    public let format: String?
    /// Default value used when an instance property is omitted.
    public let default_value: AnyCodable?
    /// Exact constant value that an instance must equal.
    public let const_value: AnyCodable?
    /// Numeric division constraint requiring the value to be an exact multiple.
    public let multipleOf: Double?
    /// Inclusive upper numeric bound.
    public let maximum: Double?
    /// Exclusive upper numeric bound.
    public let exclusiveMaximum: Double?
    /// Inclusive lower numeric bound.
    public let minimum: Double?
    /// Exclusive lower numeric bound.
    public let exclusiveMinimum: Double?
    /// Maximum character length for a string instance.
    public let maxLength: Int?
    /// Minimum character length for a string instance.
    public let minLength: Int?
    /// ECMA-262 regular expression pattern that a string instance must match.
    public let pattern: String?
    /// Maximum number of elements allowed in an array instance.
    public let maxItems: Int?
    /// Minimum number of elements required in an array instance.
    public let minItems: Int?
    /// Whether all elements in an array instance must be distinct.
    public let uniqueItems: Bool?
    /// Schema that at least one element of an array instance must validate against.
    public let contains: SchemaItem?
    /// Minimum number of array elements that must match `contains`.
    public let minContains: Int?
    /// Maximum number of array elements that may match `contains`.
    public let maxContains: Int?
    /// Maximum number of properties allowed on an object instance.
    public let maxProperties: Int?
    /// Minimum number of properties required on an object instance.
    public let minProperties: Int?
    /// Map of property names to arrays of additional required properties when the key property is present.
    public let dependentRequired: [String: [String]]?
    /// Map of property names to schemas that must validate when the key property is present.
    public let dependentSchemas: [String: Schema]?
    /// Schema that all property names on an object must match.
    public let propertyNames: SchemaItem?
    /// Map of regex patterns to schemas applied to matching property names.
    public let patternProperties: [String: Schema]?
    /// Schema applied to array items not covered by `items` or `prefixItems`.
    public let unevaluatedItems: SchemaItem?
    /// Schema applied to object properties not covered by `properties` or `patternProperties`.
    public let unevaluatedProperties: SchemaItem?
    /// Closed set of allowed values for an instance.
    public let enum_values: [AnyCodable]?
    /// Content transfer encoding for string-encoded binary data (e.g. `"base64"`, `"base64url"`).
    public let contentEncoding: String?
    /// MIME media type of string-encoded content (e.g. `"application/json"`).
    public let contentMediaType: String?
    /// Schema describing the structure of decoded `contentMediaType` data.
    public let contentSchema: SchemaItem?
    /// List of subschemas that an instance must validate against simultaneously (`allOf`).
    public let allOf: [Schema]?
    /// List of subschemas of which an instance must validate against exactly one (`oneOf`).
    public let oneOf: [Schema]?
    /// List of subschemas of which an instance must validate against at least one (`anyOf`).
    public let anyOf: [Schema]?
    /// Subschema that an instance must NOT validate against (`not`).
    public let not: SchemaItem?
    /// Conditional `if` schema evaluation guard.
    public let if_schema: SchemaItem?
    /// Subschema applied when `if_schema` succeeds (`then`).
    public let then_schema: SchemaItem?
    /// Subschema applied when `if_schema` fails (`else`).
    public let else_schema: SchemaItem?
    /// Canonical `$id` URI for this schema resource.
    public let id: String?
    /// Plain-name fragment `$anchor` identifier.
    public let anchor: String?
    /// Dynamic fragment `$dynamicAnchor` identifier.
    public let dynamicAnchor: String?
    /// Map of JSON Schema `$vocabulary` URIs to boolean requirement flags.
    public let vocabulary: [String: Bool]?
    /// Dynamic `$dynamicRef` URI reference.
    public let dynamicRef: String?
    /// Local reusable schema definitions (`$defs`).
    public let defs: [String: Schema]?
    /// Polymorphism discriminator object for `oneOf` / `anyOf` / `allOf` hierarchies.
    public let discriminator: Discriminator?
    /// XML serialization metadata for this schema.
    public let xml: XML?
    /// Additional external documentation for this schema.
    public let externalDocs: ExternalDocumentation?
    /// Example value for this schema.
    public let example: AnyCodable?
    /// Declares that this schema is deprecated.
    public let deprecated: Bool?
    /// Declares that the property is returned in responses but must not be sent in requests.
    public let readOnly: Bool?
    /// Declares that the property may be sent in requests but is never returned in responses.
    public let writeOnly: Bool?

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

    /// Coding keys mapping JSON Schema and OpenAPI keywords to `Schema` fields.
    enum CodingKeys: String, CodingKey {
        /// Key for `type`.
        case type
        /// Key for `properties`.
        case properties
        /// Key for `additionalProperties`.
        case additionalProperties
        /// Key for `items`.
        case items
        /// Key for `prefixItems`.
        case prefixItems
        /// Key for `required`.
        case required
        /// Key for `$ref`.
        case ref = "$ref"
        /// Key for `title`.
        case title
        /// Key for `description`.
        case description
        /// Key for `format`.
        case format
        /// Key for `default`.
        case default_value = "default"
        /// Key for `const`.
        case const_value = "const"
        /// Key for `multipleOf`.
        case multipleOf
        /// Key for `maximum`.
        case maximum
        /// Key for `exclusiveMaximum`.
        case exclusiveMaximum
        /// Key for `minimum`.
        case minimum
        /// Key for `exclusiveMinimum`.
        case exclusiveMinimum
        /// Key for `maxLength`.
        case maxLength
        /// Key for `minLength`.
        case minLength
        /// Key for `pattern`.
        case pattern
        /// Key for `maxItems`.
        case maxItems
        /// Key for `minItems`.
        case minItems
        /// Key for `uniqueItems`.
        case uniqueItems
        /// Key for `contains`.
        case contains
        /// Key for `minContains`.
        case minContains
        /// Key for `maxContains`.
        case maxContains
        /// Key for `maxProperties`.
        case maxProperties
        /// Key for `minProperties`.
        case minProperties
        /// Key for `dependentRequired`.
        case dependentRequired
        /// Key for `dependentSchemas`.
        case dependentSchemas
        /// Key for `propertyNames`.
        case propertyNames
        /// Key for `patternProperties`.
        case patternProperties
        /// Key for `unevaluatedItems`.
        case unevaluatedItems
        /// Key for `unevaluatedProperties`.
        case unevaluatedProperties
        /// Key for `enum`.
        case enum_values = "enum"
        /// Key for `contentEncoding`.
        case contentEncoding
        /// Key for `contentMediaType`.
        case contentMediaType
        /// Key for `contentSchema`.
        case contentSchema
        /// Key for `allOf`.
        case allOf
        /// Key for `oneOf`.
        case oneOf
        /// Key for `anyOf`.
        case anyOf
        /// Key for `not`.
        case not
        /// Key for `if`.
        case if_schema = "if"
        /// Key for `then`.
        case then_schema = "then"
        /// Key for `else`.
        case else_schema = "else"
        /// Key for `$id`.
        case id = "$id"
        /// Key for `$anchor`.
        case anchor = "$anchor"
        /// Key for `$dynamicAnchor`.
        case dynamicAnchor
        /// Key for `$vocabulary`.
        case vocabulary = "$vocabulary"
        /// Key for `$dynamicRef`.
        case dynamicRef = "$dynamicRef"
        /// Key for `$defs`.
        case defs = "$defs"
        /// Key for `discriminator`.
        case discriminator
        /// Key for `xml`.
        case xml
        /// Key for `externalDocs`.
        case externalDocs
        /// Key for `example`.
        case example
        /// Key for `deprecated`.
        case deprecated
        /// Key for `readOnly`.
        case readOnly
        /// Key for `writeOnly`.
        case writeOnly
    }

    /// Initializes a `Schema` definition.
    ///
    /// - Parameters:
    ///   - type: Primary JSON Schema type name.
    ///   - properties: Object property map.
    ///   - additionalProperties: Dynamic dictionary value schema.
    ///   - items: Array element schema item.
    ///   - prefixItems: Tuple positional schemas.
    ///   - required: Required object property names.
    ///   - ref: `$ref` pointer string.
    ///   - title: Optional schema title.
    ///   - description: Optional schema description.
    ///   - format: Optional data format hint.
    ///   - default_value: Optional default value.
    ///   - const_value: Optional constant value.
    ///   - multipleOf: Optional numeric multipleOf constraint.
    ///   - maximum: Optional inclusive maximum.
    ///   - exclusiveMaximum: Optional exclusive maximum.
    ///   - minimum: Optional inclusive minimum.
    ///   - exclusiveMinimum: Optional exclusive minimum.
    ///   - maxLength: Optional maximum string length.
    ///   - minLength: Optional minimum string length.
    ///   - pattern: Optional regex pattern string.
    ///   - maxItems: Optional maximum array length.
    ///   - minItems: Optional minimum array length.
    ///   - uniqueItems: Optional unique array elements flag.
    ///   - contains: Optional `contains` schema item.
    ///   - minContains: Optional minimum `contains` matches.
    ///   - maxContains: Optional maximum `contains` matches.
    ///   - maxProperties: Optional maximum object property count.
    ///   - minProperties: Optional minimum object property count.
    ///   - dependentRequired: Optional dependent required properties map.
    ///   - dependentSchemas: Optional dependent schemas map.
    ///   - propertyNames: Optional property name validation schema.
    ///   - patternProperties: Optional regex-keyed property schemas.
    ///   - unevaluatedItems: Optional unevaluated array items schema.
    ///   - unevaluatedProperties: Optional unevaluated object properties schema.
    ///   - enum_values: Optional list of allowed enum values.
    ///   - contentEncoding: Optional content transfer encoding.
    ///   - contentMediaType: Optional content MIME type.
    ///   - contentSchema: Optional decoded content schema.
    ///   - allOf: Optional `allOf` subschemas.
    ///   - oneOf: Optional `oneOf` subschemas.
    ///   - anyOf: Optional `anyOf` subschemas.
    ///   - not: Optional negated `not` schema item.
    ///   - if_schema: Optional conditional `if` schema item.
    ///   - then_schema: Optional conditional `then` schema item.
    ///   - else_schema: Optional conditional `else` schema item.
    ///   - id: Optional `$id` URI.
    ///   - anchor: Optional `$anchor` string.
    ///   - dynamicAnchor: Optional `$dynamicAnchor` string.
    ///   - vocabulary: Optional `$vocabulary` map.
    ///   - dynamicRef: Optional `$dynamicRef` string.
    ///   - defs: Optional local `$defs` map.
    ///   - discriminator: Optional polymorphism `Discriminator`.
    ///   - xml: Optional `XML` metadata.
    ///   - externalDocs: Optional `ExternalDocumentation`.
    ///   - example: Optional example value.
    ///   - deprecated: Optional deprecation flag.
    ///   - readOnly: Optional read-only flag.
    ///   - writeOnly: Optional write-only flag.
    public init(
        type: String? = nil, properties: [String: Schema]? = nil, additionalProperties: SchemaItem? = nil, items: SchemaItem? = nil,
        prefixItems: [Schema]? = nil, required: [String]? = nil, ref: String? = nil,
        title: String? = nil, description: String? = nil, format: String? = nil, default_value: AnyCodable? = nil,
        const_value: AnyCodable? = nil,
        multipleOf: Double? = nil, maximum: Double? = nil, exclusiveMaximum: Double? = nil, minimum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        maxLength: Int? = nil, minLength: Int? = nil, pattern: String? = nil,
        maxItems: Int? = nil, minItems: Int? = nil, uniqueItems: Bool? = nil, contains: SchemaItem? = nil, minContains: Int? = nil,
        maxContains: Int? = nil,
        maxProperties: Int? = nil, minProperties: Int? = nil, dependentRequired: [String: [String]]? = nil,
        dependentSchemas: [String: Schema]? = nil, propertyNames: SchemaItem? = nil, patternProperties: [String: Schema]? = nil,
        unevaluatedItems: SchemaItem? = nil, unevaluatedProperties: SchemaItem? = nil,
        enum_values: [AnyCodable]? = nil,
        contentEncoding: String? = nil, contentMediaType: String? = nil, contentSchema: SchemaItem? = nil,
        allOf: [Schema]? = nil, oneOf: [Schema]? = nil, anyOf: [Schema]? = nil, not: SchemaItem? = nil,
        if_schema: SchemaItem? = nil, then_schema: SchemaItem? = nil, else_schema: SchemaItem? = nil,
        id: String? = nil, anchor: String? = nil, dynamicAnchor: String? = nil, vocabulary: [String: Bool]? = nil,
        dynamicRef: String? = nil, defs: [String: Schema]? = nil,
        discriminator: Discriminator? = nil, xml: XML? = nil, externalDocs: ExternalDocumentation? = nil, example: AnyCodable? = nil,
        deprecated: Bool? = nil, readOnly: Bool? = nil, writeOnly: Bool? = nil
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

public extension Schema {
    /// Returns a copy of this `Schema` with updated description and/or validation constraints while preserving all other fields.
    ///
    /// - Parameters:
    ///   - description: New description override, or `nil` to retain existing `self.description`.
    ///   - minimum: New inclusive minimum override, or `nil` to retain existing `self.minimum`.
    ///   - maximum: New inclusive maximum override, or `nil` to retain existing `self.maximum`.
    ///   - minLength: New minimum string length override, or `nil` to retain existing `self.minLength`.
    ///   - maxLength: New maximum string length override, or `nil` to retain existing `self.maxLength`.
    ///   - pattern: New regex pattern override, or `nil` to retain existing `self.pattern`.
    /// - Returns: A new `Schema` instance with the specified overrides applied.
    func updating(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) -> Schema {
        return Schema(
            type: type, properties: properties, additionalProperties: additionalProperties, items: items,
            prefixItems: prefixItems, required: required, ref: ref, title: title,
            description: description ?? self.description, format: format, default_value: default_value, const_value: const_value,
            multipleOf: multipleOf, maximum: maximum ?? self.maximum, exclusiveMaximum: exclusiveMaximum,
            minimum: minimum ?? self.minimum, exclusiveMinimum: exclusiveMinimum,
            maxLength: maxLength ?? self.maxLength, minLength: minLength ?? self.minLength, pattern: pattern ?? self.pattern,
            maxItems: maxItems, minItems: minItems, uniqueItems: uniqueItems, contains: contains,
            minContains: minContains, maxContains: maxContains,
            maxProperties: maxProperties, minProperties: minProperties, dependentRequired: dependentRequired,
            dependentSchemas: dependentSchemas, propertyNames: propertyNames, patternProperties: patternProperties,
            unevaluatedItems: unevaluatedItems, unevaluatedProperties: unevaluatedProperties, enum_values: enum_values,
            contentEncoding: contentEncoding, contentMediaType: contentMediaType, contentSchema: contentSchema,
            allOf: allOf, oneOf: oneOf, anyOf: anyOf, not: not,
            if_schema: if_schema, then_schema: then_schema, else_schema: else_schema,
            id: id, anchor: anchor, dynamicAnchor: dynamicAnchor, vocabulary: vocabulary, dynamicRef: dynamicRef, defs: defs,
            discriminator: discriminator, xml: xml, externalDocs: externalDocs, example: example,
            deprecated: deprecated, readOnly: readOnly, writeOnly: writeOnly
        )
    }
}
