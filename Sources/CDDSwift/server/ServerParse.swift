import Foundation
import SwiftSyntax

public class ServerVisitor: SyntaxVisitor {
    public var paths: [String: PathItem] = [:]
    
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }
    
    override public func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Mock implementation to find vapor routes like app.get("path")
        return .visitChildren
    }
}
