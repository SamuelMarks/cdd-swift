/// Shared Swift identifier sanitization and case-conversion utilities for code emitters.

/// Centralizes Swift identifier sanitization, keyword escaping, and case conversions across `CDDSwift` emitters.
public enum SwiftIdentifierSanitizer {
    /// Reserved Swift keywords that must be escaped with backticks when used as identifiers.
    public static let swiftKeywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import",
        "init", "inout", "internal", "let", "open", "operator", "private", "precedencegroup",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var",
        "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while",
        "as", "false", "is", "nil", "self", "Self", "super", "throws", "true", "try"
    ]

    /// Sanitizes an arbitrary string into a valid Swift camelCase property, method, or enum case identifier.
    ///
    /// - Parameters:
    ///   - name: Raw input string (e.g. `"user-id"`, `"on/hookA"`, `"123value"`, `"default"`).
    ///   - fallback: Fallback identifier returned when `name` contains no alphanumeric characters.
    /// - Returns: A valid Swift identifier, backtick-escaped if it matches a Swift keyword.
    public static func sanitizeCamelCase(_ name: String, fallback: String = "identifier") -> String {
        let parts = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard let first = parts.first else { return fallback }
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        var combined = String(first.prefix(1).lowercased() + first.dropFirst() + tail.joined())
        if combined.first?.isNumber == true {
            combined = "_" + combined
        }
        return swiftKeywords.contains(combined) ? "`" + combined + "`" : combined
    }

    /// Converts an arbitrary string into a valid Swift PascalCase type name.
    ///
    /// - Parameters:
    ///   - name: Raw input string.
    ///   - fallback: Fallback type name returned when `name` contains no alphanumeric characters.
    /// - Returns: A valid Swift PascalCase identifier.
    public static func sanitizePascalCase(_ name: String, fallback: String = "WorkflowType") -> String {
        let parts = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !parts.isEmpty else { return fallback }
        var combined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        if combined.first?.isNumber == true {
            combined = "_" + combined
        }
        return combined
    }

    /// Converts a camelCase or mixed-delimiter string into a lowercase kebab-case CLI command or option name.
    ///
    /// - Parameters:
    ///   - name: Raw input string.
    ///   - fallback: Fallback string returned when `name` contains no alphanumeric characters.
    /// - Returns: Lowercase kebab-case string.
    public static func kebabCase(_ name: String, fallback: String = "arg") -> String {
        var result = ""
        for char in name {
            if char.isUppercase {
                if !result.isEmpty, !result.hasSuffix("-") {
                    result.append("-")
                }
                result.append(char.lowercased())
            } else if !char.isLetter, !char.isNumber {
                if !result.isEmpty, !result.hasSuffix("-") {
                    result.append("-")
                }
            } else {
                result.append(char.lowercased())
            }
        }
        return result.isEmpty ? fallback : result
    }
}
