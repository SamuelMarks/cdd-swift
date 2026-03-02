import Foundation

/// Documentation for DocsJsonOutput
public struct DocsJsonOutput: Codable {
    /// Documentation for language
    public let language: String
    /// Documentation for operations
    public let operations: [DocsJsonOperation]

    /// Documentation for initializer
    public init(language: String, operations: [DocsJsonOperation]) {
        self.language = language
        self.operations = operations
    }
}

/// Documentation for DocsJsonOperation
public struct DocsJsonOperation: Codable {
    /// Documentation for method
    public let method: String
    /// Documentation for path
    public let path: String
    /// Documentation for operationId
    public let operationId: String?
    /// Documentation for code
    public let code: DocsJsonCode

    /// Documentation for initializer
    public init(method: String, path: String, operationId: String?, code: DocsJsonCode) {
        self.method = method
        self.path = path
        self.operationId = operationId
        self.code = code
    }
}

/// Documentation for DocsJsonCode
public struct DocsJsonCode: Codable {
    /// Documentation for imports
    public let imports: String?
    /// Documentation for wrapper_start
    public let wrapper_start: String?
    /// Documentation for snippet
    public let snippet: String
    /// Documentation for wrapper_end
    public let wrapper_end: String?

    /// Documentation for initializer
    public init(imports: String?, wrapper_start: String?, snippet: String, wrapper_end: String?) {
        self.imports = imports
        self.wrapper_start = wrapper_start
        self.snippet = snippet
        self.wrapper_end = wrapper_end
    }
}
