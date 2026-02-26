import Foundation

/// Emits Swift models from OpenAPI schemas.
public func emitModel(name: String, schema: Schema) -> String {
    var output = ""
    output += emitDocstring(schema.description, indent: 0)
    
    // Process validations for docstrings
    var validationDocs: [String] = []
    if let min = schema.minimum { validationDocs.append("Minimum: \(min)") }
    if let max = schema.maximum { validationDocs.append("Maximum: \(max)") }
    if let minLen = schema.minLength { validationDocs.append("Minimum Length: \(minLen)") }
    if let maxLen = schema.maxLength { validationDocs.append("Maximum Length: \(maxLen)") }
    if let pattern = schema.pattern { validationDocs.append("Pattern: \(pattern)") }
    
    for vDoc in validationDocs {
        output += "/// - \(vDoc)\n"
    }
    
    if schema.type == "string" && schema.enum_values != nil {
        output += "public enum \(name): String, Codable, Equatable, CaseIterable {\n"
        if let enumValues = schema.enum_values {
            for val in enumValues {
                if let strVal = val.value as? String {
                    output += "    case \(strVal.replacingOccurrences(of: \"-\", with: \"_\").lowercased()) = \"\(strVal)\"\n"
                }
            }
        }
        output += "}\n"
        return output
    }
    
    if schema.anyOf != nil || schema.oneOf != nil {
         output += "public enum \\(name): Codable, Equatable {\n"
         let options = schema.anyOf ?? schema.oneOf!
         var i = 1
         
         if let discriminator = schema.discriminator {
             // Generate polymorphic enum based on discriminator
             let propName = discriminator.propertyName
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "    case \\(typeName.lowercased())(\\(typeName))\n"
             }
             
             output += "\n    public init(from decoder: Decoder) throws {\n"
             output += "        let container = try decoder.container(keyedBy: CodingKeys.self)\n"
             output += "        let type = try container.decode(String.self, forKey: .\\(propName))\n"
             output += "        switch type {\n"
             for option in options {
                 let typeName = mapType(schema: option)
                 let mappingKey = discriminator.mapping?.first(where: { $0.value == "#/components/schemas/\\(typeName)" })?.key ?? typeName
                 output += "        case \"\\(mappingKey)\":\n"
                 output += "            let singleContainer = try decoder.singleValueContainer()\n"
                 output += "            self = .\\(typeName.lowercased())(try singleContainer.decode(\\(typeName).self))\n"
             }
             output += "        default:\n"
             output += "            throw DecodingError.dataCorruptedError(forKey: .\\(propName), in: container, debugDescription: \"Unknown discriminator value: \\(type)\")\n"
             output += "        }\n"
             output += "    }\n"
             
             output += "\n    public func encode(to encoder: Encoder) throws {\n"
             output += "        var container = encoder.singleValueContainer()\n"
             output += "        switch self {\n"
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "        case .\\(typeName.lowercased())(let value):\n"
                 output += "            try container.encode(value)\n"
             }
             output += "        }\n"
             output += "    }\n"
             
             output += "\n    private enum CodingKeys: String, CodingKey {\n"
             output += "        case \\(propName)\n"
             output += "    }\n"
         } else {
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "    case option\\(i)(\\(typeName))\n"
                 i += 1
             }
             
             output += "\n    public init(from decoder: Decoder) throws {\n"
             output += "        let container = try decoder.singleValueContainer()\n"
             i = 1
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "        if let value = try? container.decode(\\(typeName).self) {\n"
                 output += "            self = .option\\(i)(value)\n"
                 output += "            return\n"
                 output += "        }\n"
                 i += 1
             }
             output += "        throw DecodingError.typeMismatch(\\(name).self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: \"Failed to decode \\(name) anyOf/oneOf\"))\n"
             output += "    }\n"
             
             output += "\n    public func encode(to encoder: Encoder) throws {\n"
             output += "        var container = encoder.singleValueContainer()\n"
             output += "        switch self {\n"
             i = 1
             for option in options {
                 output += "        case .option\\(i)(let value):\n"
                 output += "            try container.encode(value)\n"
                 i += 1
             }
             output += "        }\n"
             output += "    }\n"
         }
         
         output += "}\n"
         return output
    }
    
    output += "public struct \(name): Codable, Equatable {\n"
    var allProperties: [(name: String, schema: Schema, isRequired: Bool)] = []
    
    if let allOf = schema.allOf {
        for subSchema in allOf {
            if let props = subSchema.properties {
                for (propName, propSchema) in props {
                    let isReq = subSchema.required?.contains(propName) ?? false
                    allProperties.append((propName, propSchema, isReq))
                }
            }
        }
    }
    
    if let properties = schema.properties {
        for (propName, propSchema) in properties {
            let isReq = schema.required?.contains(propName) ?? false
            allProperties.append((propName, propSchema, isReq))
        }
    }
    
    var uniquePropsMap: [String: (Schema, Bool)] = [:]
    for prop in allProperties {
        uniquePropsMap[prop.name] = (prop.schema, prop.isRequired)
    }
    
    let sortedProps = uniquePropsMap.sorted { $0.key < $1.key }
    
    for (propName, propData) in sortedProps {
        let propSchema = propData.0
        output += emitDocstring(propSchema.description, indent: 4)
        
        var valDocs: [String] = []
        if let min = propSchema.minimum { valDocs.append("Minimum: \(min)") }
        if let max = propSchema.maximum { valDocs.append("Maximum: \(max)") }
        if let minLen = propSchema.minLength { valDocs.append("Minimum Length: \(minLen)") }
        if let maxLen = propSchema.maxLength { valDocs.append("Maximum Length: \(maxLen)") }
        if let pattern = propSchema.pattern { valDocs.append("Pattern: \(pattern)") }
        
        for vDoc in valDocs {
            output += "    /// - \(vDoc)\n"
        }
        
        let swiftType = mapType(schema: propSchema)
        let isRequired = propData.1
        let optionalSuffix = isRequired ? "" : "?"
        
        var propertyWrappers: [String] = []
        if let min = propSchema.minimum { propertyWrappers.append("@Minimum(\\(min))") }
        if let max = propSchema.maximum { propertyWrappers.append("@Maximum(\\(max))") }
        if let minLen = propSchema.minLength { propertyWrappers.append("@MinLength(\\(minLen))") }
        if let maxLen = propSchema.maxLength { propertyWrappers.append("@MaxLength(\\(maxLen))") }
        if let pattern = propSchema.pattern { propertyWrappers.append("@Pattern(\"\\(pattern)\")") }
        
        for pw in propertyWrappers {
            output += "    \\(pw)\n"
        }
        
        output += "    public var \\(propName): \\(swiftType)\\(optionalSuffix)\n"
    }
    
    if !sortedProps.isEmpty {
        output += "\n"
        let params = sortedProps.map { (propName, propData) -> String in
            let swiftType = mapType(schema: propData.0)
            let isRequired = propData.1
            let optionalSuffix = isRequired ? "" : "?"
            return "\(propName): \(swiftType)\(optionalSuffix)\(isRequired ? \"\" : \" = nil\")"
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

/// Helper mapping schema types to Swift.
public func mapType(schema: Schema) -> String {
    if let ref = schema.ref ?? schema.dynamicRef {
        return ref.components(separatedBy: "/").last ?? "Unknown"
    }
    switch schema.type {
    case "string":
        if schema.format == "date-time" { return "Date" }
        if schema.format == "uuid" { return "UUID" }
        if schema.enum_values != nil { return "String" }
        return "String"
    case "integer": return schema.format == "int64" ? "Int64" : "Int"
    case "number": return schema.format == "float" ? "Float" : "Double"
    case "boolean": return "Bool"
    case "array":
        if let prefixItems = schema.prefixItems {
            let types = prefixItems.map { mapType(schema: $0) }.joined(separator: ", ")
            return "(\(types))"
        }
        if let items = schema.items {
            if let ref = items.ref {
                return "[\(ref.components(separatedBy: \"/\").last ?? \"Unknown\")]"
            } else if let type = items.type {
                let primitive = Schema(type: type)
                return "[\(mapType(schema: primitive))]"
            }
        }
        return "[AnyCodable]"
    case "object":
        if let additional = schema.additionalProperties {
            if let ref = additional.ref {
                let valueType = ref.components(separatedBy: "/").last ?? "Unknown"
                return "[String: \(valueType)]"
            } else if let type = additional.type {
                let primitive = Schema(type: type)
                let valueType = mapType(schema: primitive)
                return "[String: \(valueType)]"
            }
            return "[String: AnyCodable]"
        }
        return "AnyCodable"
    default:
        return "AnyCodable"
    }
}
