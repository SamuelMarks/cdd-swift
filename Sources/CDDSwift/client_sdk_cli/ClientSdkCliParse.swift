import Foundation
import SwiftParser
import SwiftSyntax

/// Visitor to parse `ArgumentParser` CLI commands from Swift code and infer OpenAPI paths and operations.
public class CliVisitor: SyntaxVisitor {
    /// Dictionary mapping inferred paths to their `PathItem` definitions.
    public var paths: [String: PathItem] = [:]
    /// Extracted API title from `APIClientCLI`, if present.
    public var infoTitle: String?
    /// Extracted API version from `APIClientCLI`, if present.
    public var infoVersion: String?

    /// Initializes the `CliVisitor` with a syntax tree view mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when traversing nodes.
    override public init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    /// Visits `struct` declarations to identify `AsyncParsableCommand` subcommands and extract options.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: `.visitChildren` to continue traversing nested declarations.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        var isCommand = false
        if let inheritanceClause = node.inheritanceClause {
            for type in inheritanceClause.inheritedTypes where type.type.description.trimmingCharacters(in: .whitespacesAndNewlines) == "AsyncParsableCommand" {
                isCommand = true
            }
        }

        if isCommand {
            let structName = node.name.text
            if structName.hasSuffix("Command") && structName != "APIClientCLI" && structName != "MCPCommand" {
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
                                    if paramName == "serverUrl" || paramName == "body" {
                                        continue
                                    }
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
                if opId.hasPrefix("get") {
                    method = "get"
                } else if opId.hasPrefix("put") {
                    method = "put"
                } else if opId.hasPrefix("delete") {
                    method = "delete"
                } else if opId.hasPrefix("patch") {
                    method = "patch"
                }

                let path = "/" + opId
                let operation = Operation(operationId: String(opId), parameters: parameters.isEmpty ? nil : parameters)

                var pathItem = paths[path] ?? PathItem()
                if method == "get" {
                    pathItem.get = operation
                } else if method == "put" {
                    pathItem.put = operation
                } else if method == "delete" {
                    pathItem.delete = operation
                } else if method == "patch" {
                    pathItem.patch = operation
                } else {
                    pathItem.post = operation
                }

                paths[path] = pathItem
            }
        }

        return .visitChildren
    }
}
