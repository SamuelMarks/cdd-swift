import Foundation
import SwiftSyntax

/// Parses Vapor server routes into OpenAPI definitions.
public class ServerVisitor: SyntaxVisitor {
    /// Dictionary of inferred OpenAPI PathItems.
    public var paths: [String: PathItem] = [:]

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits function call expressions to identify route registrations.
    override public func visit(_: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Mock implementation to find vapor routes like app.get("path")
        return .visitChildren
    }
}
