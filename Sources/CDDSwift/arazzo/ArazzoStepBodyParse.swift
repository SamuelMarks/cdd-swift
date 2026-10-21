/// SwiftSyntax visitor reconstructing Arazzo 1.1.0 workflow steps, criteria, retry loops, and outputs from Swift function bodies.
import Foundation
import SwiftSyntax

/// AST `SyntaxVisitor` that traverses a workflow function's `CodeBlockSyntax` to reconstruct `ArazzoStep` definitions, criteria, retry
/// loops, and outputs.
public final class WorkflowStepBodyVisitor: SyntaxVisitor {
    /// Default prefix used when synthesizing step identifiers from bare assertions.
    public let defaultStepIdPrefix: String
    /// Ordered list of reconstructed `ArazzoStep` definitions.
    public var steps: [ArazzoStep] = []

    /// Active step identifier being accumulated.
    private var currentStepId: String?
    /// Active operation identifier being accumulated.
    private var currentOpId: String?
    /// Active success criteria list for the current step.
    private var currentCriteria: [ArazzoCriterion] = []
    /// Active retry limit for the current step.
    private var currentRetries: Int?
    /// Active output expression mappings for the current step.
    private var currentOutputs: [String: AnyCodable] = [:]

    /// Initializes a `WorkflowStepBodyVisitor`.
    ///
    /// - Parameter defaultStepIdPrefix: Fallback prefix for unnamed steps.
    public init(defaultStepIdPrefix: String) {
        self.defaultStepIdPrefix = defaultStepIdPrefix
        super.init(viewMode: .sourceAccurate)
    }

    /// Inspects leading trivia on every token for `// Step: <id>`, `/// @Step(...)`, and `// Operation dispatch: <opId>` directives.
    ///
    /// - Parameter token: The `TokenSyntax` node being visited.
    /// - Returns: `.visitChildren` to continue traversal.
    override public func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        let q = String(UnicodeScalar(34))
        for piece in token.leadingTrivia {
            switch piece {
            case let .lineComment(text):
                let line = text.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("// Step: ") {
                    flushCurrentStep()
                    currentStepId = String(line.dropFirst("// Step: ".count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("// Operation dispatch: ") {
                    currentOpId = String(line.dropFirst("// Operation dispatch: ".count)).trimmingCharacters(in: .whitespaces)
                }
            case let .docLineComment(text):
                let line = text.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("/// @Step(id: " + q) {
                    flushCurrentStep()
                    if let idRange = line.range(of: "id: " + q),
                       let endId = line.range(of: q, range: idRange.upperBound ..< line.endIndex) {
                        currentStepId = String(line[idRange.upperBound ..< endId.lowerBound])
                    }
                    if let opRange = line.range(of: "operationId: " + q),
                       let endOp = line.range(of: q, range: opRange.upperBound ..< line.endIndex) {
                        currentOpId = String(line[opRange.upperBound ..< endOp.lowerBound])
                    }
                }
            default:
                break
            }
        }
        return .visitChildren
    }

    /// Visits `WhileStmtSyntax` nodes (e.g. `while attempt <= 2`) to extract retry limits.
    ///
    /// - Parameter node: The `WhileStmtSyntax` node being visited.
    /// - Returns: `.visitChildren` to inspect statements inside the retry loop.
    override public func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        for conditionElement in node.conditions {
            if case let .expression(expr) = conditionElement.condition,
               let seq = expr.as(SequenceExprSyntax.self) {
                for elem in seq.elements {
                    if let intLit = elem.as(IntegerLiteralExprSyntax.self),
                       let limit = Int(intLit.literal.text), limit > 0 {
                        currentRetries = limit
                    }
                }
            }
        }
        return .visitChildren
    }

    /// Visits `FunctionCallExprSyntax` nodes to detect `client.<op>()`, `operationRunner("<op>", ...)`, `ArazzoCriterion(...)`, and
    /// `XCTAssertEqual(...)`.
    ///
    /// - Parameter node: The `FunctionCallExprSyntax` node being visited.
    /// - Returns: `.visitChildren` to inspect nested call expressions.
    override public func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let callee = node.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if callee.hasPrefix("client.") {
            let callName = String(callee.dropFirst("client.".count))
            if currentStepId == nil {
                currentStepId = callName + "Step"
            }
            if currentOpId == nil {
                currentOpId = callName
            }
        } else if callee == "ArazzoCriterion" {
            extractCriterionFromCall(node)
        } else if callee == "XCTAssertEqual" {
            extractCriterionFromXCTAssert(node)
        }

        return .visitChildren
    }

    /// Extracts an `ArazzoCriterion` from an `ArazzoCriterion(context: ..., condition: ...)` call expression.
    ///
    /// - Parameter node: The `FunctionCallExprSyntax` node representing the `ArazzoCriterion` initializer call.
    private func extractCriterionFromCall(_ node: FunctionCallExprSyntax) {
        var ctxVal: String?
        var condVal: String?
        for arg in node.arguments {
            let label = arg.label?.text
            if let strLit = arg.expression.as(StringLiteralExprSyntax.self),
               let seg = strLit.segments.first?.as(StringSegmentSyntax.self) {
                if label == "context" {
                    ctxVal = seg.content.text
                } else if label == "condition" {
                    condVal = seg.content.text
                }
            }
        }
        if let ctx = ctxVal, let cond = condVal {
            currentCriteria.append(ArazzoCriterion(context: ctx, condition: cond))
        }
    }

    /// Extracts an `ArazzoCriterion` from an `XCTAssertEqual(res.statusCode, <code>)` call expression.
    ///
    /// - Parameter node: The `FunctionCallExprSyntax` node representing the `XCTAssertEqual` call.
    private func extractCriterionFromXCTAssert(_ node: FunctionCallExprSyntax) {
        if node.arguments.count >= 2 {
            let firstArg = node.arguments[node.arguments.startIndex]
            let firstExpr = firstArg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if firstExpr.hasSuffix(".statusCode") {
                let secondIndex = node.arguments.index(after: node.arguments.startIndex)
                let codeVal = node.arguments[secondIndex].expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if currentStepId == nil {
                    currentStepId = defaultStepIdPrefix + "Step"
                }
                currentCriteria.append(ArazzoCriterion(context: "$statusCode", condition: "== " + codeVal))
            }
        }
    }

    /// Visits `SequenceExprSyntax` nodes to capture `currentOutputs["key"] = ...` step output assignments.
    ///
    /// - Parameter node: The `SequenceExprSyntax` node being visited.
    /// - Returns: `.visitChildren` to continue traversal.
    override public func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        guard let firstElem = node.elements.first,
              let subExpr = firstElem.as(SubscriptCallExprSyntax.self),
              subExpr.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines) == "currentOutputs",
              let keyArg = subExpr.arguments.first,
              let keyLit = keyArg.expression.as(StringLiteralExprSyntax.self),
              let keySeg = keyLit.segments.first?.as(StringSegmentSyntax.self)
        else {
            return .visitChildren
        }
        let k = keySeg.content.text
        for elem in node.elements.dropFirst() {
            let callExpr = elem.as(TryExprSyntax.self)?.expression.as(FunctionCallExprSyntax.self) ?? elem.as(FunctionCallExprSyntax.self)
            if let call = callExpr,
               let firstArg = call.arguments.first,
               let strLit = firstArg.expression.as(StringLiteralExprSyntax.self),
               let strSeg = strLit.segments.first?.as(StringSegmentSyntax.self) {
                currentOutputs[k] = AnyCodable(strSeg.content.text)
            }
        }
        return .visitChildren
    }

    /// Finalizes any accumulated step at the end of the function body traversal.
    public func finalizePendingStep() {
        flushCurrentStep()
    }

    /// Appends the currently accumulated step to `steps` and resets active step state.
    private func flushCurrentStep() {
        guard let stepId = currentStepId else { return }
        var onFailure: [ArazzoFailureAction]?
        if let retries = currentRetries, retries > 0 {
            onFailure = [
                ArazzoFailureAction(
                    name: "retryOnFailure",
                    type: .retry,
                    retryAfter: 1.0,
                    retryLimit: retries
                )
            ]
        }
        steps.append(
            ArazzoStep(
                stepId: stepId,
                operationId: currentOpId ?? stepId,
                successCriteria: currentCriteria.isEmpty ? nil : currentCriteria,
                onFailure: onFailure,
                outputs: currentOutputs.isEmpty ? nil : currentOutputs
            )
        )
        currentStepId = nil
        currentOpId = nil
        currentCriteria = []
        currentRetries = nil
        currentOutputs = [:]
    }
}
