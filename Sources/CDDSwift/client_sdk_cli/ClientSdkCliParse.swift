/// SwiftSyntax visitor parsing ArgumentParser CLI commands into OpenAPI paths and operations.
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
        guard isAsyncParsableCommand(node) else {
            return .visitChildren
        }

        let structName = node.name.text
        if structName == "APIClientCLI" {
            extractRootCLIMetadata(from: node.memberBlock.members)
        } else if structName.hasSuffix("Command") && structName != "MCPCommand" {
            extractCommandOperation(structName: structName, members: node.memberBlock.members)
        }

        return .visitChildren
    }

    /// Checks whether a struct declaration inherits from `AsyncParsableCommand`.
    ///
    /// - Parameter node: The `StructDeclSyntax` to inspect.
    /// - Returns: `true` if `AsyncParsableCommand` is in the inheritance clause.
    private func isAsyncParsableCommand(_ node: StructDeclSyntax) -> Bool {
        guard let inheritanceClause = node.inheritanceClause else { return false }
        for type in inheritanceClause.inheritedTypes
            where type.type.description.trimmingCharacters(in: .whitespacesAndNewlines) == "AsyncParsableCommand" {
            return true
        }
        return false
    }

    /// Extracts `infoTitle` and `infoVersion` from the `CommandConfiguration` initializer inside `APIClientCLI`.
    ///
    /// - Parameter members: The member declarations of `APIClientCLI`.
    private func extractRootCLIMetadata(from members: MemberBlockItemListSyntax) {
        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in varDecl.bindings {
                guard let callExpr = binding.initializer?.value.as(FunctionCallExprSyntax.self) else { continue }
                applyConfigArguments(callExpr.arguments)
            }
        }
    }

    /// Applies `abstract` and `version` string arguments from a `CommandConfiguration(...)` call.
    ///
    /// - Parameter arguments: The `LabeledExprListSyntax` of the configuration call.
    private func applyConfigArguments(_ arguments: LabeledExprListSyntax) {
        for arg in arguments {
            guard let label = arg.label?.text,
                  let strLit = arg.expression.as(StringLiteralExprSyntax.self),
                  let seg = strLit.segments.first?.as(StringSegmentSyntax.self)
            else {
                continue
            }
            let text = seg.content.text
            if label == "abstract" {
                infoTitle = text.hasSuffix(" CLI") ? String(text.dropLast(4)) : text
            } else if label == "version" {
                infoVersion = text
            }
        }
    }

    /// Extracts an OpenAPI `Operation` and registers its `PathItem` from a `*Command` struct declaration.
    ///
    /// - Parameters:
    ///   - structName: The struct name ending in `"Command"`.
    ///   - members: The member declarations of the command struct.
    private func extractCommandOperation(structName: String, members: MemberBlockItemListSyntax) {
        let baseName = structName.replacingOccurrences(of: "Command", with: "")
        let opId = String(baseName.prefix(1).lowercased() + baseName.dropFirst())
        let parameters = extractCommandOptionParameters(from: members)
        let method = inferCLICommandHTTPMethod(forOperationId: opId)
        let path = "/" + opId
        let operation = Operation(operationId: opId, parameters: parameters.isEmpty ? nil : parameters)

        var pathItem = paths[path] ?? PathItem()
        switch method {
        case "get": pathItem.get = operation
        case "put": pathItem.put = operation
        case "delete": pathItem.delete = operation
        case "patch": pathItem.patch = operation
        default: pathItem.post = operation
        }
        paths[path] = pathItem
    }

    /// Extracts query `Parameter` definitions from `@Option`-annotated properties inside a command struct.
    ///
    /// - Parameter members: The member declarations of the command struct.
    /// - Returns: Array of extracted `Parameter` definitions.
    private func extractCommandOptionParameters(from members: MemberBlockItemListSyntax) -> [Parameter] {
        var parameters: [Parameter] = []
        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  hasOptionAttribute(varDecl.attributes)
            else {
                continue
            }
            for binding in varDecl.bindings {
                guard let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let paramName = idPattern.identifier.text
                if paramName == "serverUrl" || paramName == "body" {
                    continue
                }
                var typeStr = "String"
                if let annotatedType = binding.typeAnnotation?.type {
                    typeStr = annotatedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let isOptional = typeStr.hasSuffix("?")
                let cleanType = typeStr.replacingOccurrences(of: "?", with: "")
                let schemaType: SchemaType = cleanType == "Int" ? .integer : .string
                parameters.append(
                    Parameter(
                        name: paramName,
                        in: .query,
                        description: nil,
                        required: !isOptional,
                        schema: Schema(type: schemaType.rawValue)
                    )
                )
            }
        }
        return parameters
    }

    /// Checks whether an attribute list contains an `@Option` attribute.
    ///
    /// - Parameter attributes: The `AttributeListSyntax` of a variable declaration.
    /// - Returns: `true` if an `@Option` attribute is present.
    private func hasOptionAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attr in attributes {
            if let customAttr = attr.as(AttributeSyntax.self), customAttr.attributeName.description.contains("Option") {
                return true
            }
        }
        return false
    }

    /// Infers the HTTP method from an operation ID prefix (`get`, `put`, `delete`, `patch`, defaulting to `post`).
    ///
    /// - Parameter opId: The camelCase operation identifier.
    /// - Returns: Lowercase HTTP method string.
    private func inferCLICommandHTTPMethod(forOperationId opId: String) -> String {
        for prefix in ["get", "put", "delete", "patch"] where opId.hasPrefix(prefix) {
            return prefix
        }
        return "post"
    }
}
