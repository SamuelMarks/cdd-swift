/// Data models representing JSON-formatted executable API documentation snippets.
import Foundation

/// Represents the root object for documentation JSON output.
public struct DocsJsonOutput: Codable, Equatable, Sendable {
    /// The programming language of the snippet.
    public let language: String
    /// The list of API operations documented.
    public let operations: [DocsJsonOperation]

    /// Initializes a `DocsJsonOutput` root container.
    ///
    /// - Parameters:
    ///   - language: The programming language identifier (e.g. `"swift"`).
    ///   - operations: The list of documented API operations.
    public init(language: String, operations: [DocsJsonOperation]) {
        self.language = language
        self.operations = operations
    }
}

/// Represents a single documented API operation.
public struct DocsJsonOperation: Codable, Equatable, Sendable {
    /// The HTTP method.
    public let method: String
    /// The API endpoint path.
    public let path: String
    /// The unique operation identifier.
    public let operationId: String?
    /// The code snippet parts.
    public let code: DocsJsonCode

    /// Initializes a `DocsJsonOperation` entry.
    ///
    /// - Parameters:
    ///   - method: The HTTP verb (e.g. `"get"`, `"post"`).
    ///   - path: The endpoint URL path template.
    ///   - operationId: Optional OpenAPI operation identifier.
    ///   - code: The structured code snippet components.
    public init(method: String, path: String, operationId: String?, code: DocsJsonCode) {
        self.method = method
        self.path = path
        self.operationId = operationId
        self.code = code
    }
}

/// Represents the segments of a code snippet.
public struct DocsJsonCode: Codable, Equatable, Sendable {
    /// Necessary module imports.
    public let imports: String?
    /// The setup code preceding the snippet.
    public let wrapper_start: String?
    /// The actual request snippet.
    public let snippet: String
    /// The teardown code following the snippet.
    public let wrapper_end: String?

    /// Initializes a `DocsJsonCode` snippet descriptor.
    ///
    /// - Parameters:
    ///   - imports: Optional import statements.
    ///   - wrapper_start: Optional enclosing class/function prologue.
    ///   - snippet: The core HTTP request invocation snippet.
    ///   - wrapper_end: Optional enclosing class/function epilogue.
    public init(imports: String?, wrapper_start: String?, snippet: String, wrapper_end: String?) {
        self.imports = imports
        self.wrapper_start = wrapper_start
        self.snippet = snippet
        self.wrapper_end = wrapper_end
    }
}
