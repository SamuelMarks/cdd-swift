import Foundation
import SwiftSyntax
import SwiftParser

/// A utility to parse Swift source code and generate OpenAPI definitions.
public class SwiftASTParser {
    
    public init() {}
    
    /// Parses a Swift source file and extracts `Codable` structs into OpenAPI `Schema` objects.
    public func parseModels(from source: String) throws -> [String: Schema] {
        let sourceFile = Parser.parse(source: source)
        let visitor = ModelVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.schemas
    }
}

class ModelVisitor: SyntaxVisitor {
    var schemas: [String: Schema] = [:]
    
    private func extractDocComment(from node: Syntax) -> String? {
        var docComment = ""
        for piece in node.leadingTrivia {
            switch piece {
            case .docLineComment(let text):
                let cleaned = text.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
                docComment += cleaned + "\n"
            case .docBlockComment(let text):
                docComment += text + "\n"
            default:
                break
            }
        }
        let trimmed = docComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let structName = node.name.text
        
        // Check for Codable / Encodable / Decodable conformance
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
            let structDescription = extractDocComment(from: Syntax(node))
            
            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    let propDescription = extractDocComment(from: Syntax(varDecl))
                    for binding in varDecl.bindings {
                        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self), let typeAnnotation = binding.typeAnnotation {
                            let propName = pattern.identifier.text
                            let typeSyntax = typeAnnotation.type
                            
                            var (schema, isOptional) = parseType(typeSyntax)
                            
                            // Attach description if available
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
                                    format: schema.format
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
        
        return .skipChildren // Don't dig into nested structs for now
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
        
        return (Schema(type: "string"), false) // fallback
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
