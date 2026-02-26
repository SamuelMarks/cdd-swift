import Foundation
import SwiftSyntax
import SwiftParser

/// Safely merges generated Swift code into an existing Swift file using AST.
/// Preserves whitespace and comments.
public struct SwiftCodeMerger {
    
    public static func merge(generatedCode: String, into destinationSource: String) -> String {
        let destFile = Parser.parse(source: destinationSource)
        let genFile = Parser.parse(source: generatedCode)
        
        // Extract all generated declarations (structs, enums, protocols, etc)
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
        
        // Find any new declarations that were not in the destination
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

class MergerRewriter: SyntaxRewriter {
    let generatedDecls: [String: DeclSyntax]
    var visitedDecls: Set<String> = []
    
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }
    
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Replace the node but keep the original leading trivia (comments, whitespace)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
    
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
