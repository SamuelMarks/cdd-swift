/// Swift 6 workflow orchestrator SDK emitter for Arazzo 1.1.0 specifications.

/// Code emitter generating strongly typed Swift 6 workflow orchestrator SDK clients from Arazzo 1.1.0 specifications.
public enum ArazzoSdkEmitter {
    /// Sanitizes an arbitrary string into a valid Swift camelCase property or method identifier.
    ///
    /// - Parameter name: Input raw identifier.
    /// - Returns: Valid Swift identifier.
    public static func sanitizeIdentifier(_ name: String) -> String {
        SwiftIdentifierSanitizer.sanitizeCamelCase(name, fallback: "identifier")
    }

    /// Converts an identifier string into a PascalCase Swift struct or class type name.
    ///
    /// - Parameter name: Input raw identifier.
    /// - Returns: Swift PascalCase type name.
    public static func pascalCase(_ name: String) -> String {
        SwiftIdentifierSanitizer.sanitizePascalCase(name, fallback: "WorkflowType")
    }

    /// Emits a complete Swift source file containing workflow orchestrator classes, DTOs, and runtime support.
    ///
    /// - Parameters:
    ///   - specification: The parsed Arazzo 1.1.0 specification.
    ///   - clientClassName: Name of the underlying HTTP client class. Defaults to `"APIClient"`.
    ///   - sourceDocuments: Optional dictionary of resolved `OpenAPIDocument` models keyed by `sourceDescription.name`.
    /// - Returns: Generated Swift source code string.
    public static func emitWorkflowClient(
        from specification: ArazzoSpecification,
        clientClassName: String = "APIClient",
        sourceDocuments: [String: OpenAPIDocument] = [:]
    ) -> String {
        var output = "/// Generated Arazzo 1.1.0 workflow orchestrator client and DTOs for \(specification.info.title).\n"
        output += "import Foundation\n"
        output += "#if canImport(FoundationNetworking)\n"
        output += "import FoundationNetworking\n"
        output += "#endif\n\n"
        output += "// MARK: - Workflow DTOs and Orchestrator\n\n"

        for workflow in specification.workflows {
            output += emitWorkflowDTOs(workflow: workflow)
            output += "\n"
        }

        output += emitWorkflowClientClass(
            specification: specification,
            clientClassName: clientClassName,
            sourceDocuments: sourceDocuments
        )
        return output
    }

    /// Emits a Model Context Protocol (MCP) workflow adapter exposing Arazzo workflows as MCP tools.
    ///
    /// - Parameter specification: The parsed Arazzo 1.1.0 specification.
    /// - Returns: Generated Swift source code for `WorkflowsMCPAdapter`.
    public static func emitWorkflowMCP(from specification: ArazzoSpecification) -> String {
        let q = String(UnicodeScalar(34))
        let toolIds = specification.workflows.map { q + $0.workflowId + q }.joined(separator: ", ")
        return """
        /// Model Context Protocol (MCP) workflow adapter for \(specification.info.title).
        import Foundation

        /// Model Context Protocol (MCP) adapter exposing Arazzo 1.1.0 workflows as invokable tools.
        public struct WorkflowsMCPAdapter: Sendable {
            /// Identifiers of the exposed workflow tools.
            public let workflowToolNames: [String]

            /// Initializes a new `WorkflowsMCPAdapter`.
            ///
            /// - Parameter workflowToolNames: Exposed workflow tool identifiers.
            public init(workflowToolNames: [String] = [\(toolIds)]) {
                self.workflowToolNames = workflowToolNames
            }
        }

        """
    }

    /// Emits input and output DTO struct models for a specific workflow.
    ///
    /// - Parameter workflow: The workflow to emit models for.
    /// - Returns: Generated Swift structs.
    private static func emitWorkflowDTOs(workflow: ArazzoWorkflow) -> String {
        let baseName = pascalCase(workflow.workflowId)
        var code = ""
        code += "/// Input arguments container for workflow `" + workflow.workflowId + "`.\n"
        code += "public struct " + baseName + "Inputs: Codable, Sendable, Equatable {\n"

        if let schema = workflow.inputs, let props = schema.properties, !props.isEmpty {
            for (key, propSchema) in props.sorted(by: { $0.key < $1.key }) {
                let propId = sanitizeIdentifier(key)
                let propType = mapSchemaType(propSchema)
                code += "    /// The `" + key + "` parameter value.\n"
                code += "    public let " + propId + ": " + propType + "?\n"
            }

            code += "\n    /// Initializes workflow input arguments.\n"
            code += "    ///\n"
            code += "    /// - Parameters:\n"
            for key in props.keys.sorted() {
                let propId = sanitizeIdentifier(key)
                code += "    ///   - " + propId + ": The `" + key + "` input value.\n"
            }
            code += "    public init(\n"
            let initArgs = props.sorted(by: { $0.key < $1.key }).map { key, propSchema in
                let propId = sanitizeIdentifier(key)
                let propType = mapSchemaType(propSchema)
                return "        " + propId + ": " + propType + "? = nil"
            }.joined(separator: ",\n")
            code += initArgs + "\n    ) {\n"
            for key in props.keys.sorted() {
                let propId = sanitizeIdentifier(key)
                code += "        self." + propId + " = " + propId + "\n"
            }
            code += "    }\n"
        } else {
            code += "    /// Dynamic payload parameters.\n"
            code += "    public let parameters: [String: AnyCodable]\n\n"
            code += "    /// Initializes empty or dictionary-backed parameters.\n"
            code += "    ///\n"
            code += "    /// - Parameter parameters: Dynamic input parameters map.\n"
            code += "    public init(parameters: [String: AnyCodable] = [:]) {\n"
            code += "        self.parameters = parameters\n"
            code += "    }\n"
        }
        code += "}\n\n"

        code += "/// Output execution result container for workflow `" + workflow.workflowId + "`.\n"
        code += "public struct " + baseName + "Outputs: Codable, Sendable, Equatable {\n"
        code += "    /// The extracted output variables mapped from step responses.\n"
        code += "    public let values: [String: AnyCodable]\n\n"
        code += "    /// Initializes workflow output results.\n"
        code += "    /// - Parameter values: Output variables map.\n"
        code += "    public init(values: [String: AnyCodable]) {\n"
        code += "        self.values = values\n"
        code += "    }\n"
        code += "}\n"
        return code
    }

    /// Emits the main `WorkflowsClient` orchestrator class containing step chaining methods.
    ///
    /// - Parameters:
    ///   - specification: The Arazzo specification.
    ///   - clientClassName: Underlying client class name.
    ///   - sourceDocuments: Resolved `OpenAPIDocument` models keyed by `sourceDescription.name`.
    /// - Returns: Swift class definition.
    private static func emitWorkflowClientClass(
        specification: ArazzoSpecification,
        clientClassName: String,
        sourceDocuments: [String: OpenAPIDocument]
    ) -> String {
        let q = String(UnicodeScalar(34))
        let defaultSourcesEntries = specification.sourceDescriptions
            .map { q + $0.name + q + ": " + q + $0.url + q }
            .joined(separator: ", ")
        let defaultSourcesLiteral = defaultSourcesEntries.isEmpty ? "[:]" : "[" + defaultSourcesEntries + "]"

        var code = ""
        code += "/// Strongly typed orchestrator executing Arazzo 1.1.0 workflows.\n"
        code += "public class WorkflowsClient: @unchecked Sendable {\n"
        code += "    /// Underlying API client executing HTTP operations.\n"
        code += "    public let client: " + clientClassName + "\n"
        code += "    /// Map of source description names to their base URLs.\n"
        code += "    public let sourceDescriptions: [String: String]\n"
        code += "    /// Asynchronous operation dispatcher returning a populated `ArazzoExecutionContext` for each step.\n"
        code += "    public let operationRunner: @Sendable (String, [String: [String: AnyCodable]])"
            + " async throws -> ArazzoExecutionContext\n\n"
        code += "    /// Initializes the workflow orchestrator client.\n"
        code += "    ///\n"
        code += "    /// - Parameters:\n"
        code += "    ///   - client: Underlying HTTP client instance.\n"
        code += "    ///   - sourceDescriptions: Source description endpoints mapping.\n"
        code += "    ///   - operationRunner: Custom step operation dispatcher.\n"
        code += "    public init(\n"
        code += "        client: " + clientClassName + " = " + clientClassName + "(),\n"
        code += "        sourceDescriptions: [String: String] = " + defaultSourcesLiteral + ",\n"
        code += "        operationRunner: @escaping @Sendable (String, [String: [String: AnyCodable]])"
            + " async throws -> ArazzoExecutionContext = { _, steps in ArazzoExecutionContext(statusCode: 200, steps: steps) }\n"
        code += "    ) {\n"
        code += "        self.client = client\n"
        code += "        self.sourceDescriptions = sourceDescriptions\n"
        code += "        self.operationRunner = operationRunner\n"
        code += "    }\n\n"

        let resolvedOperations = collectResolvedOperationIds(from: sourceDocuments)
        for workflow in specification.workflows {
            code += emitWorkflowMethod(workflow: workflow, resolvedOperations: resolvedOperations)
            code += "\n"
        }

        code += "}\n"
        return code
    }

    /// Collects all known `operationId` strings from a map of resolved `OpenAPIDocument` specifications.
    ///
    /// - Parameter sourceDocuments: Dictionary mapping source names to `OpenAPIDocument` models.
    /// - Returns: Set of discovered `operationId` identifiers (including `<sourceName>.<operationId>` qualified forms).
    private static func collectResolvedOperationIds(from sourceDocuments: [String: OpenAPIDocument]) -> Set<String> {
        var ids: Set<String> = []
        for (sourceName, doc) in sourceDocuments {
            for (_, item) in doc.paths ?? [:] {
                for (_, op) in item.operationsByMethod {
                    if let opId = op.operationId {
                        ids.insert(opId)
                        ids.insert(sourceName + "." + opId)
                    }
                }
            }
        }
        return ids
    }

    /// Emits an individual workflow execution async method.
    ///
    /// - Parameters:
    ///   - workflow: Workflow to generate.
    ///   - resolvedOperations: Known `operationId` values from linked OpenAPI source documents.
    /// - Returns: Swift async method string.
    private static func emitWorkflowMethod(workflow: ArazzoWorkflow, resolvedOperations: Set<String>) -> String {
        let methodName = sanitizeIdentifier(workflow.workflowId)
        let baseName = pascalCase(workflow.workflowId)

        var code = ""
        code += "    /// Executes workflow `" + workflow.workflowId + "`.\n"
        code += "    ///\n"
        code += "    /// - Parameter inputs: Workflow input parameters.\n"
        code += "    /// - Returns: Workflow execution outputs.\n"
        code += "    /// - Throws: `CDDError` if any step execution, assertion, or retry fails.\n"
        code += "    public func " + methodName + "(inputs: " + baseName + "Inputs) async throws -> " + baseName + "Outputs {\n"
        code += "        var stepOutputs: [String: [String: AnyCodable]] = [:]\n\n"

        for step in workflow.steps {
            code += emitStepExecution(step: step, resolvedOperations: resolvedOperations)
        }

        code += "        var finalOutputs: [String: AnyCodable] = [:]\n"

        if let outputs = workflow.outputs {
            for (outKey, outExpr) in outputs.sorted(by: { $0.key < $1.key }) {
                let exprStr = outExpr.stringValue ?? ""
                code += "        finalOutputs[\"" + outKey + "\"] = try ArazzoExpressionEvaluator.evaluate(expression: \""
                    + exprStr + "\", in: ArazzoExecutionContext(steps: stepOutputs))\n"
            }
        }

        code += "        return " + baseName + "Outputs(values: finalOutputs)\n"
        code += "    }\n"
        return code
    }

    /// Emits execution code for an individual step inside a workflow method.
    ///
    /// - Parameters:
    ///   - step: The step definition.
    ///   - resolvedOperations: Known `operationId` values from linked OpenAPI source documents.
    /// - Returns: Generated step invocation code.
    private static func emitStepExecution(step: ArazzoStep, resolvedOperations: Set<String>) -> String {
        let opId = step.operationId ?? sanitizeIdentifier(step.stepId)
        let maxRetries = step.onFailure?.compactMap(\.retryLimit).max() ?? 0
        let retryDelay = step.onFailure?.compactMap(\.retryAfter).max() ?? 1.0

        var code = ""
        code += "        // Step: " + step.stepId + "\n"
        code += "        do {\n"
        code += "            var attempt = 0\n"
        code += "            while attempt <= " + String(maxRetries) + " {\n"
        code += "                do {\n"
        code += "                    // Operation dispatch: " + opId + "\n"
        if resolvedOperations.contains(opId) {
            let parts = opId.components(separatedBy: ".")
            let unqualifiedOp = parts[parts.count - 1]
            let clientFunc = sanitizeIdentifier(unqualifiedOp)
            code += "                    // Resolved OpenAPI client operation: client." + clientFunc + "\n"
        }
        code += "                    let context = try await self.operationRunner(\"" + opId + "\", stepOutputs)\n"

        if let criteria = step.successCriteria, !criteria.isEmpty {
            code += "                    // Evaluate success criteria\n"
            for crit in criteria {
                let condEscaped = crit.condition.replacingOccurrences(of: "\"", with: "\\\"")
                code += "                    let crit_" + sanitizeIdentifier(crit.context) + " = ArazzoCriterion(context: \"" + crit
                    .context + "\", condition: \"" + condEscaped + "\")\n"
                code += "                    guard try ArazzoExpressionEvaluator.evaluateCriterion(crit_" +
                    sanitizeIdentifier(crit.context) + ", in: context) else {\n"
                code += "                        throw CDDError.arazzoStepExecutionFailed(stepId: \""
                    + step.stepId + "\", reason: \"Criterion failed\")\n"
                code += "                    }\n"
            }
        }

        if let outputs = step.outputs, !outputs.isEmpty {
            code += "                    var currentOutputs: [String: AnyCodable] = [:]\n"
            for (k, v) in outputs.sorted(by: { $0.key < $1.key }) {
                let expr = v.stringValue ?? ""
                code += "                    currentOutputs[\"" + k + "\"] = try ArazzoExpressionEvaluator.evaluate(expression: \"" + expr +
                    "\", in: context)\n"
            }
            code += "                    stepOutputs[\"" + step.stepId + "\"] = currentOutputs\n"
        } else {
            code += "                    stepOutputs[\"" + step.stepId + "\"] = [:]\n"
        }

        code += "                    break\n"
        code += "                } catch {\n"
        code += "                    attempt += 1\n"
        code += "                    if attempt > " + String(maxRetries) + " {\n"
        code += "                        throw error\n"
        code += "                    }\n"
        code += "                    try? await Task.sleep(nanoseconds: UInt64(" + String(retryDelay) + " * 1_000_000_000))\n"
        code += "                }\n"
        code += "            }\n"
        code += "        }\n"
        return code
    }

    /// Maps a JSON Schema type to a Swift primitive type string.
    ///
    /// - Parameter schema: The schema definition.
    /// - Returns: Swift type name.
    private static func mapSchemaType(_ schema: Schema) -> String {
        switch schema.type {
        case "string":
            "String"
        case "integer":
            "Int"
        case "number":
            "Double"
        case "boolean":
            "Bool"
        case "array":
            "[AnyCodable]"
        default:
            "AnyCodable"
        }
    }
}
