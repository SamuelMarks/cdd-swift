/// Data models representing JSON-formatted executable API documentation snippets and legacy Swagger 2.0 `CollectionFormat`.

/// Legacy Swagger 2.0 `collectionFormat` values specifying array parameter, item, and header serialization.
public enum CollectionFormat: RawRepresentable, Codable, Equatable, Hashable, Sendable, CaseIterable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// Comma-separated values (`"csv"`, e.g. `foo,bar`).
    case csv
    /// Space-separated values (`"ssv"`, e.g. `foo bar`).
    case ssv
    /// Tab-separated values (`"tsv"`, e.g. `foo\tbar`).
    case tsv
    /// Pipe-separated values (`"pipes"`, e.g. `foo|bar`).
    case pipes
    /// Multiple parameter instances rather than multiple values (`"multi"`, e.g. `foo=bar&foo=baz`).
    case multi
    /// Custom or extension collection format string.
    case custom(String)

    /// All standard Swagger 2.0 `CollectionFormat` cases.
    public static var allCases: [CollectionFormat] {
        [.csv, .ssv, .tsv, .pipes, .multi]
    }

    /// Lookup table mapping canonical raw values to standard `CollectionFormat` cases.
    private static let byRawValue: [String: CollectionFormat] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) }
    )

    /// The raw string representation of the collection format.
    public var rawValue: String {
        switch self {
        case .csv: "csv"
        case .ssv: "ssv"
        case .tsv: "tsv"
        case .pipes: "pipes"
        case .multi: "multi"
        case let .custom(val): val
        }
    }

    /// Textual description matching `rawValue`.
    public var description: String {
        rawValue
    }

    /// The element delimiter string used when joining array items for non-exploded serialization.
    public var delimiter: String {
        switch self {
        case .csv, .multi, .custom: ","
        case .ssv: " "
        case .tsv: "\t"
        case .pipes: "|"
        }
    }

    /// Maps this Swagger 2.0 `CollectionFormat` to its equivalent OpenAPI 3.x `ParameterStyle` for a given parameter location.
    ///
    /// - Parameter location: The `ParameterLocation` where the parameter is transmitted.
    /// - Returns: The corresponding `ParameterStyle`.
    public func openAPIStyle(for location: ParameterLocation) -> ParameterStyle {
        switch self {
        case .ssv:
            .spaceDelimited
        case .tsv:
            .custom("tabDelimited")
        case .pipes:
            .pipeDelimited
        case .csv, .multi, .custom:
            (location == .query || location == .cookie || location == .formData) ? .form : .simple
        }
    }

    /// Whether this `CollectionFormat` expands array items into repeated key-value pairs (`true` only for `.multi`).
    public var openAPIExplode: Bool {
        self == .multi
    }

    /// Initializes a `CollectionFormat` from its raw string representation.
    ///
    /// - Parameter rawValue: The Swagger 2.0 collection format string.
    public init(rawValue: String) {
        self = Self.byRawValue[rawValue] ?? .custom(rawValue)
    }

    /// Initializes a `CollectionFormat` from a string literal.
    ///
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Decodes a `CollectionFormat` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the value is not a string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    /// Encodes this `CollectionFormat` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Represents the root object for documentation JSON output.
public struct DocsJsonOutput: Codable, Equatable, Sendable {
    /// The programming language of the snippet.
    public let language: String
    /// The list of API operations documented.
    public let operations: [DocsJsonOperation]
    /// Optional list of incoming OpenAPI webhooks documented.
    public let webhooks: [DocsJsonOperation]?
    /// Optional list of Arazzo workflows documented.
    public let workflows: [DocsJsonWorkflow]?

    /// Initializes a `DocsJsonOutput` root container.
    ///
    /// - Parameters:
    ///   - language: The programming language identifier (e.g. `"swift"`).
    ///   - operations: The list of documented API operations.
    ///   - webhooks: Optional list of documented incoming OpenAPI webhooks.
    ///   - workflows: Optional list of documented Arazzo workflows.
    public init(
        language: String,
        operations: [DocsJsonOperation],
        webhooks: [DocsJsonOperation]? = nil,
        workflows: [DocsJsonWorkflow]? = nil
    ) {
        self.language = language
        self.operations = operations
        self.webhooks = webhooks
        self.workflows = workflows
    }
}

/// Represents a single documented Arazzo workflow.
public struct DocsJsonWorkflow: Codable, Equatable, Sendable {
    /// The unique workflow identifier.
    public let workflowId: String
    /// Optional short summary of the workflow.
    public let summary: String?
    /// The code snippet parts.
    public let code: DocsJsonCode

    /// Initializes a `DocsJsonWorkflow` entry.
    ///
    /// - Parameters:
    ///   - workflowId: The unique workflow identifier.
    ///   - summary: Optional short summary of the workflow.
    ///   - code: The structured code snippet components.
    public init(workflowId: String, summary: String? = nil, code: DocsJsonCode) {
        self.workflowId = workflowId
        self.summary = summary
        self.code = code
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
