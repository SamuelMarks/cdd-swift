/// Criterion evaluation and payload replacement helpers for Arazzo 1.1.0 runtime expressions.
import Foundation

extension ArazzoExpressionEvaluator {
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
            let valStr = value.description
            let pattern = condition.hasPrefix("/") && condition.hasSuffix("/")
                ? String(condition.dropFirst().dropLast())
                : condition
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(location: 0, length: valStr.utf16.count)
            return regex.firstMatch(in: valStr, options: [], range: range) != nil

        case .simple, .none, .jsonpath, .xpath:
            return evaluateSimpleCondition(condition, value: value)
        }
    }

    /// Evaluates a simple comparison condition (`==`, `!=`, `<=`, `>=`, `<`, `>`, or direct equality) against `value`.
    ///
    /// - Parameters:
    ///   - condition: Trimmed condition string.
    ///   - value: The evaluated `AnyCodable` value.
    /// - Returns: `true` if the comparison holds.
    private static func evaluateSimpleCondition(_ condition: String, value: AnyCodable) -> Bool {
        if condition.hasPrefix("==") {
            let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            return compareEquality(value: value, expected: expected)
        }
        if condition.hasPrefix("!=") {
            let expected = condition.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            return !compareEquality(value: value, expected: expected)
        }
        for op in ["<=", ">=", "<", ">"] where condition.hasPrefix(op) {
            let expected = condition.dropFirst(op.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return compareNumeric(value: value.jsonValue, expected: expected, op: op)
        }
        return compareEquality(value: value, expected: condition)
    }

    /// Compares a `JSONValue` numerically against an expected number string using `<=`, `>=`, `<`, or `>`.
    ///
    /// - Parameters:
    ///   - value: The evaluated `JSONValue`.
    ///   - expected: The expected numeric string.
    ///   - op: The comparison operator (`"<="`, `">="`, `"<"`, or `">"`).
    /// - Returns: `true` if both values are numeric and satisfy `op`.
    private static func compareNumeric(value: JSONValue, expected: String, op: String) -> Bool {
        guard let numVal = toDouble(value), let numExp = Double(expected) else { return false }
        switch op {
        case "<=": return numVal <= numExp
        case ">=": return numVal >= numExp
        case "<": return numVal < numExp
        default: return numVal > numExp
        }
    }

    /// Compares an `AnyCodable` value against an expected string representation.
    ///
    /// - Parameters:
    ///   - value: The evaluated runtime value.
    ///   - expected: Expected string value.
    /// - Returns: True if matching.
    private static func compareEquality(value: AnyCodable, expected: String) -> Bool {
        let cleanExpected = expected.hasPrefix(#"""#) && expected.hasSuffix(#"""#)
            ? String(expected.dropFirst().dropLast())
            : expected

        if let intVal = value.intValue, let expInt = Int(cleanExpected) {
            return intVal == expInt
        }
        if case let .double(dblVal) = value.jsonValue, let expDbl = Double(cleanExpected) {
            return dblVal == expDbl
        }
        if let boolVal = value.boolValue, let expBool = Bool(cleanExpected) {
            return boolVal == expBool
        }
        return value.description == cleanExpected
    }

    /// Converts a numeric or string `JSONValue` to a `Double` if possible.
    ///
    /// - Parameter val: The `JSONValue` to convert.
    /// - Returns: `Double` representation or `nil`.
    private static func toDouble(_ val: JSONValue) -> Double? {
        switch val {
        case let .double(d):
            return d
        case let .int(i):
            return Double(i)
        case let .string(s):
            return Double(s)
        default:
            return nil
        }
    }

    /// Recursively updates a `.object` or `.array` `JSONValue` along token path segments.
    ///
    /// - Parameters:
    ///   - tokens: Path segments to traverse.
    ///   - current: Current `JSONValue` container node.
    ///   - replacementValue: The `JSONValue` to write at the terminal token.
    /// - Returns: The mutated `JSONValue` container.
    private static func updateNode(tokens: [String], current: JSONValue, replacementValue: JSONValue) -> JSONValue {
        let first = tokens[0]
        let remaining = Array(tokens.dropFirst())

        switch current {
        case var .object(dict):
            if remaining.isEmpty {
                dict[first] = replacementValue
            } else {
                let child = dict[first] ?? .object([:])
                dict[first] = updateNode(tokens: remaining, current: child, replacementValue: replacementValue)
            }
            return .object(dict)
        case var .array(arr):
            if let idx = Int(first), idx >= 0, idx < arr.count {
                if remaining.isEmpty {
                    arr[idx] = replacementValue
                } else {
                    arr[idx] = updateNode(tokens: remaining, current: arr[idx], replacementValue: replacementValue)
                }
                return .array(arr)
            }
            return current
        default:
            return current
        }
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

        let updated = updateNode(tokens: tokens, current: root.jsonValue, replacementValue: replacement.value.jsonValue)
        return AnyCodable(updated)
    }
}
