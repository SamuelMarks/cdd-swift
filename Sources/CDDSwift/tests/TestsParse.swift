import Foundation
import SwiftSyntax

/// Extracts test case metadata from `XCTestCase` subclasses to augment OpenAPI documentation or examples.
public class TestVisitor: SyntaxVisitor {
    /// Set of discovered test method names across `*Tests` classes.
    public var discoveredTestMethods: [String] = []

    /// Initializes the `TestVisitor` with a syntax tree view mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when traversing nodes.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits class declarations to extract `test*` methods from `XCTestCase` classes.
    ///
    /// - Parameter node: The `ClassDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after inspecting member functions.
    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text.hasSuffix("Tests") {
            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
                   funcDecl.name.text.hasPrefix("test")
                {
                    discoveredTestMethods.append(funcDecl.name.text)
                }
            }
        }
        return .skipChildren
    }
}
