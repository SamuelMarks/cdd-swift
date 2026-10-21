/// Swift model, enum, and typealias code emitter for OpenAPI schemas.
import Foundation

/// Describes a resolved schema property used during Swift struct emission.
private struct ModelPropertyDescriptor {
    /// The property identifier name.
    let name: String
    /// The OpenAPI schema defining the property's type and constraints.
    let schema: Schema
    /// Indicates whether the property is required on the parent schema.
    let isRequired: Bool
}

/// Emits Swift models from OpenAPI schemas.
///
/// - Parameters:
///   - name: The PascalCase model name.
///   - schema: The OpenAPI `Schema` to render as a Swift struct, enum, or typealias.
///   - schemas: Optional dictionary of all component schemas used to resolve `$ref` inheritance in `allOf`.
/// - Returns: Generated Swift source code for the model.
public func emitModel(name: String, schema: Schema, schemas: [String: Schema] = [:]) -> String {
    var output = emitDocstring(schema.description, indent: 0)
    output += emitValidationDocComments(for: schema, indent: 0)

    if schema.type == "string" && schema.enum_values != nil {
        return output + emitStringEnumModel(name: name, schema: schema)
    }

    if isTypealiasSchema(schema) {
        let swiftType = mapType(schema: schema)
        return output + "public typealias \(name) = \(swiftType)\n"
    }

    if let options = schema.anyOf ?? schema.oneOf {
        return output + emitUnionEnumModel(name: name, schema: schema, options: options)
    }

    return output + emitObjectStructModel(name: name, schema: schema, schemas: schemas)
}

/// Checks whether a schema should be emitted as a top-level `public typealias`.
///
/// - Parameter schema: The OpenAPI `Schema` to inspect.
/// - Returns: `true` if the schema represents a primitive, array, or dictionary typealias.
private func isTypealiasSchema(_ schema: Schema) -> Bool {
    let primitiveTypes: Set<String?> = ["array", "string", "integer", "number", "boolean"]
    if primitiveTypes.contains(schema.type) {
        return true
    }
    return schema.type == "object" && schema.properties == nil && schema.additionalProperties != nil
}

/// Emits validation constraint lines (`Minimum`, `Maximum`, `Minimum Length`, `Maximum Length`, `Pattern`) as doc comments.
///
/// - Parameters:
///   - schema: The OpenAPI `Schema` containing validation keywords.
///   - indent: Number of leading spaces before `///`.
/// - Returns: Formatted doc comment lines.
private func emitValidationDocComments(for schema: Schema, indent: Int) -> String {
    let prefix = String(repeating: " ", count: indent)
    var validationDocs: [String] = []
    if let min = schema.minimum {
        validationDocs.append("Minimum: \(min)")
    }
    if let max = schema.maximum {
        validationDocs.append("Maximum: \(max)")
    }
    if let minLen = schema.minLength {
        validationDocs.append("Minimum Length: \(minLen)")
    }
    if let maxLen = schema.maxLength {
        validationDocs.append("Maximum Length: \(maxLen)")
    }
    if let pattern = schema.pattern {
        validationDocs.append("Pattern: \(pattern)")
    }
    return validationDocs.map { "\(prefix)/// - \($0)\n" }.joined()
}

/// Emits property wrapper attributes (`@Minimum`, `@Maximum`, `@MinLength`, `@MaxLength`, `@Pattern`) for a struct property.
///
/// - Parameter propSchema: The property's OpenAPI `Schema`.
/// - Returns: Formatted property wrapper lines indented by 4 spaces.
private func emitPropertyWrappers(for propSchema: Schema) -> String {
    var wrappers: [String] = []
    if let min = propSchema.minimum {
        wrappers.append("@Minimum(\(min))")
    }
    if let max = propSchema.maximum {
        wrappers.append("@Maximum(\(max))")
    }
    if let minLen = propSchema.minLength {
        wrappers.append("@MinLength(\(minLen))")
    }
    if let maxLen = propSchema.maxLength {
        wrappers.append("@MaxLength(\(maxLen))")
    }
    if let pattern = propSchema.pattern {
        wrappers.append("@Pattern(\"\(pattern)\")")
    }
    return wrappers.map { "    \($0)\n" }.joined()
}

/// Emits a `String`-backed `Codable` enum for an OpenAPI string schema with `enum` values.
///
/// - Parameters:
///   - name: The PascalCase enum name.
///   - schema: The OpenAPI `Schema` containing `enum_values`.
/// - Returns: Generated Swift enum declaration string.
private func emitStringEnumModel(name: String, schema: Schema) -> String {
    var output = "public enum \(name): String, Codable, Equatable, CaseIterable, Sendable {\n"
    if let enumValues = schema.enum_values {
        for val in enumValues {
            if let strVal = val.stringValue {
                let sanitized = SwiftIdentifierSanitizer.sanitizeCamelCase(
                    strVal.replacingOccurrences(of: "-", with: "_").lowercased(),
                    fallback: "value"
                )
                output += "    case \(sanitized) = \"\(strVal)\"\n"
            }
        }
    }
    output += "}\n"
    return output
}

/// Emits a `Codable` enum for an OpenAPI `oneOf` or `anyOf` union schema.
///
/// - Parameters:
///   - name: The PascalCase enum name.
///   - schema: The parent OpenAPI `Schema` (inspected for `discriminator`).
///   - options: The union branch `Schema` array.
/// - Returns: Generated Swift union enum declaration string.
private func emitUnionEnumModel(name: String, schema: Schema, options: [Schema]) -> String {
    if let discriminator = schema.discriminator {
        return emitDiscriminatedUnionEnum(name: name, discriminator: discriminator, options: options)
    }
    return emitUntaggedUnionEnum(name: name, options: options)
}

/// Emits a discriminated polymorphic `Codable` enum for a union schema with a `Discriminator`.
///
/// - Parameters:
///   - name: The PascalCase enum name.
///   - discriminator: The OpenAPI `Discriminator` configuration.
///   - options: The union branch `Schema` array.
/// - Returns: Generated Swift enum declaration with discriminated `init(from:)` and `encode(to:)`.
private func emitDiscriminatedUnionEnum(name: String, discriminator: Discriminator, options: [Schema]) -> String {
    var output = "public enum \(name): Codable, Equatable, Sendable {\n"
    let propName = discriminator.propertyName
    for option in options {
        let typeName = mapType(schema: option)
        output += "    case \(typeName.lowercased())(\(typeName))\n"
    }

    output += "\n    public init(from decoder: Decoder) throws {\n"
    output += "        let container = try decoder.container(keyedBy: CodingKeys.self)\n"
    output += "        let type = try container.decode(String.self, forKey: .\(propName))\n"
    output += "        switch type {\n"
    for option in options {
        let typeName = mapType(schema: option)
        let mappingKey = discriminator.mapping?
            .first(where: { $0.value == "#/components/schemas/\(typeName)" || $0.value == "#/definitions/\(typeName)" })?
            .key ?? typeName
        output += "        case \"\(mappingKey)\":\n"
        output += "            let singleContainer = try decoder.singleValueContainer()\n"
        output += "            self = .\(typeName.lowercased())(try singleContainer.decode(\(typeName).self))\n"
    }
    output += "        default:\n"
    output += "            throw DecodingError.dataCorruptedError(forKey: .\(propName), in: container, debugDescription: \"Unknown discriminator value: \\(type)\")\n"
    output += "        }\n"
    output += "    }\n"

    output += "\n    public func encode(to encoder: Encoder) throws {\n"
    output += "        var container = encoder.singleValueContainer()\n"
    output += "        switch self {\n"
    for option in options {
        let typeName = mapType(schema: option)
        output += "        case .\(typeName.lowercased())(let value):\n"
        output += "            try container.encode(value)\n"
    }
    output += "        }\n"
    output += "    }\n"

    output += "\n    private enum CodingKeys: String, CodingKey {\n"
    output += "        case \(propName)\n"
    output += "    }\n"
    output += "}\n"
    return output
}

/// Emits an untagged `Codable` union enum using sequential single-value container decoding (`option1`, `option2`, ...).
///
/// - Parameters:
///   - name: The PascalCase enum name.
///   - options: The union branch `Schema` array.
/// - Returns: Generated Swift enum declaration string.
private func emitUntaggedUnionEnum(name: String, options: [Schema]) -> String {
    var output = "public enum \(name): Codable, Equatable, Sendable {\n"
    for (idx, option) in options.enumerated() {
        let typeName = mapType(schema: option)
        output += "    case option\(idx + 1)(\(typeName))\n"
    }

    output += "\n    public init(from decoder: Decoder) throws {\n"
    output += "        let container = try decoder.singleValueContainer()\n"
    for (idx, option) in options.enumerated() {
        let typeName = mapType(schema: option)
        output += "        if let value = try? container.decode(\(typeName).self) {\n"
        output += "            self = .option\(idx + 1)(value)\n"
        output += "            return\n"
        output += "        }\n"
    }
    output += "        throw DecodingError.typeMismatch(\(name).self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: \"Failed to decode \(name) anyOf/oneOf\"))\n"
    output += "    }\n"

    output += "\n    public func encode(to encoder: Encoder) throws {\n"
    output += "        var container = encoder.singleValueContainer()\n"
    output += "        switch self {\n"
    for idx in options.indices {
        output += "        case .option\(idx + 1)(let value):\n"
        output += "            try container.encode(value)\n"
    }
    output += "        }\n"
    output += "    }\n"
    output += "}\n"
    return output
}

/// Emits a `Codable` Swift `struct` for an object or `allOf` OpenAPI schema.
///
/// - Parameters:
///   - name: The PascalCase struct name.
///   - schema: The OpenAPI `Schema` to render.
///   - schemas: Dictionary of component schemas for resolving `allOf` references.
/// - Returns: Generated Swift struct declaration string.
private func emitObjectStructModel(name: String, schema: Schema, schemas: [String: Schema]) -> String {
    var output = "public struct \(name): Codable, Equatable, Sendable {\n"
    let sortedProps = collectStructProperties(schema: schema, schemas: schemas)

    for (propName, propData) in sortedProps {
        let propSchema = propData.0
        output += emitDocstring(propSchema.description, indent: 4)
        output += emitValidationDocComments(for: propSchema, indent: 4)
        output += emitPropertyWrappers(for: propSchema)

        let swiftType = mapType(schema: propSchema)
        let optionalSuffix = propData.1 ? "" : "?"
        output += "    public var \(propName): \(swiftType)\(optionalSuffix)\n"
    }

    if !sortedProps.isEmpty {
        output += "\n"
        let params = sortedProps.map { propName, propData -> String in
            let swiftType = mapType(schema: propData.0)
            let isRequired = propData.1
            let optionalSuffix = isRequired ? "" : "?"
            return "\(propName): \(swiftType)\(optionalSuffix)\(isRequired ? "" : " = nil")"
        }.joined(separator: ", ")

        output += "    public init(\(params)) {\n"
        for (propName, _) in sortedProps {
            output += "        self.\(propName) = \(propName)\n"
        }
        output += "    }\n"
    } else {
        output += "    public init() {}\n"
    }

    output += "}\n"
    return output
}

/// Collects and deduplicates properties from `schema.allOf` and `schema.properties`, sorted alphabetically.
///
/// - Parameters:
///   - schema: The target OpenAPI `Schema`.
///   - schemas: Component schemas dictionary for resolving `$ref` entries in `allOf`.
/// - Returns: Sorted array of `(propertyName, (Schema, isRequired))` tuples.
private func collectStructProperties(schema: Schema, schemas: [String: Schema]) -> [(key: String, value: (Schema, Bool))] {
    var allProperties: [ModelPropertyDescriptor] = []

    if let allOf = schema.allOf {
        for subSchema in allOf {
            let resolvedSub: Schema
            if let ref = subSchema.ref ?? subSchema.dynamicRef, let target = schemas[lastPathSegment(ref)] {
                resolvedSub = target
            } else {
                resolvedSub = subSchema
            }
            if let props = resolvedSub.properties {
                for (propName, propSchema) in props {
                    let isReq = resolvedSub.required?.contains(propName) ?? false
                    allProperties.append(ModelPropertyDescriptor(name: propName, schema: propSchema, isRequired: isReq))
                }
            }
        }
    }

    if let properties = schema.properties {
        for (propName, propSchema) in properties {
            let isReq = schema.required?.contains(propName) ?? false
            allProperties.append(ModelPropertyDescriptor(name: propName, schema: propSchema, isRequired: isReq))
        }
    }

    var uniquePropsMap: [String: (Schema, Bool)] = [:]
    for prop in allProperties {
        uniquePropsMap[prop.name] = (prop.schema, prop.isRequired)
    }

    return uniquePropsMap.sorted { $0.key < $1.key }
}

/// Helper mapping schema types to Swift.
///
/// - Parameter schema: The OpenAPI `Schema` to map to a Swift type string.
/// - Returns: The corresponding Swift type string.
public func mapType(schema: Schema) -> String {
    if let ref = schema.ref ?? schema.dynamicRef {
        return lastPathSegment(ref)
    }
    switch schema.type {
    case "string":
        return mapStringFormat(schema.format)
    case "integer":
        return schema.format == "int64" ? "Int64" : "Int"
    case "number":
        return schema.format == "float" ? "Float" : "Double"
    case "boolean":
        return "Bool"
    case "array":
        return mapArrayType(schema: schema)
    case "object":
        return mapObjectType(schema: schema)
    default:
        return "AnyCodable"
    }
}

/// Maps an OpenAPI `"string"` format modifier to its corresponding Swift type.
///
/// - Parameter format: Optional `OpenAPIFormat` value.
/// - Returns: `"Date"`, `"UUID"`, `"Data"`, or `"String"`.
private func mapStringFormat(_ format: String?) -> String {
    switch format {
    case "date-time": return "Date"
    case "uuid": return "UUID"
    case "binary": return "Data"
    default: return "String"
    }
}

/// Maps an OpenAPI `"array"` schema (including `prefixItems` tuples and `items`) to a Swift type string.
///
/// - Parameter schema: The array `Schema`.
/// - Returns: The mapped Swift array or tuple type string.
private func mapArrayType(schema: Schema) -> String {
    if let prefixItems = schema.prefixItems {
        let types = prefixItems.map { mapType(schema: $0) }.joined(separator: ", ")
        return "(\(types))"
    }
    if let items = schema.items {
        if let ref = items.ref {
            return "[\(lastPathSegment(ref))]"
        } else if let type = items.type {
            let primitive = Schema(type: type, format: items.format)
            return "[\(mapType(schema: primitive))]"
        }
    }
    return "[AnyCodable]"
}

/// Maps an OpenAPI `"object"` schema (with optional `additionalProperties`) to a Swift dictionary or `AnyCodable` type string.
///
/// - Parameter schema: The object `Schema`.
/// - Returns: The mapped Swift dictionary or `"AnyCodable"` type string.
private func mapObjectType(schema: Schema) -> String {
    guard let additional = schema.additionalProperties else {
        return "AnyCodable"
    }
    if let ref = additional.ref {
        return "[String: \(lastPathSegment(ref))]"
    }
    if let type = additional.type {
        let primitive = Schema(type: type, format: additional.format)
        return "[String: \(mapType(schema: primitive))]"
    }
    return "[String: AnyCodable]"
}
