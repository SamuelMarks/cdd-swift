/// Unified error domain and `$ref` helper utilities for `CDDSwift` and `cdd-swift-cli`.
import Foundation

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
