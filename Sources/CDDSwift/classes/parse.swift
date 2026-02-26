import Foundation
import SwiftSyntax
import SwiftParser

/// Model visitor to extract Codable structs into OpenAPI Schemas.
public class ModelVisitor: SyntaxVisitor {
    public var schemas: [String: Schema] = [:]
    
    public override init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }
    
    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let enumName = node.name.text
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" || typeName == "String" {
                    isCodable = true
                    break
                }
            }
        }
        
        if isCodable {
            var stringCases: [String] = []
            var oneOfSchemas: [Schema] = []
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
    
    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let structName = node.name.text
        
        var isCodable = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                let typeName = type.type.trimmedDescription
                if typeName == "Codable" || typeName == "Encodable" || typeName == "Decodable" {
                    isCodable = true
                    break
                }
            }
        }
        
        if isCodable {
            var properties: [String: Schema] = [:]
            var required: [String] = []
            let structDescription = parseDocstring(from: Syntax(node))
            
            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    let propDescription = parseDocstring(from: Syntax(varDecl))
                    for binding in varDecl.bindings {
                        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self), let typeAnnotation = binding.typeAnnotation {
                            let propName = pattern.identifier.text
                            let typeSyntax = typeAnnotation.type
                            
                            var (schema, isOptional) = parseType(typeSyntax)
                            
                            var min: Double? = nil
                            var max: Double? = nil
                            var minLen: Int? = nil
                            var maxLen: Int? = nil
                            var patternStr: String? = nil
                            
                            if let attributes = binding.parent?.parent?.as(VariableDeclSyntax.self)?.attributes {
                                for attr in attributes {
                                    if let customAttr = attr.as(AttributeSyntax.self) {
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
    
    private func parseType(_ type: TypeSyntax) -> (Schema, Bool) {
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
                items = SchemaItem(type: itemSchema.type)
            }
            
            let arraySchema = Schema(type: "array", items: items)
            return (arraySchema, false)
        } else if let dictType = type.as(DictionaryTypeSyntax.self) {
            let (valueSchema, _) = parseType(dictType.value)
            let item: SchemaItem
            if let ref = valueSchema.ref {
                item = SchemaItem(ref: ref)
            } else {
                item = SchemaItem(type: valueSchema.type)
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
