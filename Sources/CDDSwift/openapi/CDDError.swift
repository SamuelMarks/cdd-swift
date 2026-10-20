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
    /// Indicates that encoding a string or payload to UTF-8 data failed.
    case utf8EncodingFailed
    /// Indicates that decoding a file at the given path as UTF-8 failed.
    case utf8DecodingFailed(path: String)
    /// Indicates a POSIX or file system I/O failure.
    case fileIOError(path: String, operation: String, errno: Int32, message: String)
    /// Indicates that a required CLI or tool argument was not provided.
    case missingRequiredArgument(String)
    /// Indicates that a URL string could not be parsed as a valid URL.
    case invalidURL(String)
    /// Indicates an unsupported OpenAPI schema construct.
    case unsupportedSchemaConstruct(String)
    /// Indicates an unresolvable or malformed `$ref` pointer.
    case invalidReference(String)
    /// Indicates a failure while parsing Swift syntax into an OpenAPI AST.
    case astParsingFailed(String)
    /// Indicates a failure while emitting Swift source code.
    case codeGenerationFailed(String)
    /// Indicates an error in the Model Context Protocol (MCP) transport layer.
    case mcpTransportError(String)
    /// Indicates a JSON-RPC protocol error with a numeric code and message.
    case jsonRpcError(code: Int, message: String)
    /// Indicates that launching an external process failed.
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
    /// Indicates a structured file system failure with an operation, path, and POSIX errno code.
    case fileSystemError(operation: String, path: String, errnoCode: Int32)
    /// Indicates that a CLI or subprocess command execution failed.
    case commandExecutionFailed(command: String, reason: String)
    /// Indicates an unsupported OpenAPI, Swagger, or Arazzo specification version.
    case unsupportedSpecificationVersion(spec: String, version: String)
    /// Indicates that a requested Model Context Protocol tool does not exist.
    case mcpToolNotFound(name: String)
    /// Indicates that a requested Model Context Protocol resource URI does not exist.
    case mcpResourceNotFound(uri: String)
    /// Indicates that encoding a model to JSON failed.
    case jsonEncodingFailed(reason: String)
    /// Indicates that decoding a model from JSON failed.
    case jsonDecodingFailed(reason: String)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case let .invalidJSON(reason):
            return "Invalid JSON: \(reason)"
        case .utf8EncodingFailed:
            return "Failed to encode string as UTF-8 data."
        case let .utf8DecodingFailed(path):
            return "Could not decode file at \(path) as UTF-8."
        case let .fileIOError(path, operation, code, message):
            return "File I/O error during \(operation) at \(path) (errno \(code)): \(message)"
        case let .missingRequiredArgument(arg):
            return "Missing required argument: \(arg)"
        case let .invalidURL(url):
            return "Invalid URL: \(url)"
        case let .unsupportedSchemaConstruct(detail):
            return "Unsupported schema construct: \(detail)"
        case let .invalidReference(ref):
            return "Invalid reference: \(ref)"
        case let .astParsingFailed(detail):
            return "AST parsing failed: \(detail)"
        case let .codeGenerationFailed(detail):
            return "Code generation failed: \(detail)"
        case let .mcpTransportError(detail):
            return "MCP transport error: \(detail)"
        case let .jsonRpcError(code, message):
            return "JSON-RPC error (\(code)): \(message)"
        case let .processExecutionFailed(executable, message):
            return "Process execution failed for \(executable): \(message)"
        case let .validationFailed(field, reason):
            return "Validation failed for '\(field)': \(reason)"
        case let .arazzoValidationError(message):
            return "Arazzo validation error: \(message)"
        case let .arazzoExpressionEvaluationError(expression, context):
            return "Arazzo expression evaluation error for '\(expression)' in context '\(context)'"
        case let .arazzoStepExecutionFailed(stepId, reason):
            return "Arazzo step execution failed for '\(stepId)': \(reason)"
        case let .arazzoWorkflowNotFound(workflowId):
            return "Arazzo workflow not found: '\(workflowId)'"
        case let .arazzoCircularDependency(workflowId):
            return "Arazzo circular dependency detected involving workflow '\(workflowId)'"
        case let .fileSystemError(operation, path, errnoCode):
            return "File system error during \(operation) at '\(path)' (errno \(errnoCode))"
        case let .commandExecutionFailed(command, reason):
            return "Command '\(command)' failed: \(reason)"
        case let .unsupportedSpecificationVersion(spec, version):
            return "Unsupported \(spec) specification version: \(version)"
        case let .mcpToolNotFound(name):
            return "Unknown MCP tool: '\(name)'"
        case let .mcpResourceNotFound(uri):
            return "Unknown MCP resource URI: '\(uri)'"
        case let .jsonEncodingFailed(reason):
            return "JSON encoding failed: \(reason)"
        case let .jsonDecodingFailed(reason):
            return "JSON decoding failed: \(reason)"
        }
    }

    /// The localized description of the error for `LocalizedError` conformance.
    public var errorDescription: String? {
        return description
    }
}
