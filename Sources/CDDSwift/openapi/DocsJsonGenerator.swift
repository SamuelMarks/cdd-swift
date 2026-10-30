/// Generator for producing JSON-formatted executable API code snippets from OpenAPI and Arazzo documents.

/// Generator for producing JSON-formatted API documentation.
public enum DocsJsonGenerator {
    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument) -> String {
        generate(from: document, includeImports: true, includeWrapping: true)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeImports: Whether to include Foundation and GeneratedAPI imports in the generated code snippet.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeImports: Bool) -> String {
        generate(from: document, includeImports: includeImports, includeWrapping: true)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeWrapping: Whether to wrap the snippet in an executable `@main` struct.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeWrapping: Bool) -> String {
        generate(from: document, includeImports: true, includeWrapping: includeWrapping)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeImports: Whether to include Foundation and GeneratedAPI imports in the generated code snippet.
    ///   - includeWrapping: Whether to wrap the snippet in an executable `@main` struct.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeImports: Bool, includeWrapping: Bool) -> String {
        generate(from: document, arazzo: nil, includeImports: includeImports, includeWrapping: includeWrapping)
    }

    /// Generates JSON documentation from an Arazzo 1.1.0 specification.
    ///
    /// - Parameters:
    ///   - specification: The parsed `ArazzoSpecification`.
    ///   - includeImports: Whether to include Foundation and GeneratedAPI imports in the generated code snippet.
    ///   - includeWrapping: Whether to wrap the snippet in an executable `@main` struct.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(
        from specification: ArazzoSpecification,
        includeImports: Bool = true,
        includeWrapping: Bool = true
    ) -> String {
        let baseUrl = specification.sourceDescriptions.first?.url ?? "https://api.example.com"
        let workflows = buildWorkflowSnippets(
            from: specification,
            baseUrl: baseUrl,
            includeImports: includeImports,
            includeWrapping: includeWrapping
        )
        let output = DocsJsonOutput(language: "swift", operations: [], webhooks: nil, workflows: workflows)
        return encodeDocsJsonOutputs([output])
    }

    /// Generates JSON documentation from an OpenAPI document and an optional Arazzo 1.1.0 specification.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - arazzo: Optional `ArazzoSpecification` containing multi-step workflows.
    ///   - includeImports: Whether to include Foundation and GeneratedAPI imports in the generated code snippet.
    ///   - includeWrapping: Whether to wrap the snippet in an executable `@main` struct.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(
        from document: OpenAPIDocument,
        arazzo: ArazzoSpecification?,
        includeImports: Bool = true,
        includeWrapping: Bool = true
    ) -> String {
        let baseUrl = resolveBaseUrl(from: document)
        let operations = buildPathOperations(
            from: document,
            baseUrl: baseUrl,
            includeImports: includeImports,
            includeWrapping: includeWrapping
        )
        let webhooks = buildWebhookOperations(
            from: document,
            baseUrl: baseUrl,
            includeImports: includeImports,
            includeWrapping: includeWrapping
        )
        let workflows = arazzo.map {
            buildWorkflowSnippets(
                from: $0,
                baseUrl: baseUrl,
                includeImports: includeImports,
                includeWrapping: includeWrapping
            )
        }

        let output = DocsJsonOutput(
            language: "swift",
            operations: operations,
            webhooks: webhooks.isEmpty ? nil : webhooks,
            workflows: workflows
        )
        return encodeDocsJsonOutputs([output])
    }

    /// Resolves the server base URL from an `OpenAPIDocument`, falling back to Swagger 2.0 `schemes`/`host`/`basePath` or
    /// `"https://api.example.com"`.
    ///
    /// - Parameter document: The `OpenAPIDocument`.
    /// - Returns: The resolved base URL string.
    private static func resolveBaseUrl(from document: OpenAPIDocument) -> String {
        if let serverUrl = document.servers?.first?.url, !serverUrl.isEmpty {
            return serverUrl
        }
        if let host = document.host, !host.isEmpty {
            let scheme = document.schemes?.first ?? "https"
            let basePath = document.basePath ?? ""
            return "\(scheme)://\(host)\(basePath)"
        }
        return "https://api.example.com"
    }

    /// Builds `DocsJsonOperation` entries for all paths and operations in an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The `OpenAPIDocument`.
    ///   - baseUrl: Resolved server base URL string.
    ///   - includeImports: Whether to include imports in the snippet.
    ///   - includeWrapping: Whether to include the `@main` wrapper around the snippet.
    /// - Returns: Array of `DocsJsonOperation` entries.
    private static func buildPathOperations(
        from document: OpenAPIDocument,
        baseUrl: String,
        includeImports: Bool,
        includeWrapping: Bool
    ) -> [DocsJsonOperation] {
        var operations = [DocsJsonOperation]()
        for (path, pathItem) in (document.paths ?? [:]).sorted(by: { $0.key < $1.key }) {
            let allOps = collectPathItemOperations(from: pathItem)
            for (method, op) in allOps {
                let opName = resolveOperationMethodName(method: method, path: path, operationId: op.operationId)
                let callArgs = buildOperationCallArguments(for: op, pathParameters: pathItem.parameters)
                let code = buildOperationCode(
                    opName: opName,
                    callArgs: callArgs,
                    baseUrl: baseUrl,
                    includeImports: includeImports,
                    includeWrapping: includeWrapping
                )
                operations.append(DocsJsonOperation(method: method, path: path, operationId: op.operationId, code: code))
            }
        }
        return operations
    }

    /// Builds `DocsJsonOperation` entries for all incoming webhooks in an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The `OpenAPIDocument`.
    ///   - baseUrl: Resolved server base URL string.
    ///   - includeImports: Whether to include imports in the snippet.
    ///   - includeWrapping: Whether to include the `@main` wrapper around the snippet.
    /// - Returns: Array of `DocsJsonOperation` entries for webhooks.
    private static func buildWebhookOperations(
        from document: OpenAPIDocument,
        baseUrl: String,
        includeImports: Bool,
        includeWrapping: Bool
    ) -> [DocsJsonOperation] {
        guard let webhooks = document.webhooks, !webhooks.isEmpty else { return [] }
        var webhookOps = [DocsJsonOperation]()
        for (name, item) in webhooks.sorted(by: { $0.key < $1.key }) {
            let allOps = collectPathItemOperations(from: item)
            for (method, op) in allOps {
                let funcName = op.operationId.map { SwiftIdentifierSanitizer.sanitizeCamelCase($0) }
                    ?? SwiftIdentifierSanitizer.sanitizeCamelCase("on-" + name)
                let callArgs = buildOperationCallArguments(for: op, pathParameters: item.parameters)
                let code = buildOperationCode(
                    opName: funcName,
                    callArgs: callArgs,
                    baseUrl: baseUrl,
                    includeImports: includeImports,
                    includeWrapping: includeWrapping
                )
                webhookOps.append(DocsJsonOperation(method: method, path: name, operationId: op.operationId, code: code))
            }
        }
        return webhookOps
    }

    /// Collects all standard and OpenAPI 3.2.0 `additionalOperations` from a `PathItem`.
    ///
    /// - Parameter pathItem: The `PathItem` to inspect.
    /// - Returns: Ordered array of `(lowercaseMethod, Operation)` pairs.
    private static func collectPathItemOperations(from pathItem: PathItem) -> [(String, Operation)] {
        var result = pathItem.operationsByMethod.map { ($0.0.rawValue, $0.1) }
        if let additional = pathItem.additionalOperations {
            for (methodName, op) in additional.sorted(by: { $0.key < $1.key }) {
                result.append((methodName.lowercased(), op))
            }
        }
        return result
    }
}

extension DocsJsonGenerator {
    /// Builds `DocsJsonWorkflow` entries for all workflows in an Arazzo 1.1.0 specification.
    ///
    /// - Parameters:
    ///   - specification: The `ArazzoSpecification`.
    ///   - baseUrl: Resolved server base URL string.
    ///   - includeImports: Whether to include imports in the snippet.
    ///   - includeWrapping: Whether to include the `@main` wrapper around the snippet.
    /// - Returns: Array of `DocsJsonWorkflow` entries.
    private static func buildWorkflowSnippets(
        from specification: ArazzoSpecification,
        baseUrl: String,
        includeImports: Bool,
        includeWrapping: Bool
    ) -> [DocsJsonWorkflow] {
        var results = [DocsJsonWorkflow]()
        let imports: String? = includeImports ? ["import Foundation", "import GeneratedAPI"].joined(separator: "\n") : nil
        let wrapperStart: String? = includeWrapping
            ? [
                "@main",
                "struct Example {",
                "    static func main() async throws {",
                "        let client = APIClient(baseURL: URL(string: \"\(baseUrl)\")!)",
                "        let workflows = WorkflowsClient(client: client)"
            ].joined(separator: "\n")
            : nil
        let wrapperEnd: String? = includeWrapping ? ["    }", "}"].joined(separator: "\n") : nil
        let indent = includeWrapping ? "        " : ""

        for workflow in specification.workflows {
            let methodName = ArazzoSdkEmitter.sanitizeIdentifier(workflow.workflowId)
            let baseName = ArazzoSdkEmitter.pascalCase(workflow.workflowId)
            let inputArgs = buildWorkflowInputArguments(from: workflow.inputs)
            let callExpr = "let outputs = try await workflows.\(methodName)(inputs: \(baseName)Inputs(\(inputArgs)))"
            let snippet = ["\(indent)\(callExpr)", "\(indent)print(outputs)"].joined(separator: "\n")
            let code = DocsJsonCode(
                imports: imports,
                wrapper_start: wrapperStart,
                snippet: snippet,
                wrapper_end: wrapperEnd
            )
            results.append(DocsJsonWorkflow(workflowId: workflow.workflowId, summary: workflow.summary, code: code))
        }
        return results
    }

    /// Builds the `DocsJsonCode` components for an individual OpenAPI operation or webhook.
    ///
    /// - Parameters:
    ///   - opName: The resolved Swift SDK method name.
    ///   - callArgs: Named argument expressions for the method call.
    ///   - baseUrl: Resolved server base URL string.
    ///   - includeImports: Whether to include imports.
    ///   - includeWrapping: Whether to include the `@main` wrapper.
    /// - Returns: The constructed `DocsJsonCode`.
    private static func buildOperationCode(
        opName: String,
        callArgs: [String],
        baseUrl: String,
        includeImports: Bool,
        includeWrapping: Bool
    ) -> DocsJsonCode {
        let imports: String? = includeImports ? ["import Foundation", "import GeneratedAPI"].joined(separator: "\n") : nil
        let wrapperStart: String? = includeWrapping
            ? [
                "@main",
                "struct Example {",
                "    static func main() async throws {",
                "        let client = APIClient(baseURL: URL(string: \"\(baseUrl)\")!)"
            ].joined(separator: "\n")
            : nil
        let wrapperEnd: String? = includeWrapping ? ["    }", "}"].joined(separator: "\n") : nil
        let indent = includeWrapping ? "        " : ""

        let joinedArgs = callArgs.joined(separator: ", ")
        let snippet = ["\(indent)let response = try await client.\(opName)(\(joinedArgs))", "\(indent)print(response)"]
            .joined(separator: "\n")

        return DocsJsonCode(
            imports: imports,
            wrapper_start: wrapperStart,
            snippet: snippet,
            wrapper_end: wrapperEnd
        )
    }

    /// Resolves the Swift SDK method name for an OpenAPI operation.
    ///
    /// - Parameters:
    ///   - method: Lowercase HTTP verb string.
    ///   - path: URL path template.
    ///   - operationId: Optional explicit OpenAPI `operationId`.
    /// - Returns: The Swift method identifier matching `APIClient`.
    private static func resolveOperationMethodName(method: String, path: String, operationId: String?) -> String {
        if let operationId {
            return operationId
        }
        let sanitizedPath = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        return "\(method)\(sanitizedPath)"
    }

    /// Builds named Swift argument expressions for an operation's parameters and request body.
    ///
    /// - Parameters:
    ///   - op: The OpenAPI `Operation` to inspect.
    ///   - pathParameters: Optional shared `Parameter` list defined on the enclosing `PathItem`.
    /// - Returns: Array of `"label: value"` argument strings.
    private static func buildOperationCallArguments(
        for op: Operation,
        pathParameters: [Parameter]?
    ) -> [String] {
        var args = [String]()
        let mergedParams = mergeParameters(pathParameters: pathParameters, operationParameters: op.parameters)
        for param in mergedParams {
            let pIn: ParameterLocation = param.in ?? .query
            if pIn == .body, let schema = param.schema {
                let bodyLabel = param.name ?? "body"
                let literal = synthesizeSchemaLiteral(schema: schema, example: param.example)
                args.append("\(bodyLabel): \(literal)")
                continue
            }
            let rawName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            let safeName = rawName.replacingOccurrences(of: "-", with: "_")
            let swiftType = param.schema.map { mapType(schema: $0) } ?? "String"
            let literal = synthesizeDummyParameterLiteral(param: param, swiftType: swiftType)
            args.append("\(safeName): \(literal)")
        }
        if let bodyArg = buildRequestBodyArgument(from: op.requestBody) {
            args.append(bodyArg)
        }
        return args
    }

    /// Merges path-level and operation-level parameters, allowing operation-level parameters to override path-level ones with the same
    /// name.
    ///
    /// - Parameters:
    ///   - pathParameters: Optional parameters defined on the `PathItem`.
    ///   - operationParameters: Optional parameters defined on the `Operation`.
    /// - Returns: Merged array of `Parameter` definitions.
    private static func mergeParameters(
        pathParameters: [Parameter]?,
        operationParameters: [Parameter]?
    ) -> [Parameter] {
        let opParams = operationParameters ?? []
        guard let pathParams = pathParameters, !pathParams.isEmpty else {
            return opParams
        }
        let opNames = Set(opParams.compactMap { $0.name ?? $0.ref })
        let inherited = pathParams.filter { param in
            guard let key = param.name ?? param.ref else { return true }
            return !opNames.contains(key)
        }
        return inherited + opParams
    }

    /// Builds a named Swift argument string for an operation's `RequestBody`, if present.
    ///
    /// - Parameter requestBody: Optional OpenAPI `RequestBody`.
    /// - Returns: A `"label: value"` argument string, or `nil` if no supported request body content exists.
    private static func buildRequestBodyArgument(from requestBody: RequestBody?) -> String? {
        guard let reqBody = requestBody else { return nil }
        if let jsonMedia = reqBody.content?["application/json"], let schema = jsonMedia.schema {
            return "body: \(synthesizeSchemaLiteral(schema: schema, example: jsonMedia.example))"
        }
        if let formMedia = reqBody.content?["application/x-www-form-urlencoded"], let schema = formMedia.schema {
            return "formData: \(synthesizeSchemaLiteral(schema: schema, example: formMedia.example))"
        }
        if let multiMedia = reqBody.content?["multipart/form-data"], let schema = multiMedia.schema {
            return "multipartData: \(synthesizeSchemaLiteral(schema: schema, example: multiMedia.example))"
        }
        if let octetMedia = reqBody.content?["application/octet-stream"], let schema = octetMedia.schema {
            return "fileData: \(synthesizeSchemaLiteral(schema: schema, example: octetMedia.example))"
        }
        return nil
    }

    /// Synthesizes a Swift literal or initializer expression for a given OpenAPI `Schema`.
    ///
    /// - Parameters:
    ///   - schema: The OpenAPI `Schema`.
    ///   - example: Optional media-type or parameter example override.
    /// - Returns: A valid Swift expression string representing a sample value.
    private static func synthesizeSchemaLiteral(schema: Schema, example: AnyCodable? = nil) -> String {
        let swiftType = mapType(schema: schema)
        let param = Parameter(schema: schema, example: example)
        if schema.ref != nil {
            return "\(swiftType)()"
        }
        if swiftType == "AnyCodable" || swiftType == "[String: AnyCodable]" {
            return "[:]"
        }
        return synthesizeDummyParameterLiteral(param: param, swiftType: swiftType)
    }

    /// Builds named Swift initializer arguments for an Arazzo workflow's input `Schema`.
    ///
    /// - Parameter inputs: Optional input `Schema` for the workflow.
    /// - Returns: Comma-separated `"propName: value"` string for `<Workflow>Inputs(...)`.
    private static func buildWorkflowInputArguments(from inputs: Schema?) -> String {
        guard let schema = inputs, let props = schema.properties, !props.isEmpty else {
            return ""
        }
        var args = [String]()
        for (key, propSchema) in props.sorted(by: { $0.key < $1.key }) {
            let propId = ArazzoSdkEmitter.sanitizeIdentifier(key)
            let literal = synthesizeSchemaLiteral(schema: propSchema)
            args.append("\(propId): \(literal)")
        }
        return args.joined(separator: ", ")
    }

    /// Encodes an array of `DocsJsonOutput` values into a pretty-printed JSON string.
    ///
    /// - Parameter root: The `[DocsJsonOutput]` array to encode.
    /// - Returns: UTF-8 JSON string with pretty printing and unescaped slashes.
    private static func encodeDocsJsonOutputs(_ root: [DocsJsonOutput]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        var encodedData = Data()
        if let data = try? encoder.encode(root) {
            encodedData = data
        }
        return String(decoding: encodedData, as: UTF8.self)
    }
}
