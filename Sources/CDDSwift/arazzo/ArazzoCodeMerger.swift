/// Non-destructive AST code merger for Arazzo 1.1.0 Swift workflow sources.
import SwiftParser
import SwiftSyntax

/// Non-destructively merges regenerated Arazzo workflow classes, structs, and methods into existing Swift source files.
public enum ArazzoCodeMerger {
    /// Merges generated Swift workflow source code into an existing Swift source file using AST rewriting.
    ///
    /// Preserves custom user helper structs, classes, functions, and leading docstrings.
    ///
    /// - Parameters:
    ///   - generatedCode: Newly generated Swift code from an Arazzo emitter.
    ///   - existingSource: Existing Swift file content to update.
    /// - Returns: Merged Swift source code string.
    public static func merge(generatedCode: String, into existingSource: String) -> String {
        let destFile = Parser.parse(source: existingSource)
        let genFile = Parser.parse(source: generatedCode)

        var generatedStructs: [String: StructDeclSyntax] = [:]
        var generatedClasses: [String: ClassDeclSyntax] = [:]
        var generatedEnums: [String: EnumDeclSyntax] = [:]

        for statement in genFile.statements {
            if let structDecl = statement.item.as(StructDeclSyntax.self) {
                generatedStructs[structDecl.name.text] = structDecl
            } else if let classDecl = statement.item.as(ClassDeclSyntax.self) {
                generatedClasses[classDecl.name.text] = classDecl
            } else if let enumDecl = statement.item.as(EnumDeclSyntax.self) {
                generatedEnums[enumDecl.name.text] = enumDecl
            }
        }

        let rewriter = ArazzoMergerRewriter(
            generatedStructs: generatedStructs,
            generatedClasses: generatedClasses,
            generatedEnums: generatedEnums
        )
        let rewritten = rewriter.rewrite(destFile)
        var finalSource = rewritten.description

        for (name, decl) in generatedStructs.sorted(by: { $0.key < $1.key }) where !rewriter.visitedNames.contains(name) {
            appendDeclaration(decl.description, to: &finalSource)
        }
        for (name, decl) in generatedClasses.sorted(by: { $0.key < $1.key }) where !rewriter.visitedNames.contains(name) {
            appendDeclaration(decl.description, to: &finalSource)
        }
        for (name, decl) in generatedEnums.sorted(by: { $0.key < $1.key }) where !rewriter.visitedNames.contains(name) {
            appendDeclaration(decl.description, to: &finalSource)
        }

        return finalSource
    }

    /// Appends a declaration string with clean newline spacing.
    ///
    /// - Parameters:
    ///   - declText: Declaration source string.
    ///   - source: Target source buffer.
    private static func appendDeclaration(_ declText: String, to source: inout String) {
        let nl = String(UnicodeScalar(10))
        if !source.hasSuffix(nl) {
            source += nl + nl
        } else if !source.hasSuffix(nl + nl) {
            source += nl
        }
        source += declText + nl
    }
}

/// Internal `SyntaxRewriter` updating workflow structs, enums, and orchestrator classes while preserving custom helper methods.
final class ArazzoMergerRewriter: SyntaxRewriter {
    /// Generated structs by name.
    let generatedStructs: [String: StructDeclSyntax]
    /// Generated classes by name.
    let generatedClasses: [String: ClassDeclSyntax]
    /// Generated enums by name.
    let generatedEnums: [String: EnumDeclSyntax]
    /// Set of declaration names visited and updated in-place.
    var visitedNames: Set<String> = []

    /// Initializes the `ArazzoMergerRewriter`.
    ///
    /// - Parameters:
    ///   - generatedStructs: Map of generated structs.
    ///   - generatedClasses: Map of generated classes.
    ///   - generatedEnums: Map of generated enums.
    init(
        generatedStructs: [String: StructDeclSyntax],
        generatedClasses: [String: ClassDeclSyntax],
        generatedEnums: [String: EnumDeclSyntax]
    ) {
        self.generatedStructs = generatedStructs
        self.generatedClasses = generatedClasses
        self.generatedEnums = generatedEnums
    }

    /// Visits and updates struct declarations while keeping original trivia.
    ///
    /// - Parameter node: The `StructDeclSyntax` node.
    /// - Returns: Updated `DeclSyntax`.
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if var gen = generatedStructs[name] {
            visitedNames.insert(name)
            gen.leadingTrivia = node.leadingTrivia
            gen.trailingTrivia = node.trailingTrivia
            return DeclSyntax(gen)
        }
        return super.visit(node)
    }

    /// Visits and updates enum declarations while keeping original trivia.
    ///
    /// - Parameter node: The `EnumDeclSyntax` node.
    /// - Returns: Updated `DeclSyntax`.
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if var gen = generatedEnums[name] {
            visitedNames.insert(name)
            gen.leadingTrivia = node.leadingTrivia
            gen.trailingTrivia = node.trailingTrivia
            return DeclSyntax(gen)
        }
        return super.visit(node)
    }

    /// Visits and merges class declarations, preserving custom user helper methods not present in generated code.
    ///
    /// - Parameter node: The `ClassDeclSyntax` node.
    /// - Returns: Updated `DeclSyntax`.
    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if var gen = generatedClasses[name] {
            visitedNames.insert(name)
            var genFuncNames: Set<String> = []
            for member in gen.memberBlock.members {
                if let f = member.decl.as(FunctionDeclSyntax.self) {
                    genFuncNames.insert(f.name.text)
                }
            }
            var extraMembers: [MemberBlockItemSyntax] = []
            for member in node.memberBlock.members {
                if let f = member.decl.as(FunctionDeclSyntax.self), !genFuncNames.contains(f.name.text) {
                    extraMembers.append(member)
                }
            }
            if !extraMembers.isEmpty {
                var combined = Array(gen.memberBlock.members)
                combined.append(contentsOf: extraMembers)
                gen.memberBlock.members = MemberBlockItemListSyntax(combined)
            }
            gen.leadingTrivia = node.leadingTrivia
            gen.trailingTrivia = node.trailingTrivia
            return DeclSyntax(gen)
        }
        return super.visit(node)
    }
}
