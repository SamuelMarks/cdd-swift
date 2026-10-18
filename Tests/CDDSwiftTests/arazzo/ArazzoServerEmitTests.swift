@testable import CDDSwift
import SwiftParser
import XCTest

final class ArazzoServerEmitTests: XCTestCase {
    func testEmitTestSuiteAndServerOrchestrator() {
        let step1 = ArazzoStep(
            stepId: "createOrder",
            operationId: "postOrder",
            successCriteria: [
                ArazzoCriterion(context: "$statusCode", condition: "== 200"),
                ArazzoCriterion(context: "$statusCode", condition: "!= 500")
            ],
            outputs: ["orderId": AnyCodable("$response.body#/id")]
        )
        let step2 = ArazzoStep(
            stepId: "confirmOrder",
            operationId: "putOrder"
        )
        let wf1 = ArazzoWorkflow(
            workflowId: "checkoutFlow",
            summary: "Executes checkout order flow",
            steps: [step1, step2],
            outputs: ["finalOrder": AnyCodable("$steps.createOrder.outputs.orderId")]
        )
        let wf2 = ArazzoWorkflow(
            workflowId: "minimalFlow",
            steps: [step2]
        )
        let components = ArazzoComponents(
            parameters: [
                "tenantHeader": ArazzoParameter(name: "X-Tenant", in: .header, value: AnyCodable("acme"))
            ]
        )
        let spec = ArazzoSpecification(
            selfRef: "https://example.com/arazzo.json",
            info: ArazzoInfo(title: "Commerce Workflows", summary: "Summary text", description: "Detailed docs", version: "1.1.0"),
            sourceDescriptions: [
                ArazzoSourceDescription(name: "commerceApi", url: "https://api.example.com/openapi.json", type: .openapi)
            ],
            workflows: [wf1, wf2],
            components: components
        )

        let testSuiteCode = ArazzoTestEmitter.emitTestSuite(from: spec)
        XCTAssertTrue(testSuiteCode.contains("public final class GeneratedArazzoWorkflowTests: XCTestCase"))
        XCTAssertTrue(testSuiteCode.contains(#"sourceEndpoints["commerceApi"] = "https://api.example.com/openapi.json""#))
        XCTAssertTrue(testSuiteCode.contains(#"sharedParameters["tenantHeader"] = AnyCodable("acme")"#))
        XCTAssertTrue(testSuiteCode.contains("public func testCheckoutFlow() async throws"))
        XCTAssertTrue(testSuiteCode.contains("XCTAssertEqual(context_createOrder.statusCode, 200)"))
        XCTAssertTrue(testSuiteCode.contains("XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion"))
        XCTAssertTrue(testSuiteCode.contains("public struct GeneratedArazzoWorkflowTestsSwiftTesting: Sendable"))

        let parsedTestTree = Parser.parse(source: testSuiteCode)
        XCTAssertFalse(parsedTestTree.statements.isEmpty)

        // Also test without components
        let specNoComp = ArazzoSpecification(
            info: ArazzoInfo(title: "NoComp", version: "1.0.0"),
            sourceDescriptions: [],
            workflows: [wf2]
        )
        let testSuiteNoComp = ArazzoTestEmitter.emitTestSuite(from: specNoComp, suiteName: "CustomSuite")
        XCTAssertTrue(testSuiteNoComp.contains("public final class CustomSuite: XCTestCase"))

        let serverCode = ArazzoServerEmitter.emitServerOrchestrator(from: spec)
        XCTAssertTrue(serverCode.contains("public struct WorkflowProbeReport: Codable, Sendable, Equatable"))
        XCTAssertTrue(serverCode.contains("public final class ServerWorkflowOrchestrator: Sendable"))
        XCTAssertTrue(serverCode.contains("public func runAllProbes() async -> [WorkflowProbeReport]"))
        XCTAssertTrue(serverCode.contains("public func probeCheckoutFlow() async -> WorkflowProbeReport"))

        let parsedServerTree = Parser.parse(source: serverCode)
        XCTAssertFalse(parsedServerTree.statements.isEmpty)
    }

    func testArazzoEmitterJSONAndYAML() throws {
        let wf = ArazzoWorkflow(
            workflowId: "syncUsers",
            summary: "Synchronizes users",
            steps: [
                ArazzoStep(stepId: "fetchStep", operationId: "listUsers"),
                ArazzoStep(stepId: "bareStep")
            ]
        )
        let spec = ArazzoSpecification(
            selfRef: "https://example.com/self.json",
            info: ArazzoInfo(title: "Sync Spec", summary: "Sync summary", description: "Sync description", version: "1.1.0"),
            sourceDescriptions: [
                ArazzoSourceDescription(name: "usersApi", url: "./users.json", type: .openapi)
            ],
            workflows: [wf]
        )

        let json = try ArazzoEmitter.emitJSON(from: spec)
        let parsed = try ArazzoEmitter.parse(json: json)
        XCTAssertEqual(parsed, spec)

        let yaml = ArazzoEmitter.emitYAML(from: spec)
        XCTAssertTrue(yaml.contains(#"arazzo: "1.1.0""#))
        XCTAssertTrue(yaml.contains(#"$self: "https://example.com/self.json""#))
        XCTAssertTrue(yaml.contains(#"summary: "Sync summary""#))
        XCTAssertTrue(yaml.contains(#"description: "Sync description""#))
        XCTAssertTrue(yaml.contains(#"workflowId: "syncUsers""#))
        XCTAssertTrue(yaml.contains(#"operationId: "listUsers""#))

        // Minimal spec without optional fields for YAML branch coverage
        let minSpec = ArazzoSpecification(
            info: ArazzoInfo(title: "Min", version: "1.1.0"),
            sourceDescriptions: [],
            workflows: [ArazzoWorkflow(workflowId: "minWf", steps: [ArazzoStep(stepId: "s1")])]
        )
        let minYaml = ArazzoEmitter.emitYAML(from: minSpec)
        XCTAssertFalse(minYaml.contains("$self:"))

        // Invalid Arazzo version check
        let badVersionJson = """
        {
          "arazzo": "2.0.0",
          "info": { "title": "Bad", "version": "1.0.0" },
          "sourceDescriptions": [],
          "workflows": []
        }
        """
        XCTAssertThrowsError(try ArazzoEmitter.parse(json: badVersionJson))

        let v100Json = """
        {
          "arazzo": "1.0.0",
          "info": { "title": "V1", "version": "1.0.0" },
          "sourceDescriptions": [],
          "workflows": []
        }
        """
        let v100Spec = try ArazzoEmitter.parse(json: v100Json)
        XCTAssertEqual(v100Spec.arazzo, "1.0.0")

        let v101Json = """
        {
          "arazzo": "1.0.1",
          "info": { "title": "V101", "version": "1.0.0" },
          "sourceDescriptions": [],
          "workflows": []
        }
        """
        let v101Spec = try ArazzoEmitter.parse(json: v101Json)
        XCTAssertEqual(v101Spec.arazzo, "1.0.1")
    }

    func testArazzoCodeMerger() {
        let existing = """
        import Foundation

        /// Custom struct doc
        public struct CheckoutInputs {
            public let oldField: String?
        }

        public struct UserCustomHelper {
            public let x: Int
        }

        /// Custom enum doc
        public enum WorkflowHelperEnum {
            case old
        }

        public enum UnchangedEnum {
            case stay
        }

        /// Custom class doc
        public class WorkflowsClient {
            public func checkout(inputs: CheckoutInputs) async throws {
            }

            public func customUserHelperMethod() -> String {
                return "preserved"
            }
        }

        public class UnchangedClass {
        }
        """

        let generated = """
        public struct CheckoutInputs {
            public let newField: Int?
        }

        public struct NewWorkflowOutputs {
            public let ok: Bool
        }

        public enum WorkflowHelperEnum {
            case updated
        }

        public enum BrandNewEnum {
            case added
        }

        public class WorkflowsClient {
            public func checkout(inputs: CheckoutInputs) async throws {
                let x = 1
            }
        }

        public class BrandNewClass {
        }
        """

        let merged = ArazzoCodeMerger.merge(generatedCode: generated, into: existing)
        XCTAssertTrue(merged.contains("public let newField: Int?"))
        XCTAssertTrue(merged.contains("public struct UserCustomHelper"))
        XCTAssertTrue(merged.contains("public struct NewWorkflowOutputs"))
        XCTAssertTrue(merged.contains("case updated"))
        XCTAssertTrue(merged.contains("public enum BrandNewEnum"))
        XCTAssertTrue(merged.contains("public enum UnchangedEnum"))
        XCTAssertTrue(merged.contains("public class BrandNewClass"))
        XCTAssertTrue(merged.contains("public class UnchangedClass"))
        XCTAssertTrue(merged.contains("customUserHelperMethod"))

        // Also test class merge when no extra user methods exist & newline variations
        let nl = String(UnicodeScalar(10))
        let existing2 = "public class WorkflowsClient {" + nl + "    public func checkout() {}" + nl + "}" + nl
        let generated2 = "public class WorkflowsClient {" + nl + "    public func checkout() {}" + nl + "}" + nl + "public struct AppendedStruct {}"
        let merged2 = ArazzoCodeMerger.merge(generatedCode: generated2, into: existing2)
        XCTAssertTrue(merged2.contains("AppendedStruct"))

        let existing3 = "public struct First {}" + nl + nl
        let generated3 = "public struct Second {}"
        let merged3 = ArazzoCodeMerger.merge(generatedCode: generated3, into: existing3)
        XCTAssertTrue(merged3.contains("Second"))
    }
}
