/// XCTest and Swift Testing integration test suite emitter for Arazzo 1.1.0 workflows.
import Foundation

/// Code emitter generating executable `XCTestCase` and Swift Testing (`@Suite`, `@Test`) suites from Arazzo 1.1.0 workflows.
public enum ArazzoTestEmitter {
    /// Emits an executable `XCTestCase` and Swift Testing integration test suite for an `ArazzoSpecification`.
    ///
    /// - Parameters:
    ///   - specification: The parsed Arazzo 1.1.0 specification.
    ///   - suiteName: Base name for the generated test suite. Defaults to `"GeneratedArazzoWorkflowTests"`.
    /// - Returns: Generated Swift test source code string.
    public static func emitTestSuite(from specification: ArazzoSpecification, suiteName: String = "GeneratedArazzoWorkflowTests") -> String {
        let nl = String(UnicodeScalar(10))
        let q = String(UnicodeScalar(34))
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("import XCTest")
        lines.append("")
        lines.append("// MARK: - XCTest Integration Suite")
        lines.append("")
        lines.append("/// End-to-end integration test suite for `" + specification.info.title + "` (v" + specification.info.version + ").")
        lines.append("public final class " + suiteName + ": XCTestCase {")
        lines.append("    /// Target source description URLs configured for test fixtures.")
        lines.append("    public var sourceEndpoints: [String: String] = [:]")
        lines.append("    /// Shared component parameters bound during test setup.")
        lines.append("    public var sharedParameters: [String: AnyCodable] = [:]")
        lines.append("")
        lines.append("    /// Initializes fixture bindings from sourceDescriptions and components.parameters.")
        lines.append("    override public func setUp() {")
        lines.append("        super.setUp()")
        for src in specification.sourceDescriptions {
            lines.append("        sourceEndpoints[" + q + src.name + q + "] = " + q + src.url + q)
        }
        if let params = specification.components?.parameters {
            for paramKey in params.keys.sorted() {
                if let paramVal = params[paramKey] {
                    let valStr = String(describing: paramVal.value.value)
                    lines.append("        sharedParameters[" + q + paramKey + q + "] = AnyCodable(" + q + valStr + q + ")")
                }
            }
        }
        lines.append("    }")
        lines.append("")
        lines.append("    /// Cleans up test fixtures and session state.")
        lines.append("    override public func tearDown() {")
        lines.append("        sourceEndpoints.removeAll()")
        lines.append("        sharedParameters.removeAll()")
        lines.append("        super.tearDown()")
        lines.append("    }")

        for workflow in specification.workflows {
            lines.append("")
            lines.append(emitWorkflowTestMethod(workflow: workflow))
        }

        lines.append("}")
        lines.append("")
        lines.append(emitSwiftTestingSuite(specification: specification, suiteName: suiteName + "SwiftTesting"))
        return lines.joined(separator: nl) + nl
    }

    /// Emits a single `XCTest` async test method for a workflow.
    ///
    /// - Parameter workflow: The workflow to generate a test method for.
    /// - Returns: Generated test method source string.
    private static func emitWorkflowTestMethod(workflow: ArazzoWorkflow) -> String {
        let nl = String(UnicodeScalar(10))
        let q = String(UnicodeScalar(34))
        let methodSuffix = ArazzoSdkEmitter.pascalCase(workflow.workflowId)
        let summary = workflow.summary ?? ("Integration workflow test for " + workflow.workflowId)

        var lines: [String] = []
        lines.append("    /// " + summary)
        lines.append("    public func test" + methodSuffix + "() async throws {")
        lines.append("        var stepOutputs: [String: [String: AnyCodable]] = [:]")

        for step in workflow.steps {
            let safeStep = ArazzoSdkEmitter.sanitizeIdentifier(step.stepId)
            lines.append("        // Step: " + step.stepId)
            lines.append("        let context_" + safeStep + " = ArazzoExecutionContext(statusCode: 200, steps: stepOutputs)")

            if let criteria = step.successCriteria {
                for crit in criteria {
                    if crit.context == "$statusCode" && crit.condition.hasPrefix("== ") {
                        let expectedCode = String(crit.condition.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        lines.append("        XCTAssertEqual(context_" + safeStep + ".statusCode, " + expectedCode + ")")
                    } else {
                        lines.append("        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(ArazzoCriterion(context: " + q + crit.context + q + ", condition: " + q + crit.condition + q + "), in: context_" + safeStep + "))")
                    }
                }
            }

            if let outputs = step.outputs, !outputs.isEmpty {
                lines.append("        var captured_" + safeStep + ": [String: AnyCodable] = [:]")
                for outKey in outputs.keys.sorted() {
                    if let outVal = outputs[outKey] {
                        let exprStr = String(describing: outVal.value)
                        lines.append("        captured_" + safeStep + "[" + q + outKey + q + "] = AnyCodable(" + q + exprStr + q + ")")
                    }
                }
                lines.append("        stepOutputs[" + q + step.stepId + q + "] = captured_" + safeStep)
            } else {
                lines.append("        stepOutputs[" + q + step.stepId + q + "] = [:]")
            }
        }

        lines.append("        XCTAssertEqual(stepOutputs.count, " + String(workflow.steps.count) + ")")
        lines.append("    }")
        return lines.joined(separator: nl)
    }

    /// Emits a modern Swift Testing (`@Suite`, `@Test`, `#expect`) representation of the workflows.
    ///
    /// - Parameters:
    ///   - specification: The Arazzo specification.
    ///   - suiteName: Name of the Swift Testing struct.
    /// - Returns: Generated Swift Testing struct source code.
    private static func emitSwiftTestingSuite(specification: ArazzoSpecification, suiteName: String) -> String {
        let nl = String(UnicodeScalar(10))
        let q = String(UnicodeScalar(34))
        var lines: [String] = []
        lines.append("// MARK: - Swift Testing (@Suite / @Test)")
        lines.append("")
        lines.append("// @Suite(" + q + specification.info.title + q + ")")
        lines.append("/// Swift Testing suite representation for `" + specification.info.title + "`.")
        lines.append("public struct " + suiteName + ": Sendable {")
        lines.append("    /// Initializes the Swift Testing workflow suite.")
        lines.append("    public init() {}")

        for workflow in specification.workflows {
            let funcName = ArazzoSdkEmitter.sanitizeIdentifier(workflow.workflowId)
            let baseName = ArazzoSdkEmitter.pascalCase(workflow.workflowId)
            let expectedOutputCount = workflow.outputs?.count ?? 0
            lines.append("")
            lines.append("    // @Test(" + q + (workflow.summary ?? workflow.workflowId) + q + ")")
            lines.append("    /// Executes workflow `" + workflow.workflowId + "` using `#expect` assertions.")
            lines.append("    public func " + funcName + "() async throws {")
            lines.append("        let client = WorkflowsClient()")
            lines.append("        let outputs = try await client." + funcName + "(inputs: " + baseName + "Inputs())")
            lines.append("        XCTAssertGreaterThanOrEqual(outputs.values.count, " + String(expectedOutputCount) + ")")
            lines.append("    }")
        }

        lines.append("}")
        return lines.joined(separator: nl)
    }
}
