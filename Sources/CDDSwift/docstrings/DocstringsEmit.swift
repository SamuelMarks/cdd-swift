import Foundation

/// Emits a docstring for Swift code generation.
/// - Parameters:
///   - description: The documentation string to emit.
///   - indent: The indentation level.
/// - Returns: A formatted Swift docstring.
public func emitDocstring(_ description: String?, indent: Int = 0) -> String {
    guard let desc = description, !desc.isEmpty else { return "" }
    /// Documentation for prefix
    let prefix = String(repeating: " ", count: indent)

    // Sanitize basic Markdown/HTML issues for Swift documentation
    /// Documentation for sanitized
    let sanitized = desc.replacingOccurrences(of: "*/", with: "*\\/")

    /// Documentation for lines
    let lines = sanitized.split(separator: "\n")
    return lines.map { "\(prefix)/// \($0)" }.joined(separator: "\n") + "\n"
}
