import Foundation

/// Represents the root object for documentation JSON output.
public struct DocsJsonOutput: Codable {
    /// The programming language of the snippet.
    public let language: String
    /// The list of API operations documented.
    public let operations: [DocsJsonOperation]

    /// Initializer.
    public init(language: String, operations: [DocsJsonOperation]) {
        self.language = language
        self.operations = operations
    }
}

/// Represents a single documented API operation.
public struct DocsJsonOperation: Codable {
    /// The HTTP method.
    public let method: String
    /// The API endpoint path.
    public let path: String
    /// The unique operation identifier.
    public let operationId: String?
    /// The code snippet parts.
    public let code: DocsJsonCode

    /// Initializer.
    public init(method: String, path: String, operationId: String?, code: DocsJsonCode) {
        self.method = method
        self.path = path
        self.operationId = operationId
        self.code = code
    }
}

/// Represents the segments of a code snippet.
public struct DocsJsonCode: Codable {
    /// Necessary module imports.
    public let imports: String?
    /// The setup code preceding the snippet.
    public let wrapper_start: String?
    /// The actual request snippet.
    public let snippet: String
    /// The teardown code following the snippet.
    public let wrapper_end: String?

    /// Initializer.
    public init(imports: String?, wrapper_start: String?, snippet: String, wrapper_end: String?) {
        self.imports = imports
        self.wrapper_start = wrapper_start
        self.snippet = snippet
        self.wrapper_end = wrapper_end
    }
}
