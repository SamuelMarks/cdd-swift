import Foundation
import SwiftParser
import SwiftSyntax

/// Model visitor to extract Codable structs into OpenAPI Schemas.
public class ModelVisitor: SyntaxVisitor {
    /// Documentation for schemas
    public var schemas: [String: Schema] = [:]

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for enumName
        let enumName = node.name.text
        /// Documentation for isCodable
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                /// Documentation for typeName
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" || typeName == "String" {
                    isCodable = true
                    break
                }
            }
        }

        if isCodable {
            /// Documentation for stringCases
            var stringCases: [String] = []
            /// Documentation for oneOfSchemas
            var oneOfSchemas: [Schema] = []
            /// Documentation for hasAssociatedValues
            var hasAssociatedValues = false

            for member in node.memberBlock.members {
                if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                    for element in caseDecl.elements {
                        if let assocValue = element.parameterClause {
                            hasAssociatedValues = true
                            if let firstParam = assocValue.parameters.first {
                                /// Documentation for declaration
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

            /// Documentation for enumDescription
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

    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for structName
        let structName = node.name.text

        /// Documentation for isCodable
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                /// Documentation for typeName
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" {
                    isCodable = true
                    break
                }
            }
        }

        if isCodable {
            /// Documentation for properties
            var properties: [String: Schema] = [:]
            /// Documentation for required
            var required: [String] = []
            /// Documentation for structDescription
            let structDescription = parseDocstring(from: Syntax(node))

            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    /// Documentation for propDescription
                    let propDescription = parseDocstring(from: Syntax(varDecl))
                    for binding in varDecl.bindings {
                        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self), let typeAnnotation = binding.typeAnnotation {
                            /// Documentation for propName
                            let propName = pattern.identifier.text
                            /// Documentation for typeSyntax
                            let typeSyntax = typeAnnotation.type

                            /// Documentation for declaration
                            var (schema, isOptional) = parseType(typeSyntax)

                            /// Documentation for min
                            var min: Double? = nil
                            /// Documentation for max
                            var max: Double? = nil
                            /// Documentation for minLen
                            var minLen: Int? = nil
                            /// Documentation for maxLen
                            var maxLen: Int? = nil
                            /// Documentation for patternStr
                            var patternStr: String? = nil

                            if let attributes = binding.parent?.parent?.as(VariableDeclSyntax.self)?.attributes {
                                for attr in attributes {
                                    if let customAttr = attr.as(AttributeSyntax.self) {
                                        /// Documentation for attrName
                                        let attrName = customAttr.attributeName.trimmedDescription
                                        if let args = customAttr.arguments?.as(LabeledExprListSyntax.self), let firstArg = args.first {
                                            if attrName == "Minimum", let val = Double(firstArg.expression.trimmedDescription) { min = val }
                                            if attrName == "Maximum", let val = Double(firstArg.expression.trimmedDescription) { max = val }
                                            if attrName == "MinLength", let val = Int(firstArg.expression.trimmedDescription) { minLen = val }
                                            if attrName == "MaxLength", let val = Int(firstArg.expression.trimmedDescription) { maxLen = val }
                                            if attrName == "Pattern" {
                                                if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self), let seg = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                                                    patternStr = seg.content.text
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if let desc = propDescription {
                                schema = Schema(
                                    type: schema.type,
                                    properties: schema.properties,
                                    additionalProperties: schema.additionalProperties,
                                    items: schema.items,
                                    prefixItems: schema.prefixItems,
                                    required: schema.required,
                                    ref: schema.ref,
                                    description: desc,
                                    format: schema.format,
                                    maximum: max ?? schema.maximum,
                                    minimum: min ?? schema.minimum,
                                    maxLength: maxLen ?? schema.maxLength,
                                    minLength: minLen ?? schema.minLength,
                                    pattern: patternStr ?? schema.pattern
                                )
                            } else if min != nil || max != nil || minLen != nil || maxLen != nil || patternStr != nil {
                                schema = Schema(
                                    type: schema.type,
                                    properties: schema.properties,
                                    additionalProperties: schema.additionalProperties,
                                    items: schema.items,
                                    prefixItems: schema.prefixItems,
                                    required: schema.required,
                                    ref: schema.ref,
                                    description: schema.description,
                                    format: schema.format,
                                    maximum: max ?? schema.maximum,
                                    minimum: min ?? schema.minimum,
                                    maxLength: maxLen ?? schema.maxLength,
                                    minLength: minLen ?? schema.minLength,
                                    pattern: patternStr ?? schema.pattern
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

            /// Documentation for schema
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

    /// Documentation for parseType
    private func parseType(_ type: TypeSyntax) -> (Schema, Bool) {
        if let optType = type.as(OptionalTypeSyntax.self) {
            /// Documentation for declaration
            let (schema, _) = parseType(optType.wrappedType)
            return (schema, true)
        } else if let identType = type.as(IdentifierTypeSyntax.self) {
            /// Documentation for typeName
            let typeName = identType.name.text
            return (mapPrimitive(typeName), false)
        } else if let arrayType = type.as(ArrayTypeSyntax.self) {
            /// Documentation for declaration
            let (itemSchema, _) = parseType(arrayType.element)

            /// Documentation for items
            let items: SchemaItem
            if let ref = itemSchema.ref {
                items = SchemaItem(ref: ref)
            } else {
                items = SchemaItem(type: itemSchema.type)
            }

            /// Documentation for arraySchema
            let arraySchema = Schema(type: "array", items: items)
            return (arraySchema, false)
        } else if let dictType = type.as(DictionaryTypeSyntax.self) {
            /// Documentation for declaration
            let (valueSchema, _) = parseType(dictType.value)
            /// Documentation for item
            let item: SchemaItem
            if let ref = valueSchema.ref {
                item = SchemaItem(ref: ref)
            } else {
                item = SchemaItem(type: valueSchema.type)
            }
            return (Schema(type: "object", additionalProperties: item), false)
        } else if let tupleType = type.as(TupleTypeSyntax.self) {
            /// Documentation for prefixItems
            var prefixItems: [Schema] = []
            for element in tupleType.elements {
                /// Documentation for declaration
                let (elemSchema, _) = parseType(element.type)
                prefixItems.append(elemSchema)
            }
            return (Schema(type: "array", prefixItems: prefixItems.isEmpty ? nil : prefixItems), false)
        }

        return (Schema(type: "string"), false)
    }

    /// Documentation for mapPrimitive
    private func mapPrimitive(_ name: String) -> Schema {
        switch name {
        case "String": return Schema(type: "string")
        case "Int": return Schema(type: "integer", format: "int32")
        case "Int64": return Schema(type: "integer", format: "int64")
        case "Double": return Schema(type: "number", format: "double")
        case "Float": return Schema(type: "number", format: "float")
        case "Bool": return Schema(type: "boolean")
        case "Date": return Schema(type: "string", format: "date-time")
        case "UUID": return Schema(type: "string", format: "uuid")
        default:
            return Schema(ref: "#/components/schemas/\(name)")
        }
    }
}
