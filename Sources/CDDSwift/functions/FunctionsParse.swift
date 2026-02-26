import SwiftSyntax

/// Parses webhooks / callback functions to OpenAPI definitions.
public class FunctionVisitor: SyntaxVisitor {
    public override init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

}
