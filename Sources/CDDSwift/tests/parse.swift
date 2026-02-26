import SwiftSyntax

/// Extracts test cases to augment OpenAPI documentation or examples.
public class TestVisitor: SyntaxVisitor {
    public override init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }
    
    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text.hasSuffix("Tests") {
            // Could extract sample data here to embed into the OpenAPI specification
        }
        return .skipChildren
    }
}
