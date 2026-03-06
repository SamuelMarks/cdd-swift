public enum SwiftCodeMerger {
    public static func merge(generatedCode: String, into destinationSource: String) -> String {
        /// Documentation for destFile
        let destFile = Parser.parse(source: destinationSource)
        /// Documentation for genFile
        let genFile = Parser.parse(source: generatedCode)

        // Extract all generated declarations (structs, enums, protocols, etc)
        /// Documentation for generatedDecls
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

        /// Documentation for rewriter
        let rewriter = MergerRewriter(generatedDecls: generatedDecls)
        /// Documentation for mergedFile
        let mergedFile = rewriter.rewrite(destFile)

        // Find any new declarations that were not in the destination
        /// Documentation for finalSource
        var finalSource = mergedFile.description

        for (name, decl) in generatedDecls {
            if !rewriter.visitedDecls.contains(name) {
                if !finalSource.hasSuffix("\n") {
                    finalSource += "\n\n"
                } else if !finalSource.hasSuffix("\n\n") {
                    finalSource += "\n"
                }
                finalSource += decl.description + "\n"
            }
        }

        return finalSource
    }
}

/// Documentation for MergerRewriter
class MergerRewriter: SyntaxRewriter {
    /// Documentation for generatedDecls
    let generatedDecls: [String: DeclSyntax]
    /// Documentation for visitedDecls
    var visitedDecls: Set<String> = []

    /// Documentation for initializer
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Replace the node but keep the original leading trivia (comments, whitespace)
            /// Documentation for newDecl
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            /// Documentation for newDecl
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            /// Documentation for newDecl
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
}
