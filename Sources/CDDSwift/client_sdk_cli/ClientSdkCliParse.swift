import Foundation
import SwiftParser
import SwiftSyntax

/// Visitor to parse CLI commands from Swift code and infer OpenAPI paths/operations.
public class CliVisitor: SyntaxVisitor {
    public var paths: [String: PathItem] = [:]

    public override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for structs conforming to AsyncParsableCommand
        var isCommand = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                if type.type.description.trimmingCharacters(in: .whitespacesAndNewlines) == "AsyncParsableCommand" {
                    isCommand = true
                }
            }
        }
        
        if isCommand {
            let structName = node.name.text
            if structName.hasSuffix("Command") && structName != "APIClientCLI" {
                // Infer operation ID from struct name
                let opId = structName.replacingOccurrences(of: "Command", with: "").prefix(1).lowercased() + structName.replacingOccurrences(of: "Command", with: "").dropFirst()
                
                var parameters: [Parameter] = []
                for member in node.memberBlock.members {
                    if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                        var hasOption = false
                        for attr in varDecl.attributes {
                            if let customAttr = attr.as(AttributeSyntax.self), customAttr.attributeName.description.contains("Option") {
                                hasOption = true
                            }
                        }
                        
                        if hasOption {
                            for binding in varDecl.bindings {
                                if let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                                    let paramName = idPattern.identifier.text
                                    var typeStr = "String"
                                    if let typeAnn = binding.typeAnnotation {
                                        typeStr = typeAnn.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                    let isOptional = typeStr.hasSuffix("?")
                                    let cleanType = typeStr.replacingOccurrences(of: "?", with: "")
                                    
                                    let schemaType = cleanType == "Int" ? "integer" : "string"
                                    let schema = Schema(type: schemaType)
                                    let param = Parameter(name: paramName, in: "query", description: nil, required: !isOptional, schema: schema)
                                    parameters.append(param)
                                }
                            }
                        }
                    }
                }
                
                var method = "post"
                if opId.hasPrefix("get") { method = "get" }
                else if opId.hasPrefix("put") { method = "put" }
                else if opId.hasPrefix("delete") { method = "delete" }
                else if opId.hasPrefix("patch") { method = "patch" }
                
                let path = "/" + opId
                
                let operation = Operation(operationId: String(opId), parameters: parameters.isEmpty ? nil : parameters)
                
                var pathItem = paths[path] ?? PathItem()
                if method == "get" { pathItem.get = operation }
                else if method == "put" { pathItem.put = operation }
                else if method == "delete" { pathItem.delete = operation }
                else if method == "patch" { pathItem.patch = operation }
                else { pathItem.post = operation }
                
                paths[path] = pathItem
            }
        }
        
        return .visitChildren
    }
}
