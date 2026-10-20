/// SwiftSyntax visitor extracting Codable structs, enums, and typealiases into OpenAPI schemas.
import Foundation
import SwiftParser
import SwiftSyntax

/// Model visitor to extract Codable structs into OpenAPI Schemas.
public class ModelVisitor: SyntaxVisitor {
    /// Dictionary of extracted schemas mapped by name.
    public var schemas: [String: Schema] = [:]

    /// Initializes the `ModelVisitor` with a syntax tree traversal mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when walking syntax nodes.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits and parses `enum` declarations into string-backed or `oneOf` OpenAPI schemas.
    ///
    /// - Parameter node: The `EnumDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the enum cases.
    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the name of the Enum.
        let enumName = node.name.text
        // Check if the enum conforms to Codable, Encodable, Decodable, or String.
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                // Extract the name of the inherited type.
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" || typeName == "String" {
                    isCodable = true
                    break
                }
            }
        }

        if isCodable {
            // Collect the raw string values for string-backed enums.
            var stringCases: [String] = []
            // Collect the associated type schemas for polymorphic enums.
            var oneOfSchemas: [Schema] = []
            // Flag to determine if the enum is polymorphic.
            var hasAssociatedValues = false

            for member in node.memberBlock.members {
                if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                    for element in caseDecl.elements {
                        if let assocValue = element.parameterClause {
                            hasAssociatedValues = true
                            if let firstParam = assocValue.parameters.first {
                                let (schema, _) = parseType(firstParam.type)
                                oneOfSchemas.append(schema)
                            }
                        } else {
                            if let rawValue = element.rawValue {
                                if let stringLiteral = rawValue.value.as(StringLiteralExprSyntax.self), let seg = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                                    stringCases.append(seg.content.text)
                                } else {
                                    stringCases.append(element.name.text)
                                }
                            } else {
                                stringCases.append(element.name.text)
                            }
                        }
                    }
                }
            }

            let enumDescription = parseDocstring(from: Syntax(node))

            if hasAssociatedValues {
                schemas[enumName] = Schema(
                    description: enumDescription,
                    oneOf: oneOfSchemas.isEmpty ? nil : oneOfSchemas
                )
            } else {
                schemas[enumName] = Schema(
                    type: "string",
                    description: enumDescription,
                    enum_values: stringCases.map { AnyCodable($0) }
                )
            }
        }
        return .skipChildren
    }

    /// Visits and parses `struct` declarations into object OpenAPI schemas.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the struct properties.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the name of the Struct.
        let structName = node.name.text

        // Check if the struct conforms to Codable, Encodable, or Decodable.
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                // Extract the name of the inherited type.
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" {
                    isCodable = true
                    break
                }
            }
        }

        if isCodable {
            // Map property names to their corresponding schemas.
            var properties: [String: Schema] = [:]
            var required: [String] = []
            let structDescription = parseDocstring(from: Syntax(node))

            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    let propDescription = parseDocstring(from: Syntax(varDecl))
                    for binding in varDecl.bindings {
                        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self), let typeAnnotation = binding.typeAnnotation {
                            // The name of the property.
                            let propName = pattern.identifier.text
                            let typeSyntax = typeAnnotation.type

                            var (schema, isOptional) = parseType(typeSyntax)

                            var min: Double?
                            var max: Double?
                            var minLen: Int?
                            var maxLen: Int?
                            var patternStr: String?

                            if let attributes = binding.parent?.parent?.as(VariableDeclSyntax.self)?.attributes {
                                for attr in attributes {
                                    if let customAttr = attr.as(AttributeSyntax.self) {
                                        let attrName = customAttr.attributeName.trimmedDescription
                                        if let args = customAttr.arguments?.as(LabeledExprListSyntax.self), let firstArg = args.first {
                                            if attrName == "Minimum", let val = Double(firstArg.expression.trimmedDescription) {
                                                min = val
                                            }
                                            if attrName == "Maximum", let val = Double(firstArg.expression.trimmedDescription) {
                                                max = val
                                            }
                                            if attrName == "MinLength", let val = Int(firstArg.expression.trimmedDescription) {
                                                minLen = val
                                            }
                                            if attrName == "MaxLength", let val = Int(firstArg.expression.trimmedDescription) {
                                                maxLen = val
                                            }
                                            if attrName == "Pattern" {
                                                if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self), let seg = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                                                    patternStr = seg.content.text
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if propDescription != nil || min != nil || max != nil || minLen != nil || maxLen != nil || patternStr != nil {
                                schema = schema.updating(
                                    description: propDescription,
                                    minimum: min,
                                    maximum: max,
                                    minLength: minLen,
                                    maxLength: maxLen,
                                    pattern: patternStr
                                )
                            }

                            properties[propName] = schema
                            if !isOptional {
                                required.append(propName)
                            }
                        }
                    }
                }
            }

            // Parse schema
            let schema = Schema(
                type: "object",
                properties: properties.isEmpty ? nil : properties,
                required: required.isEmpty ? nil : required,
                description: structDescription
            )
            schemas[structName] = schema
        }

        return .skipChildren
    }

    /// Visits and parses `typealias` declarations into OpenAPI schemas.
    ///
    /// - Parameter node: The `TypeAliasDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after recording the typealias schema.
    override public func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let (schema, _) = parseType(node.initializer.value)

        let description = parseDocstring(from: Syntax(node))
        var finalSchema = schema
        if let desc = description {
            finalSchema = schema.updating(description: desc)
        }

        schemas[name] = finalSchema
        return .skipChildren
    }

    /// Parses a Swift type into an OpenAPI Schema.
    ///
    /// - Parameter type: The `TypeSyntax` node to inspect.
    /// - Returns: A tuple of the inferred `Schema` and a boolean indicating whether the type is optional.
    public func parseType(_ type: TypeSyntax) -> (Schema, Bool) {
        if let optType = type.as(OptionalTypeSyntax.self) {
            let (schema, _) = parseType(optType.wrappedType)
            return (schema, true)
        } else if let identType = type.as(IdentifierTypeSyntax.self) {
            let typeName = identType.name.text
            return (mapPrimitive(typeName), false)
        } else if let arrayType = type.as(ArrayTypeSyntax.self) {
            let (itemSchema, _) = parseType(arrayType.element)

            let items: SchemaItem
            if let ref = itemSchema.ref {
                items = SchemaItem(ref: ref)
            } else {
                items = SchemaItem(type: itemSchema.type, format: itemSchema.format)
            }

            let arraySchema = Schema(type: "array", items: items)
            return (arraySchema, false)
        } else if let dictType = type.as(DictionaryTypeSyntax.self) {
            let (valueSchema, _) = parseType(dictType.value)
            let item: SchemaItem
            if let ref = valueSchema.ref {
                item = SchemaItem(ref: ref)
            } else {
                item = SchemaItem(type: valueSchema.type, format: valueSchema.format)
            }
            return (Schema(type: "object", additionalProperties: item), false)
        } else if let tupleType = type.as(TupleTypeSyntax.self) {
            var prefixItems: [Schema] = []
            for element in tupleType.elements {
                let (elemSchema, _) = parseType(element.type)
                prefixItems.append(elemSchema)
            }
            return (Schema(type: "array", prefixItems: prefixItems.isEmpty ? nil : prefixItems), false)
        }

        return (Schema(type: "string"), false)
    }

    /// Maps a primitive Swift type to an OpenAPI Schema.
    ///
    /// - Parameter name: The Swift type identifier string.
    /// - Returns: The mapped OpenAPI `Schema`.
    public func mapPrimitive(_ name: String) -> Schema {
        switch name {
        case "String": return Schema(type: "string")
        case "Int": return Schema(type: "integer", format: "int32")
        case "Int64": return Schema(type: "integer", format: "int64")
        case "Double": return Schema(type: "number", format: "double")
        case "Float": return Schema(type: "number", format: "float")
        case "Bool": return Schema(type: "boolean")
        case "Date": return Schema(type: "string", format: "date-time")
        case "UUID": return Schema(type: "string", format: "uuid")
        case "Data": return Schema(type: "string", format: "binary")
        case "AnyCodable": return Schema(type: "object")
        default:
            return Schema(ref: "#/components/schemas/\(name)")
        }
    }
}
