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
        guard supportedMethods.contains(method),
              let baseExpr = memberAccess.base?.description.trimmingCharacters(in: .whitespacesAndNewlines),
              isVaporRouterExpression(baseExpr)
        else {
            return .visitChildren
        }

        let segments = extractPathSegments(from: node.arguments)
        let fullPath = "/" + segments.joined(separator: "/")
        if fullPath == "/_mock/trigger-webhook/{name}" || fullPath.hasPrefix("/auth/") {
            return .visitChildren
        }

        let cleanJoined = segments.joined(separator: "_")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        let operation = Operation(
            operationId: "\(method)_\(cleanJoined)",
            responses: ["200": Response(description: "OK")]
        )
        recordOperation(operation, method: method, fullPath: fullPath)
        return .visitChildren
    }

    /// Checks whether a base expression refers to a Vapor application or routes builder.
    ///
    /// - Parameter baseExpr: Trimmed Swift base expression string.
    /// - Returns: `true` if `baseExpr` is `"app"`, `"routes"`, or ends with `"Routes"`.
    private func isVaporRouterExpression(_ baseExpr: String) -> Bool {
        return baseExpr == "app" || baseExpr == "routes" || baseExpr.hasSuffix("Routes")
    }

    /// Extracts URL path segments from Vapor route registration string literal arguments.
    ///
    /// - Parameter arguments: The `LabeledExprListSyntax` of the route call.
    /// - Returns: Array of normalized OpenAPI path segment strings (converting `:param` to `{param}`).
    private func extractPathSegments(from arguments: LabeledExprListSyntax) -> [String] {
        var segments: [String] = []
        for arg in arguments {
            guard let strLit = arg.expression.as(StringLiteralExprSyntax.self),
                  let seg = strLit.segments.first?.as(StringSegmentSyntax.self)
            else {
                continue
            }
            let raw = seg.content.text
            if raw.isEmpty {
                continue
            }
            if raw.hasPrefix(":") {
                segments.append("{\(String(raw.dropFirst()))}")
            } else {
                segments.append(raw)
            }
        }
        return segments
    }

    /// Assigns an `Operation` to the appropriate HTTP method slot on `paths[fullPath]`.
    ///
    /// - Parameters:
    ///   - operation: The inferred OpenAPI `Operation`.
    ///   - method: Lowercase HTTP method string.
    ///   - fullPath: Normalized OpenAPI URL path template.
    private func recordOperation(_ operation: Operation, method: String, fullPath: String) {
        var item = paths[fullPath] ?? PathItem()
        switch method {
        case "get": item.get = operation
        case "post": item.post = operation
        case "put": item.put = operation
        case "delete": item.delete = operation
        case "patch": item.patch = operation
        case "options": item.options = operation
        default: item.head = operation
        }
        paths[fullPath] = item
    }
}
