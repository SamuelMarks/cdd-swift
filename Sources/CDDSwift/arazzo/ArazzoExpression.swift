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

        var current: Any = root.value
        for token in tokens {
            if let dict = current as? [String: Any] {
                guard let next = dict[token] else { return nil }
                current = (next as? AnyCodable)?.value ?? next
            } else if let arr = current as? [Any] {
                guard let idx = Int(token), idx >= 0, idx < arr.count else { return nil }
                let next = arr[idx]
                current = (next as? AnyCodable)?.value ?? next
            } else {
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

        if trimmed == "$url" {
            guard let val = context.url else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "url is nil")
            }
            return AnyCodable(val)
        }
        if trimmed == "$method" {
            guard let val = context.method else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "method is nil")
            }
            return AnyCodable(val)
        }
        if trimmed == "$statusCode" {
            guard let val = context.statusCode else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "statusCode is nil")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.header.") {
            let key = String(trimmed.dropFirst("$request.header.".count))
            guard let val = context.requestHeaders[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing request header \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.query.") {
            let key = String(trimmed.dropFirst("$request.query.".count))
            guard let val = context.requestQuery[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing request query \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.path.") {
            let key = String(trimmed.dropFirst("$request.path.".count))
            guard let val = context.requestPath[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing request path \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$request.body") {
            guard let body = context.requestBody else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "requestBody is nil")
            }
            if trimmed == "$request.body" {
                return body
            }
            if let hashIdx = trimmed.firstIndex(of: "#") {
                let pointer = String(trimmed[hashIdx...])
                guard let res = evaluateJsonPointer(pointer, on: body) else {
                    throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "pointer not found in request body")
                }
                return res
            }
            return body
        }
        if trimmed.hasPrefix("$response.header.") {
            let key = String(trimmed.dropFirst("$response.header.".count))
            guard let val = context.responseHeaders[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing response header \(key)")
            }
            return AnyCodable(val)
        }
        if trimmed.hasPrefix("$response.body") {
            guard let body = context.responseBody else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "responseBody is nil")
            }
            if trimmed == "$response.body" {
                return body
            }
            if let hashIdx = trimmed.firstIndex(of: "#") {
                let pointer = String(trimmed[hashIdx...])
                guard let res = evaluateJsonPointer(pointer, on: body) else {
                    throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "pointer not found in response body")
                }
                return res
            }
            return body
        }
        if trimmed.hasPrefix("$inputs.") {
            let key = String(trimmed.dropFirst("$inputs.".count))
            guard let val = context.inputs[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing input \(key)")
            }
            return val
        }
        if trimmed.hasPrefix("$outputs.") {
            let key = String(trimmed.dropFirst("$outputs.".count))
            guard let val = context.outputs[key] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing output \(key)")
            }
            return val
        }
        if trimmed.hasPrefix("$steps.") {
            let rest = String(trimmed.dropFirst("$steps.".count))
            let parts = rest.components(separatedBy: ".")
            guard parts.count >= 3, parts[1] == "outputs" else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "malformed $steps expression")
            }
            let stepId = parts[0]
            let outputKey = parts[2]
            guard let stepDict = context.steps[stepId], let val = stepDict[outputKey] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "missing step output '\(outputKey)' from '\(stepId)'")
            }
            return val
        }
        if trimmed.hasPrefix("$sourceDescriptions.") {
            let rest = String(trimmed.dropFirst("$sourceDescriptions.".count))
            let parts = rest.components(separatedBy: ".")
            guard parts.count == 2, parts[1] == "url" else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "malformed $sourceDescriptions expression")
            }
            let sourceName = parts[0]
            guard let url = context.sourceDescriptions[sourceName] else {
                throw CDDError.arazzoExpressionEvaluationError(expression: expression, context: "sourceDescription '\(sourceName)' not found")
            }
            return AnyCodable(url)
        }

        // Return literal value if not an Arazzo expression
        return AnyCodable(expression)
    }

    /// Evaluates an Arazzo assertion criterion condition against the execution context.
    ///
    /// - Parameters:
    ///   - criterion: The assertion criterion to evaluate.
    ///   - context: The execution context containing runtime state.
    /// - Returns: `true` if the criterion condition succeeds, `false` otherwise.
    /// - Throws: `CDDError.arazzoExpressionEvaluationError` if expression evaluation fails.
    public static func evaluateCriterion(_ criterion: ArazzoCriterion, in context: ArazzoExecutionContext) throws -> Bool {
        let value = try evaluate(expression: criterion.context, in: context)
        let condition = criterion.condition.trimmingCharacters(in: .whitespacesAndNewlines)

        switch criterion.type {
        case .regex:
            let valStr = String(describing: value.value)
            let pattern = condition.hasPrefix("/") && condition.hasSuffix("/")
                ? String(condition.dropFirst().dropLast())
                : condition
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(location: 0, length: valStr.utf16.count)
            return regex.firstMatch(in: valStr, options: [], range: range) != nil

        case .simple, .none, .jsonpath, .xpath:
            if condition.hasPrefix("==") {
                let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                return compareEquality(value: value, expected: expected)
            }
            if condition.hasPrefix("!=") {
                let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                return !compareEquality(value: value, expected: expected)
            }
            if condition.hasPrefix("<=") {
                let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let numVal = toDouble(value.value), let numExp = Double(expected) else { return false }
                return numVal <= numExp
            }
            if condition.hasPrefix(">=") {
                let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let numVal = toDouble(value.value), let numExp = Double(expected) else { return false }
                return numVal >= numExp
            }
            if condition.hasPrefix("<") {
                let expected = condition.dropFirst(1).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let numVal = toDouble(value.value), let numExp = Double(expected) else { return false }
                return numVal < numExp
            }
            if condition.hasPrefix(">") {
                let expected = condition.dropFirst(1).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let numVal = toDouble(value.value), let numExp = Double(expected) else { return false }
                return numVal > numExp
            }
            return compareEquality(value: value, expected: condition)
        }
    }

    /// Compares an `AnyCodable` value against an expected string representation.
    ///
    /// - Parameters:
    ///   - value: The evaluated runtime value.
    ///   - expected: Expected string value.
    /// - Returns: True if matching.
    private static func compareEquality(value: AnyCodable, expected: String) -> Bool {
        let cleanExpected = expected.hasPrefix("\"") && expected.hasSuffix("\"")
            ? String(expected.dropFirst().dropLast())
            : expected

        if let intVal = value.value as? Int, let expInt = Int(cleanExpected) {
            return intVal == expInt
        }
        if let dblVal = value.value as? Double, let expDbl = Double(cleanExpected) {
            return dblVal == expDbl
        }
        if let boolVal = value.value as? Bool, let expBool = Bool(cleanExpected) {
            return boolVal == expBool
        }
        return String(describing: value.value) == cleanExpected
    }

    /// Converts a numeric dynamic value to a Double if possible.
    ///
    /// - Parameter val: Any value.
    /// - Returns: Double representation or nil.
    private static func toDouble(_ val: Any) -> Double? {
        if let d = val as? Double {
            return d
        }
        if let i = val as? Int {
            return Double(i)
        }
        if let s = val as? String {
            return Double(s)
        }
        return nil
    }

    /// Recursively updates a dictionary or array along token path segments.
    ///
    /// - Parameters:
    ///   - tokens: Path segments to traverse.
    ///   - current: Current data container node.
    ///   - replacementValue: The value to write at the terminal token.
    /// - Returns: The mutated data container.
    private static func updateNode(tokens: [String], current: Any, replacementValue: Any) -> Any {
        let first = tokens[0]
        let remaining = Array(tokens.dropFirst())

        if var dict = current as? [String: Any] {
            if remaining.isEmpty {
                dict[first] = replacementValue
            } else {
                let child = dict[first] ?? [String: Any]()
                dict[first] = updateNode(tokens: remaining, current: child, replacementValue: replacementValue)
            }
            return dict
        }
        if var arr = current as? [Any], let idx = Int(first), idx >= 0, idx < arr.count {
            if remaining.isEmpty {
                arr[idx] = replacementValue
            } else {
                arr[idx] = updateNode(tokens: remaining, current: arr[idx], replacementValue: replacementValue)
            }
            return arr
        }
        return current
    }

    /// Injects an in-place payload replacement rule into an existing `AnyCodable` root payload.
    ///
    /// - Parameters:
    ///   - replacement: The payload replacement rule.
    ///   - root: The original payload root.
    /// - Returns: The modified payload `AnyCodable`.
    public static func applyReplacement(_ replacement: ArazzoPayloadReplacement, to root: AnyCodable) -> AnyCodable {
        let cleanTarget = replacement.target.hasPrefix("#") ? String(replacement.target.dropFirst()) : replacement.target
        let tokens = cleanTarget.components(separatedBy: "/").filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return replacement.value
        }

        let updated = updateNode(tokens: tokens, current: root.value, replacementValue: replacement.value.value)
        return AnyCodable(updated)
    }
}
