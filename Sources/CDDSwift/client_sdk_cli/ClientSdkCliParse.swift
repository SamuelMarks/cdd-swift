import Foundation
import SwiftParser
import SwiftSyntax

/// Visitor to parse CLI commands from Swift code and infer OpenAPI paths/operations.
public class CliVisitor: SyntaxVisitor {
    /// Documentation for paths
    public var paths: [String: PathItem] = [:]

    override public init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    /// Documentation for visit
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for structs conforming to AsyncParsableCommand
        /// Documentation for isCommand
        var isCommand = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes {
                if type.type.description.trimmingCharacters(in: .whitespacesAndNewlines) == "AsyncParsableCommand" {
                    isCommand = true
                }
            }
        }

        if isCommand {
            /// Documentation for structName
            let structName = node.name.text
            if structName.hasSuffix("Command") && structName != "APIClientCLI" {
                // Infer operation ID from struct name
                /// Documentation for opId
                let opId = structName.replacingOccurrences(of: "Command", with: "").prefix(1).lowercased() + structName.replacingOccurrences(of: "Command", with: "").dropFirst()

                /// Documentation for parameters
                var parameters: [Parameter] = []
                for member in node.memberBlock.members {
                    if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                        /// Documentation for hasOption
                        var hasOption = false
                        for attr in varDecl.attributes {
                            if let customAttr = attr.as(AttributeSyntax.self), customAttr.attributeName.description.contains("Option") {
                                hasOption = true
                            }
                        }

                        if hasOption {
                            for binding in varDecl.bindings {
                                if let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                                    /// Documentation for paramName
                                    let paramName = idPattern.identifier.text
                                    /// Documentation for typeStr
                                    var typeStr = "String"
                                    if let typeAnn = binding.typeAnnotation {
                                        typeStr = typeAnn.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                    /// Documentation for isOptional
                                    let isOptional = typeStr.hasSuffix("?")
                                    /// Documentation for cleanType
                                    let cleanType = typeStr.replacingOccurrences(of: "?", with: "")

                                    /// Documentation for schemaType
                                    let schemaType = cleanType == "Int" ? "integer" : "string"
                                    /// Documentation for schema
                                    let schema = Schema(type: schemaType)
                                    /// Documentation for param
                                    let param = Parameter(name: paramName, in: "query", description: nil, required: !isOptional, schema: schema)
                                    parameters.append(param)
                                }
                            }
                        }
                    }
                }

                /// Documentation for method
                var method = "post"
                if opId.hasPrefix("get") { method = "get" }
                else if opId.hasPrefix("put") { method = "put" }
                else if opId.hasPrefix("delete") { method = "delete" }
                else if opId.hasPrefix("patch") { method = "patch" }

                /// Documentation for path
                let path = "/" + opId

                /// Documentation for operation
                let operation = Operation(operationId: String(opId), parameters: parameters.isEmpty ? nil : parameters)

                /// Documentation for pathItem
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
