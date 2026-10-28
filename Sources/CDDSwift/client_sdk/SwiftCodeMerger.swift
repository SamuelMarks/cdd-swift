/// SwiftSyntax AST code merger for preserving existing declarations and trivia when regenerating SDK files.
import SwiftParser
import SwiftSyntax

/// Safely merges generated Swift code into an existing Swift file using AST.
/// Preserves whitespace and comments.
public enum SwiftCodeMerger {
    /// Merges generated Swift code into an existing Swift file using AST.
    ///
    /// - Parameters:
    ///   - generatedCode: Newly generated Swift source code.
    ///   - destinationSource: Existing Swift source code to update.
    /// - Returns: The merged Swift source code preserving existing trivia and custom declarations.
    public static func merge(generatedCode: String, into destinationSource: String) -> String {
        let destFile = Parser.parse(source: destinationSource)
        let genFile = Parser.parse(source: generatedCode)

        var generatedDecls: [String: DeclSyntax] = [:]
        for statement in genFile.statements {
            if let structDecl = statement.item.as(StructDeclSyntax.self) {
                generatedDecls[structDecl.name.text] = statement.item.as(DeclSyntax.self)
            } else if let enumDecl = statement.item.as(EnumDeclSyntax.self) {
                generatedDecls[enumDecl.name.text] = statement.item.as(DeclSyntax.self)
            } else if let protoDecl = statement.item.as(ProtocolDeclSyntax.self) {
                generatedDecls[protoDecl.name.text] = statement.item.as(DeclSyntax.self)
            }
        }

        let rewriter = MergerRewriter(generatedDecls: generatedDecls)
        let mergedFile = rewriter.rewrite(destFile)
        var finalSource = mergedFile.description

        for (name, decl) in generatedDecls where !rewriter.visitedDecls.contains(name) {
            if !finalSource.hasSuffix("\n") {
                finalSource += "\n\n"
            } else if !finalSource.hasSuffix("\n\n") {
                finalSource += "\n"
            }
            finalSource += decl.description + "\n"
        }

        return finalSource
    }
}

/// A syntax rewriter that replaces existing declarations with generated ones.
class MergerRewriter: SyntaxRewriter {
    /// The mapped generated declarations available for injection.
    let generatedDecls: [String: DeclSyntax]
    /// Tracks which generated declarations were injected to append remainders later.
    var visitedDecls: Set<String> = []

    /// Initializes the rewriter.
    ///
    /// - Parameter generatedDecls: Dictionary mapping declaration names to their generated `DeclSyntax` nodes.
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }

    /// Visits and replaces `struct` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Visits and replaces `enum` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `EnumDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Visits and replaces `protocol` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `ProtocolDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
}
