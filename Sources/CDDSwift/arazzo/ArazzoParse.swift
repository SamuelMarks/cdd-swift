/// Programmatic document builder and SwiftSyntax AST parser for Arazzo 1.1.0 specifications.
import SwiftParser
import SwiftSyntax

/// Fluent builder for constructing strongly typed `ArazzoSpecification` documents programmatically.
public final class ArazzoDocumentBuilder {
    /// The specification version string.
    private var arazzoVersion: String = "1.1.0"
    /// Optional canonical self URI.
    private var selfRef: String?
    /// Specification metadata info.
    private var info: ArazzoInfo
    /// Registered source descriptions.
    private var sourceDescriptions: [ArazzoSourceDescription] = []
    /// Registered workflows.
    private var workflows: [ArazzoWorkflow] = []
    /// Optional reusable components registry.
    private var components: ArazzoComponents?

    /// Initializes a new `ArazzoDocumentBuilder`.
    ///
    /// - Parameters:
    ///   - title: The workflow specification title.
    ///   - version: The workflow specification version.
    ///   - summary: Optional short summary.
    ///   - description: Optional extended Markdown description.
    public init(title: String, version: String, summary: String? = nil, description: String? = nil) {
        info = ArazzoInfo(title: title, summary: summary, description: description, version: version)
    }

    /// Sets the canonical `$self` URI for the Arazzo document.
    ///
    /// - Parameter uri: Canonical URI string.
    /// - Returns: Self for fluent chaining.
    @discardableResult
    public func withSelfRef(_ uri: String) -> ArazzoDocumentBuilder {
        selfRef = uri
        return self
    }

    /// Adds a source description to the Arazzo document.
    ///
    /// - Parameters:
    ///   - name: Unique source description name.
    ///   - url: URL or file path to the target specification.
    ///   - type: Source specification type (`openapi`, `asyncapi`, `arazzo`).
    /// - Returns: Self for fluent chaining.
    @discardableResult
    public func addSourceDescription(name: String, url: String, type: ArazzoSourceType = .openapi) -> ArazzoDocumentBuilder {
        sourceDescriptions.append(ArazzoSourceDescription(name: name, url: url, type: type))
        return self
    }

    /// Adds a workflow definition to the Arazzo document.
    ///
    /// - Parameter workflow: The `ArazzoWorkflow` to append.
    /// - Returns: Self for fluent chaining.
    @discardableResult
    public func addWorkflow(_ workflow: ArazzoWorkflow) -> ArazzoDocumentBuilder {
        workflows.append(workflow)
        return self
    }

    /// Sets the reusable components container on the Arazzo document.
    ///
    /// - Parameter components: The `ArazzoComponents` object.
    /// - Returns: Self for fluent chaining.
    @discardableResult
    public func withComponents(_ components: ArazzoComponents) -> ArazzoDocumentBuilder {
        self.components = components
        return self
    }

    /// Builds and returns the constructed `ArazzoSpecification`.
    ///
    /// - Returns: Strongly typed `ArazzoSpecification`.
    public func build() -> ArazzoSpecification {
        let sources = sourceDescriptions.isEmpty
            ? [ArazzoSourceDescription(name: "defaultApi", url: "./openapi.json", type: .openapi)]
            : sourceDescriptions
        return ArazzoSpecification(
            arazzo: arazzoVersion,
            selfRef: selfRef,
            info: info,
            sourceDescriptions: sources,
            workflows: workflows,
            components: components
        )
    }

    /// Builds and serializes the `ArazzoSpecification` into a formatted JSON string.
    ///
    /// - Returns: Formatted JSON string.
    /// - Throws: Encoding error if serialization fails.
    public func serialize() throws -> String {
        try ArazzoEmitter.emitJSON(from: build())
    }
}

/// Parses Swift source code using `SwiftSyntax` to extract `ArazzoSpecification` workflows, steps, assertions, and retry policies.
public final class SwiftASTArazzoParser {
    /// Initializes a new `SwiftASTArazzoParser`.
    public init() {}

    /// Parses Swift workflow source code into an `ArazzoSpecification`.
    ///
    /// - Parameter source: Swift source code containing workflow orchestrator classes or test suites.
    /// - Returns: Extracted `ArazzoSpecification`.
    /// - Throws: `CDDError` if workflow validation fails.
    public func parseSpecification(from source: String) throws -> ArazzoSpecification {
        let sourceFile = Parser.parse(source: source)
        let visitor = WorkflowASTVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)

        let builder = ArazzoDocumentBuilder(
            title: visitor.extractedTitle ?? "Extracted Workflows",
            version: "1.0.0",
            summary: visitor.extractedSummary
        )

        for wf in visitor.workflows {
            builder.addWorkflow(wf)
        }

        return builder.build()
    }
}

/// AST `SyntaxVisitor` inspecting Swift classes, structs, methods, docstrings, and expressions to reconstruct Arazzo workflows.
public final class WorkflowASTVisitor: SyntaxVisitor {
    /// Extracted suite title from class/struct docstring.
    public var extractedTitle: String?
    /// Extracted suite summary from class/struct docstring.
    public var extractedSummary: String?
    /// Extracted workflows from methods.
    public var workflows: [ArazzoWorkflow] = []
    /// Discovered input DTO schemas keyed by struct name.
    public var inputSchemas: [String: Schema] = [:]

    /// Initializes the `WorkflowASTVisitor`.
    ///
    /// - Parameter viewMode: Syntax tree traversal mode.
    override public init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    /// Visits struct declarations to capture `*Inputs` DTOs or `@Suite` workflow structs.
    ///
    /// - Parameter node: The `StructDeclSyntax` node.
    /// - Returns: `.visitChildren` to inspect nested members.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name.hasSuffix("Inputs") {
            let properties = Self.extractInputProperties(from: node.memberBlock)
            if !properties.isEmpty {
                inputSchemas[name] = Schema(type: "object", properties: properties)
            }
        }
        return .visitChildren
    }

    /// Extracts property schemas from an `*Inputs` struct's `MemberBlockSyntax`.
    ///
    /// - Parameter memberBlock: The `MemberBlockSyntax` of the struct.
    /// - Returns: Dictionary mapping property names to their `Schema` definitions.
    private static func extractInputProperties(from memberBlock: MemberBlockSyntax) -> [String: Schema] {
        var properties: [String: Schema] = [:]
        for member in memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in varDecl.bindings {
                guard let ident = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnn = binding.typeAnnotation,
                      ident.identifier.text != "parameters"
                else {
                    continue
                }
                let rawType = typeAnn.type.description
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "?", with: "")
                properties[ident.identifier.text] = Schema(type: mapSwiftInputType(rawType).rawValue)
            }
        }
        return properties
    }

    /// Maps a Swift primitive type name on an `*Inputs` struct to a JSON Schema type.
    ///
    /// - Parameter rawType: The non-optional Swift type string.
    /// - Returns: The corresponding JSON Schema type.
    private static func mapSwiftInputType(_ rawType: String) -> SchemaType {
        switch rawType {
        case "Int": .integer
        case "Double", "Float": .number
        case "Bool": .boolean
        default: .string
        }
    }

    /// Visits class declarations to identify `WorkflowsClient`, `WorkflowOrchestrator`, or `*Tests` classes.
    ///
    /// - Parameter node: The `ClassDeclSyntax` node.
    /// - Returns: `.visitChildren` to inspect methods.
    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let trivia = node.leadingTrivia.description
        parseHeaderDocstring(trivia)
        return .visitChildren
    }

    /// Visits function declarations to extract workflow steps, assertions, and retry actions.
    ///
    /// - Parameter node: The `FunctionDeclSyntax` node.
    /// - Returns: `.skipChildren` once function body is analyzed.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let funcName = node.name.text
        let ignoredFuncs: Set = [
            "setUp",
            "tearDown",
            "run",
            "runAllProbes",
            "printOutputs",
            "sanitizeIdentifier",
            "pascalCase",
            "kebabCase"
        ]
        if ignoredFuncs.contains(funcName) || funcName.hasPrefix("probe") {
            return .skipChildren
        }

        let leadingDoc = node.leadingTrivia.description
        let isAnnotatedWorkflow = leadingDoc.contains("@Workflow") || leadingDoc.contains("Executes workflow")
        let isTestWorkflow = funcName.hasPrefix("test") && funcName.count > 4
        guard isAnnotatedWorkflow || isTestWorkflow || hasInputParameter(node) else {
            return .skipChildren
        }

        let workflowId = extractWorkflowId(from: funcName, doc: leadingDoc)
        let summary = extractSummary(from: leadingDoc)
        let inputSchema = resolveInputSchema(for: node)

        var steps: [ArazzoStep] = []
        if let body = node.body {
            let bodyVisitor = WorkflowStepBodyVisitor(defaultStepIdPrefix: workflowId)
            bodyVisitor.walk(body)
            bodyVisitor.finalizePendingStep()
            steps = bodyVisitor.steps
        }
        if steps.isEmpty {
            steps = [ArazzoStep(stepId: "step1", operationId: workflowId)]
        }

        let wf = ArazzoWorkflow(
            workflowId: workflowId,
            summary: summary,
            inputs: inputSchema,
            steps: steps
        )
        workflows.append(wf)
        return .skipChildren
    }

    /// Parses leading trivia docstrings on classes for title and summary metadata.
    ///
    /// - Parameter trivia: Raw leading trivia string.
    private func parseHeaderDocstring(_ trivia: String) {
        for line in trivia.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("///") {
                let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if let backtickRange = text.range(of: "`"),
                   let endRange = text.range(of: "`", range: backtickRange.upperBound ..< text.endIndex) {
                    let candidate = String(text[backtickRange.upperBound ..< endRange.lowerBound])
                    if candidate != "ArazzoSpecification", extractedTitle == nil {
                        extractedTitle = candidate
                    }
                }
                if extractedSummary == nil, !text.isEmpty {
                    extractedSummary = text
                }
            }
        }
    }

    /// Checks whether a function declaration accepts a `*Inputs` typed parameter.
    ///
    /// - Parameter node: The `FunctionDeclSyntax` node.
    /// - Returns: `true` if a parameter type ends with `Inputs`.
    private func hasInputParameter(_ node: FunctionDeclSyntax) -> Bool {
        for param in node.signature.parameterClause.parameters {
            let typeText = param.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if typeText.hasSuffix("Inputs") {
                return true
            }
        }
        return false
    }

    /// Resolves the `Schema` for a function's `*Inputs` parameter if previously parsed.
    ///
    /// - Parameter node: The `FunctionDeclSyntax` node.
    /// - Returns: Matched `Schema` or `nil`.
    private func resolveInputSchema(for node: FunctionDeclSyntax) -> Schema? {
        for param in node.signature.parameterClause.parameters {
            let typeText = param.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if let schema = inputSchemas[typeText] {
                return schema
            }
        }
        return nil
    }

    /// Extracts the canonical workflowId from the function name or `@Workflow(id: ...)` annotation.
    ///
    /// - Parameters:
    ///   - funcName: Raw function name.
    ///   - doc: Leading docstring trivia.
    /// - Returns: Resolved workflow identifier.
    private func extractWorkflowId(from funcName: String, doc: String) -> String {
        let q = String(UnicodeScalar(34))
        if let idRange = doc.range(of: "@Workflow(id: " + q),
           let endQuote = doc.range(of: q, range: idRange.upperBound ..< doc.endIndex) {
            return String(doc[idRange.upperBound ..< endQuote.lowerBound])
        }
        if let execRange = doc.range(of: "Executes workflow `"),
           let endTick = doc.range(of: "`", range: execRange.upperBound ..< doc.endIndex) {
            return String(doc[execRange.upperBound ..< endTick.lowerBound])
        }
        if funcName.hasPrefix("test"), funcName.count > 4 {
            let dropped = funcName.dropFirst(4)
            return dropped.prefix(1).lowercased() + dropped.dropFirst()
        }
        return funcName
    }

    /// Extracts a clean summary line from leading docstring comments.
    ///
    /// - Parameter doc: Leading docstring trivia.
    /// - Returns: Extracted summary or `nil`.
    private func extractSummary(from doc: String) -> String? {
        for line in doc.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("///") {
                let content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty, !content.hasPrefix("-"), !content.hasPrefix("@") {
                    return content
                }
            }
        }
        return nil
    }
}
