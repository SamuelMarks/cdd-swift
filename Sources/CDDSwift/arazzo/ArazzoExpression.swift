/// Runtime expression, JSON Pointer, and criterion evaluator for Arazzo 1.1.0 workflows.
import Foundation

/// Runtime execution state container against which Arazzo expressions and criteria are evaluated.
public struct ArazzoExecutionContext: Sendable, Equatable {
    /// Active target URL for the step or operation.
    public var url: String?
    /// HTTP method (verb) of the operation.
    public var method: String?
    /// HTTP response status code.
    public var statusCode: Int?
    /// Outgoing HTTP request headers.
    public var requestHeaders: [String: String]
    /// Outgoing URL query parameters.
    public var requestQuery: [String: String]
    /// Outgoing URL path parameters.
    public var requestPath: [String: String]
    /// Outgoing request payload body.
    public var requestBody: AnyCodable?
    /// Incoming HTTP response headers.
    public var responseHeaders: [String: String]
    /// Incoming response payload body.
    public var responseBody: AnyCodable?
    /// Workflow invocation input argument bindings.
    public var inputs: [String: AnyCodable]
    /// Workflow accumulated output variables.
    public var outputs: [String: AnyCodable]
    /// Output variables captured by previously executed steps (`[stepId: [outputKey: value]]`).
    public var steps: [String: [String: AnyCodable]]
    /// Base URLs mapped from source descriptions (`[sourceName: sourceUrl]`).
    public var sourceDescriptions: [String: String]

    /// Initializes a new execution context with default empty state.
    ///
    /// - Parameters:
    ///   - url: Target request URL.
    ///   - method: HTTP method string.
    ///   - statusCode: HTTP status code integer.
    ///   - requestHeaders: Request headers map.
    ///   - requestQuery: Request query parameters map.
    ///   - requestPath: Request path parameters map.
    ///   - requestBody: Request body payload.
    ///   - responseHeaders: Response headers map.
    ///   - responseBody: Response body payload.
    ///   - inputs: Workflow input arguments.
    ///   - outputs: Workflow outputs.
    ///   - steps: Step outputs map.
    ///   - sourceDescriptions: Source description URLs map.
    public init(
        url: String? = nil,
        method: String? = nil,
        statusCode: Int? = nil,
        requestHeaders: [String: String] = [:],
        requestQuery: [String: String] = [:],
        requestPath: [String: String] = [:],
        requestBody: AnyCodable? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: AnyCodable? = nil,
        inputs: [String: AnyCodable] = [:],
        outputs: [String: AnyCodable] = [:],
        steps: [String: [String: AnyCodable]] = [:],
        sourceDescriptions: [String: String] = [:]
    ) {
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.requestHeaders = requestHeaders
        self.requestQuery = requestQuery
        self.requestPath = requestPath
        self.requestBody = requestBody
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.inputs = inputs
        self.outputs = outputs
        self.steps = steps
        self.sourceDescriptions = sourceDescriptions
    }
}

/// Evaluator engine for Arazzo 1.1.0 runtime expressions and criteria conditions.
public enum ArazzoExpressionEvaluator {
    /// Evaluates an RFC 6901 JSON Pointer against an `AnyCodable` data structure.
    ///
    /// - Parameters:
    ///   - pointer: The JSON Pointer string (e.g. `"/items/0/id"` or `""`).
    ///   - root: The root `AnyCodable` structure to query.
    /// - Returns: The extracted `AnyCodable` value, or `nil` if not found.
    public static func evaluateJsonPointer(_ pointer: String, on root: AnyCodable) -> AnyCodable? {
        let cleanPointer = pointer.hasPrefix("#") ? String(pointer.dropFirst()) : pointer
        if cleanPointer.isEmpty || cleanPointer == "/" {
            return root
        }

        let tokens = cleanPointer.components(separatedBy: "/").dropFirst().map { token in
            token.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
        }

        var current: JSONValue = root.jsonValue
        for token in tokens {
            switch current {
            case let .object(dict):
                guard let next = dict[token] else { return nil }
                current = next
            case let .array(arr):
                guard let idx = Int(token), idx >= 0, idx < arr.count else { return nil }
                current = arr[idx]
            default:
                return nil
            }
        }
        return AnyCodable(current)
    }

    /// Evaluates a single Arazzo runtime expression string against the provided execution context.
    ///
    /// - Parameters:
    ///   - expression: The Arazzo expression string (e.g. `"$statusCode"`, `"$response.body#/id"`).
    ///   - context: The execution context containing active state.
    /// - Returns: The evaluated `AnyCodable` value.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if evaluation fails.
    public static func evaluate(expression: String, in context: ArazzoExecutionContext) throws -> AnyCodable {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        if let scalarResult = try evaluateScalarExpression(trimmed, original: expression, in: context) {
            return scalarResult
        }
        if trimmed.hasPrefix("$request.") {
            return try evaluateRequestExpression(trimmed, original: expression, in: context)
        }
        if trimmed.hasPrefix("$response.") {
            return try evaluateResponseExpression(trimmed, original: expression, in: context)
        }
        if let stateResult = try evaluateWorkflowStateExpression(trimmed, original: expression, in: context) {
            return stateResult
        }

        return AnyCodable(expression)
    }

    /// Evaluates top-level scalar expressions (`$url`, `$method`, `$statusCode`).
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string.
    ///   - original: Original untrimmed expression string for error reporting.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The resolved `AnyCodable`, or `nil` if `trimmed` is not a top-level scalar expression.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if the target context field is `nil`.
    private static func evaluateScalarExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable? {
        switch trimmed {
        case "$url":
            guard let val = context.url else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "url is nil")
            }
            return AnyCodable(val)
        case "$method":
            guard let val = context.method else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "method is nil")
            }
            return AnyCodable(val)
        case "$statusCode":
            guard let val = context.statusCode else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "statusCode is nil")
            }
            return AnyCodable(val)
        default:
            return nil
        }
    }

    /// Evaluates `$request.header.*`, `$request.query.*`, `$request.path.*`, and `$request.body*` expressions.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string starting with `"$request."`.
    ///   - original: Original expression string.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The resolved `AnyCodable` value.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if the requested field or JSON pointer is missing.
    private static func evaluateRequestExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable {
        if trimmed.hasPrefix("$request.header.") {
            let key = String(trimmed.dropFirst("$request.header.".count))
            guard let val = context.requestHeaders[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing request header \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.query.") {
            let key = String(trimmed.dropFirst("$request.query.".count))
            guard let val = context.requestQuery[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing request query \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.path.") {
            let key = String(trimmed.dropFirst("$request.path.".count))
            guard let val = context.requestPath[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing request path \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.body") {
            return try evaluateBodyPointer(
                trimmed: trimmed,
                original: original,
                body: context.requestBody,
                nilError: "requestBody is nil",
                pointerError: "pointer not found in request body"
            )
        }
        return AnyCodable(original)
    }

    /// Evaluates `$response.header.*` and `$response.body*` expressions.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string starting with `"$response."`.
    ///   - original: Original expression string.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The resolved `AnyCodable` value.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if the response field or JSON pointer is missing.
    private static func evaluateResponseExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable {
        if trimmed.hasPrefix("$response.header.") {
            let key = String(trimmed.dropFirst("$response.header.".count))
            guard let val = context.responseHeaders[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing response header \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$response.body") {
            return try evaluateBodyPointer(
                trimmed: trimmed,
                original: original,
                body: context.responseBody,
                nilError: "responseBody is nil",
                pointerError: "pointer not found in response body"
            )
        }
        return AnyCodable(original)
    }

    /// Evaluates a body expression with an optional `#/...` JSON Pointer suffix.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string (`$request.body...` or `$response.body...`).
    ///   - original: Original expression string.
    ///   - body: Optional `AnyCodable` body payload.
    ///   - nilError: Error context message if `body` is nil.
    ///   - pointerError: Error context message if the JSON pointer does not resolve.
    /// - Returns: The resolved `AnyCodable` value.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` on failure.
    private static func evaluateBodyPointer(
        trimmed: String,
        original: String,
        body: AnyCodable?,
        nilError: String,
        pointerError: String
    ) throws -> AnyCodable {
        guard let body = body else {
            throw CDDError.arazzoExpressionEvaluationError(expression: original, context: nilError)
        }
        if let hashIdx = trimmed.firstIndex(of: "#") {
            let pointer = String(trimmed[hashIdx...])
            guard let res = evaluateJsonPointer(pointer, on: body) else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: pointerError)
            }
            return res
        }
        return body
    }

    /// Evaluates `$inputs.*`, `$outputs.*`, `$steps.*`, and `$sourceDescriptions.*` expressions.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string.
    ///   - original: Original expression string.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The resolved `AnyCodable` value, or `nil` if `trimmed` does not match a state prefix.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if lookup fails.
    private static func evaluateWorkflowStateExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable? {
        if trimmed.hasPrefix("$inputs.") {
            let key = String(trimmed.dropFirst("$inputs.".count))
            guard let val = context.inputs[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing input \(key)")
            }
            return val
        }
        if trimmed.hasPrefix("$outputs.") {
            let key = String(trimmed.dropFirst("$outputs.".count))
            guard let val = context.outputs[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "missing output \(key)")
            }
            return val
        }
        if trimmed.hasPrefix("$steps.") {
            return try evaluateStepsExpression(trimmed, original: original, in: context)
        }
        if trimmed.hasPrefix("$sourceDescriptions.") {
            return try evaluateSourceDescriptionExpression(trimmed, original: original, in: context)
        }
        return nil
    }

    /// Evaluates a `$steps.<stepId>.outputs.<outputKey>` expression.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string starting with `"$steps."`.
    ///   - original: Original expression string.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The step output `AnyCodable` value.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if malformed or missing.
    private static func evaluateStepsExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable {
        let rest = String(trimmed.dropFirst("$steps.".count))
        let parts = rest.components(separatedBy: ".")
        guard parts.count >= 3, parts[1] == "outputs" else {
            throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "malformed $steps expression")
        }
        let stepId = parts[0]
        let outputKey = parts[2]
        guard let stepDict = context.steps[stepId], let val = stepDict[outputKey] else {
            throw CDDError.arazzoExpressionEvaluationError(
                expression: original,
                context: "missing step output '\(outputKey)' from '\(stepId)'"
            )
        }
        return val
    }

    /// Evaluates a `$sourceDescriptions.<name>.url` expression.
    ///
    /// - Parameters:
    ///   - trimmed: Trimmed expression string starting with `"$sourceDescriptions."`.
    ///   - original: Original expression string.
    ///   - context: The active `ArazzoExecutionContext`.
    /// - Returns: The source description URL wrapped in `AnyCodable`.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if malformed or missing.
    private static func evaluateSourceDescriptionExpression(
        _ trimmed: String,
        original: String,
        in context: ArazzoExecutionContext
    ) throws -> AnyCodable {
        let rest = String(trimmed.dropFirst("$sourceDescriptions.".count))
        let parts = rest.components(separatedBy: ".")
        guard parts.count == 2, parts[1] == "url" else {
            throw CDDError.arazzoExpressionEvaluationError(expression: original, context: "malformed $sourceDescriptions expression")
        }
        let sourceName = parts[0]
        guard let url = context.sourceDescriptions[sourceName] else {
            throw CDDError.arazzoExpressionEvaluationError(
                expression: original,
                context: "sourceDescription '\(sourceName)' not found"
            )
        }
        return AnyCodable(url)
    }
}
