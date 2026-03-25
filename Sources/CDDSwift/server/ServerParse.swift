import Foundation
import SwiftSyntax

/// Documentation for ServerVisitor
public class ServerVisitor: SyntaxVisitor {
    /// Documentation for paths
    public var paths: [String: PathItem] = [:]

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Documentation for visit
    override public func visit(_: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Mock implementation to find vapor routes like app.get("path")
        return .visitChildren
    }
}
