/// SwiftSyntax leading trivia docstring parser.
import SwiftSyntax

/// Parses a doc comment from a SwiftSyntax node.
/// - Parameter node: The SwiftSyntax node to parse.
/// - Returns: The extracted doc comment as a string, or nil.
public func parseDocstring(from node: Syntax) -> String? {
    var docComment = ""
    for piece in node.leadingTrivia {
        switch piece {
        case let .docLineComment(text):
            let cleaned = text.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
            docComment += cleaned + "\n"
        case let .docBlockComment(text):
            docComment += text + "\n"
        default:
            break
        }
    }
    let trimmed = docComment.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
