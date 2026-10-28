/// Unified error domain and `$ref` helper utilities for `CDDSwift` and `cdd-swift-cli`.
#if os(WASI)
    @_exported import FoundationEssentials
#else
    @_exported import Foundation
#endif

/// Extracts the trailing identifier from an OpenAPI `$ref` pointer (e.g., `"#/components/schemas/User"` -> `"User"`).
///
/// - Parameter ref: The `$ref` string.
/// - Returns: The trailing component after the last `"/"`, or `ref` if no `"/"` is present.
public func lastPathSegment(_ ref: String) -> String {
    let parts = ref.components(separatedBy: "/")
    return parts[parts.count - 1]
}

/// A unified, strongly-typed error enumeration representing all failure modes across `CDDSwift` and `cdd-swift-cli`.
public enum CDDError: Error, Equatable, CustomStringConvertible, LocalizedError, Sendable {
    /// Indicates that an OpenAPI or JSON-RPC payload is not valid JSON.
    case invalidJSON(String)
    /// Indicates that decoding a file at the given path as UTF-8 failed.
    case utf8DecodingFailed(path: String)
    /// Indicates a POSIX or file system I/O failure.
    case fileIOError(path: String, operation: String, errno: Int32, message: String)
    /// Indicates an error in the Model Context Protocol (MCP) transport layer.
    case mcpTransportError(String)
    /// Indicates that launching an external process or CLI command failed.
    case processExecutionFailed(executable: String, message: String)
    /// Indicates that a value failed schema validation constraints.
    case validationFailed(field: String, reason: String)
    /// Indicates an Arazzo specification validation error.
    case arazzoValidationError(String)
    /// Indicates an error evaluating an Arazzo runtime expression.
    case arazzoExpressionEvaluationError(expression: String, context: String)
    /// Indicates that an Arazzo workflow step execution failed.
    case arazzoStepExecutionFailed(stepId: String, reason: String)
    /// Indicates that an Arazzo workflow identifier could not be found.
    case arazzoWorkflowNotFound(String)
    /// Indicates a circular dependency in workflow or step dependencies.
    case arazzoCircularDependency(workflowId: String)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case let .invalidJSON(reason):
            "Invalid JSON: \(reason)"
        case let .utf8DecodingFailed(path):
            "Could not decode file at \(path) as UTF-8."
        case let .fileIOError(path, operation, code, message):
            "File I/O error during \(operation) at \(path) (errno \(code)): \(message)"
        case let .mcpTransportError(detail):
            "MCP transport error: \(detail)"
        case let .processExecutionFailed(executable, message):
            "Process execution failed for \(executable): \(message)"
        case let .validationFailed(field, reason):
            "Validation failed for '\(field)': \(reason)"
        case let .arazzoValidationError(message):
            "Arazzo validation error: \(message)"
        case let .arazzoExpressionEvaluationError(expression, context):
            "Arazzo expression evaluation error for '\(expression)' in context '\(context)'"
        case let .arazzoStepExecutionFailed(stepId, reason):
            "Arazzo step execution failed for '\(stepId)': \(reason)"
        case let .arazzoWorkflowNotFound(workflowId):
            "Arazzo workflow not found: '\(workflowId)'"
        case let .arazzoCircularDependency(workflowId):
            "Arazzo circular dependency detected involving workflow '\(workflowId)'"
        }
    }

    /// The localized description of the error for `LocalizedError` conformance.
    public var errorDescription: String? {
        description
    }
}

#if os(WASI)
    /// Lightweight character set descriptor used on WASI when compiling against `FoundationEssentials` without ICU.
    public enum WASICharacterSet: Sendable {
        /// Horizontal whitespace characters (`" "` and `"\t"`).
        case whitespaces
        /// Line break characters (`"\n"` and `"\r"`).
        case newlines
        /// Whitespace and newline characters (`" "`, `"\t"`, `"\n"`, and `"\r"`).
        case whitespacesAndNewlines

        /// Evaluates whether the given `Character` belongs to this character set.
        ///
        /// - Parameter char: The character to test.
        /// - Returns: `true` if `char` is a member of this set, `false` otherwise.
        public func contains(_ char: Character) -> Bool {
            switch self {
            case .whitespaces:
                char == " " || char == "\t"
            case .newlines:
                char.isNewline
            case .whitespacesAndNewlines:
                char.isWhitespace || char.isNewline
            }
        }
    }

    public extension StringProtocol {
        /// Returns a new string made by removing characters contained in `set` from both ends of the receiver.
        ///
        /// - Parameter set: The `WASICharacterSet` of characters to trim.
        /// - Returns: The trimmed `String`.
        func trimmingCharacters(in set: WASICharacterSet) -> String {
            guard let start = firstIndex(where: { !set.contains($0) }),
                  let end = lastIndex(where: { !set.contains($0) })
            else {
                return ""
            }
            return String(self[start ... end])
        }

        /// Returns an array containing substrings from the receiver that have been divided by characters in `set`.
        ///
        /// - Parameter set: The `WASICharacterSet` delimiter set.
        /// - Returns: An array of substrings converted to `String`.
        func components(separatedBy set: WASICharacterSet) -> [String] {
            String(self).split(omittingEmptySubsequences: false, whereSeparator: { set.contains($0) }).map(String.init)
        }

        /// Returns a new string in which all occurrences of a target string in the receiver are replaced by another string.
        ///
        /// - Parameters:
        ///   - target: The substring to replace.
        ///   - replacement: The replacement string.
        /// - Returns: A new string with all occurrences of `target` replaced by `replacement`.
        func replacingOccurrences(of target: some StringProtocol, with replacement: some StringProtocol) -> String {
            components(separatedBy: target).joined(separator: String(replacement))
        }

        /// Finds and returns the range of the first occurrence of a given string within the optional search range.
        ///
        /// - Parameters:
        ///   - target: The substring to search for.
        ///   - searchRange: Optional range within the receiver to search.
        /// - Returns: The `Range<Index>` of the first match, or `nil` if not found.
        func range(of target: some StringProtocol, range searchRange: Range<Index>? = nil) -> Range<Index>? {
            let slice = searchRange.map { self[$0] } ?? self[startIndex ..< endIndex]
            return slice.firstRange(of: target)
        }
    }

    public extension Error {
        /// Returns a human-readable description of the error on WASI without linking `Foundation` ICU tables.
        var localizedDescription: String {
            if let localized = self as? LocalizedError, let desc = localized.errorDescription {
                return desc
            }
            return String(describing: self)
        }
    }
#endif
