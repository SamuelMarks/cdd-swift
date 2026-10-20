/// SwiftSyntax visitor extracting OpenAPI path items from Vapor server route registrations.
import Foundation
import SwiftSyntax

/// Parses Vapor server routes into OpenAPI definitions.
public class ServerVisitor: SyntaxVisitor {
    /// Dictionary of inferred OpenAPI PathItems.
    public var paths: [String: PathItem] = [:]

    /// Initializes the `ServerVisitor` with a syntax tree view mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when traversing syntax nodes.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits function call expressions to identify route registrations.
    ///
    /// - Parameter node: The `FunctionCallExprSyntax` node being visited.
    /// - Returns: `.visitChildren` to continue traversing nested syntax nodes.
    override public func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        let method = memberAccess.declName.baseName.text.lowercased()
        let supportedMethods: Set = ["get", "post", "put", "delete", "patch", "options", "head"]
        guard supportedMethods.contains(method) else {
            return .visitChildren
        }

        if let baseExpr = memberAccess.base?.description.trimmingCharacters(in: .whitespacesAndNewlines),
           baseExpr == "app" || baseExpr == "routes" || baseExpr.hasSuffix("Routes")
        {
            var segments: [String] = []
            for arg in node.arguments {
                let raw = arg.expression.description
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .filter { $0 != "\"" }
                if raw.isEmpty {
                    continue
                }
                if raw.hasPrefix(":") {
                    let paramName = String(raw.dropFirst())
                    segments.append("{\(paramName)}")
                } else {
                    segments.append(raw)
                }
            }

            let fullPath = "/" + segments.joined(separator: "/")
            if fullPath == "/_mock/trigger-webhook/{name}" || fullPath.hasPrefix("/auth/") {
                return .visitChildren
            }

            let opId = "\(method)_\(segments.joined(separator: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
            let operation = Operation(
                operationId: opId,
                responses: ["200": Response(description: "OK")]
            )

            var item = paths[fullPath] ?? PathItem()
            if method == "get" {
                item.get = operation
            } else if method == "post" {
                item.post = operation
            } else if method == "put" {
                item.put = operation
            } else if method == "delete" {
                item.delete = operation
            } else if method == "patch" {
                item.patch = operation
            } else if method == "options" {
                item.options = operation
            } else {
                item.head = operation
            }
            paths[fullPath] = item
        }
        return .visitChildren
    }
}
