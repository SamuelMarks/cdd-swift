import CDDSwift
import SwiftParser
import XCTest

final class ArazzoSdkEmitTests: XCTestCase {
    func testSanitizeIdentifierAndPascalCase() {
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier("normalName"), "normalName")
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier("kebab-case-name"), "kebabCaseName")
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier("snake_case_name"), "snakeCaseName")
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier("default"), "`default`")
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier("class"), "`class`")
        XCTAssertEqual(ArazzoSdkEmitter.sanitizeIdentifier(""), "identifier")

        XCTAssertEqual(ArazzoSdkEmitter.pascalCase("orderCheckout"), "OrderCheckout")
        XCTAssertEqual(ArazzoSdkEmitter.pascalCase("order-checkout"), "OrderCheckout")
        XCTAssertEqual(ArazzoSdkEmitter.pascalCase(""), "WorkflowType")
    }

    func testEmitWorkflowClient() {
        let criterion = ArazzoCriterion(
            context: "$statusCode",
            condition: "200",
            type: .simple
        )
        let failureAction = ArazzoFailureAction(
            name: "retryOnError",
            type: .retry,
            retryAfter: 0.5,
            retryLimit: 2
        )
        let step1 = ArazzoStep(
            stepId: "stepCreateUser",
            description: "Creates user",
            operationId: "createUser",
            successCriteria: [criterion],
            onFailure: [failureAction],
            outputs: [
                "userId": AnyCodable("$response.body#/id"),
                "numericId": AnyCodable(123)
            ]
        )
        let step2 = ArazzoStep(
            stepId: "stepGetUser",
            description: "Gets user"
        )

        let inputSchema = Schema(
            type: "object",
            properties: [
                "username": Schema(type: "string"),
                "age": Schema(type: "integer"),
                "score": Schema(type: "number"),
                "active": Schema(type: "boolean"),
                "tags": Schema(type: "array"),
                "metadata": Schema(type: "object")
            ]
        )

        let workflowFull = ArazzoWorkflow(
            workflowId: "userOnboarding",
            summary: "Onboards new user",
            inputs: inputSchema,
            steps: [step1, step2],
            outputs: [
                "createdId": AnyCodable("$steps.stepCreateUser.outputs.userId"),
                "numericCount": AnyCodable(42)
            ]
        )

        let workflowEmpty = ArazzoWorkflow(
            workflowId: "simpleFlow",
            inputs: Schema(type: "object", properties: [:]),
            steps: [step2]
        )

        let spec = ArazzoSpecification(
            arazzo: "1.1.0",
            info: ArazzoInfo(title: "Test Spec", version: "1.0.0"),
            sourceDescriptions: [
                ArazzoSourceDescription(name: "api", url: "https://example.com/spec.json", type: .openapi)
            ],
            workflows: [workflowFull, workflowEmpty]
        )

        let emittedDefault = ArazzoSdkEmitter.emitWorkflowClient(from: spec)
        XCTAssertTrue(emittedDefault.contains("APIClient"))

        let emitted = ArazzoSdkEmitter.emitWorkflowClient(from: spec, clientClassName: "CustomClient")
        XCTAssertTrue(emitted.contains("public class WorkflowsClient"))
        XCTAssertTrue(emitted.contains("public struct UserOnboardingInputs"))
        XCTAssertTrue(emitted.contains("public struct UserOnboardingOutputs"))
        XCTAssertTrue(emitted.contains("public func userOnboarding(inputs: UserOnboardingInputs)"))
        XCTAssertTrue(emitted.contains("public struct SimpleFlowInputs"))
        XCTAssertTrue(emitted.contains("public func simpleFlow(inputs: SimpleFlowInputs)"))
        XCTAssertTrue(emitted.contains("CustomClient"))

        let parsedSyntax = Parser.parse(source: emitted)
        XCTAssertFalse(parsedSyntax.hasError)
    }
}
