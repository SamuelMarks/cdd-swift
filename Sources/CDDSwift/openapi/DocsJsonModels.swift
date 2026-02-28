import Foundation

public struct DocsJsonOutput: Codable {
    public let language: String
    public let operations: [DocsJsonOperation]
    
    public init(language: String, operations: [DocsJsonOperation]) {
        self.language = language
        self.operations = operations
    }
}

public struct DocsJsonOperation: Codable {
    public let method: String
    public let path: String
    public let operationId: String?
    public let code: DocsJsonCode
    
    public init(method: String, path: String, operationId: String?, code: DocsJsonCode) {
        self.method = method
        self.path = path
        self.operationId = operationId
        self.code = code
    }
}

public struct DocsJsonCode: Codable {
    public let imports: String?
    public let wrapper_start: String?
    public let snippet: String
    public let wrapper_end: String?
    
    public init(imports: String?, wrapper_start: String?, snippet: String, wrapper_end: String?) {
        self.imports = imports
        self.wrapper_start = wrapper_start
        self.snippet = snippet
        self.wrapper_end = wrapper_end
    }
}
