/// Unit tests for Arazzo 1.1.0 domain models, enums, and `CDDError` descriptions.
import CDDSwift
import XCTest

/// Test suite verifying `ArazzoSpecification` models and `Codable` round-tripping.
final class ArazzoModelsTests: XCTestCase {
    /// Builds a comprehensive `ArazzoSpecification` instance for round-trip testing.
    ///
    /// - Returns: The populated `ArazzoSpecification`.
    private func makeSampleArazzoSpecification() -> ArazzoSpecification {
        let criterion = ArazzoCriterion(context: "$statusCode", condition: "200", type: .simple)
        let param = ArazzoParameter(name: "userId", in: .path, value: AnyCodable("123"))
        let successAction = ArazzoSuccessAction(
            name: "proceed", type: .goto, workflowId: "nextFlow", stepId: "step2", parameters: [param], criteria: [criterion]
        )
        let failureAction = ArazzoFailureAction(
            name: "handleError", type: .retry, workflowId: nil, stepId: nil,
            parameters: [param], retryAfter: 1.5, retryLimit: 3, criteria: [criterion]
        )
        let replacement = ArazzoPayloadReplacement(target: "/id", targetSelectorType: .jsonpointer, value: AnyCodable("newId"))
        let requestBody = ArazzoRequestBody(
            contentType: "application/json", payload: AnyCodable(["name": "test"]), replacements: [replacement]
        )
        let step = ArazzoStep(
            stepId: "step1", description: "Initial step", operationId: "getUser", operationPath: "/paths/~1users/get",
            channelPath: "users/events", workflowId: "subFlow", parameters: [param], requestBody: requestBody,
            successCriteria: [criterion], onSuccess: [successAction], onFailure: [failureAction],
            outputs: ["userId": AnyCodable("$response.body#/id")], timeout: 5000, correlationId: "corr-1",
            action: .send, dependsOn: ["step0"]
        )
        let workflow = ArazzoWorkflow(
            workflowId: "userWorkflow", summary: "Fetches user data", description: "Detailed workflow description",
            inputs: Schema(type: "object"), dependsOn: ["authWorkflow"], steps: [step],
            successActions: [successAction], failureActions: [failureAction],
            outputs: ["finalUser": AnyCodable("$steps.step1.outputs.userId")], parameters: [param]
        )
        let components = ArazzoComponents(
            inputs: ["UserSchema": Schema(type: "object")], parameters: ["userId": param],
            successActions: ["proceed": successAction], failureActions: ["retry": failureAction]
        )
        return ArazzoSpecification(
            arazzo: "1.1.0", selfRef: "https://example.com/arazzo.json",
            info: ArazzoInfo(
                title: "User Workflow Suite",
                summary: "A suite for managing users",
                description: "Markdown docs",
                version: "1.0.0"
            ),
            sourceDescriptions: [ArazzoSourceDescription(name: "userApi", url: "https://api.example.com/openapi.json", type: .openapi)],
            workflows: [workflow], components: components
        )
    }

    /// Verifies full JSON encoding and decoding round-trip of `ArazzoSpecification` and all nested types.
    func testArazzoModelsRoundtrip() throws {
        let spec = makeSampleArazzoSpecification()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(spec)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ArazzoSpecification.self, from: data)

        XCTAssertEqual(decoded.arazzo, "1.1.0")
        XCTAssertEqual(decoded.selfRef, "https://example.com/arazzo.json")
        XCTAssertEqual(decoded.info.title, "User Workflow Suite")
        XCTAssertEqual(decoded.sourceDescriptions.count, 1)
        XCTAssertEqual(decoded.sourceDescriptions.first?.type, .openapi)
        XCTAssertEqual(decoded.workflows.count, 1)
        XCTAssertEqual(decoded.workflows.first?.workflowId, "userWorkflow")
        XCTAssertEqual(decoded.workflows.first?.steps.count, 1)
        XCTAssertEqual(decoded.workflows.first?.steps.first?.stepId, "step1")
        XCTAssertEqual(decoded.workflows.first?.steps.first?.action, .send)
        XCTAssertEqual(decoded.components?.parameters?["userId"]?.name, "userId")
    }

    /// Verifies raw string values of all Arazzo 1.1.0 domain enums.
    func testArazzoEnums() {
        XCTAssertEqual(ArazzoSourceType.openapi.rawValue, "openapi")
        XCTAssertEqual(ArazzoSourceType.asyncapi.rawValue, "asyncapi")
        XCTAssertEqual(ArazzoSourceType.arazzo.rawValue, "arazzo")

        XCTAssertEqual(ArazzoParameterLocation.path.rawValue, "path")
        XCTAssertEqual(ArazzoParameterLocation.query.rawValue, "query")
        XCTAssertEqual(ArazzoParameterLocation.header.rawValue, "header")
        XCTAssertEqual(ArazzoParameterLocation.cookie.rawValue, "cookie")

        XCTAssertEqual(ArazzoCriterionType.simple.rawValue, "simple")
        XCTAssertEqual(ArazzoCriterionType.regex.rawValue, "regex")
        XCTAssertEqual(ArazzoCriterionType.jsonpath.rawValue, "jsonpath")
        XCTAssertEqual(ArazzoCriterionType.xpath.rawValue, "xpath")

        XCTAssertEqual(ArazzoSuccessActionType.end.rawValue, "end")
        XCTAssertEqual(ArazzoSuccessActionType.goto.rawValue, "goto")

        XCTAssertEqual(ArazzoFailureActionType.end.rawValue, "end")
        XCTAssertEqual(ArazzoFailureActionType.retry.rawValue, "retry")
        XCTAssertEqual(ArazzoFailureActionType.goto.rawValue, "goto")

        XCTAssertEqual(ArazzoAsyncAction.send.rawValue, "send")
        XCTAssertEqual(ArazzoAsyncAction.receive.rawValue, "receive")

        XCTAssertEqual(ArazzoTargetSelectorType.jsonpointer.rawValue, "jsonpointer")
        XCTAssertEqual(ArazzoTargetSelectorType.jsonpath.rawValue, "jsonpath")
        XCTAssertEqual(ArazzoTargetSelectorType.xpath.rawValue, "xpath")
    }

    /// Verifies `description` and `errorDescription` on Arazzo-specific `CDDError` cases.
    func testCDDErrorArazzoDescriptions() {
        let valErr = CDDError.arazzoValidationError("invalid schema")
        XCTAssertTrue(valErr.description.contains("invalid schema"))
        XCTAssertEqual(valErr.errorDescription, valErr.description)

        let exprErr = CDDError.arazzoExpressionEvaluationError(expression: "$steps.s1.outputs.id", context: "payload")
        XCTAssertTrue(exprErr.description.contains("$steps.s1.outputs.id"))
        XCTAssertEqual(exprErr.errorDescription, exprErr.description)

        let stepErr = CDDError.arazzoStepExecutionFailed(stepId: "step1", reason: "timeout")
        XCTAssertTrue(stepErr.description.contains("step1"))
        XCTAssertEqual(stepErr.errorDescription, stepErr.description)

        let wfErr = CDDError.arazzoWorkflowNotFound("wfUnknown")
        XCTAssertTrue(wfErr.description.contains("wfUnknown"))
        XCTAssertEqual(wfErr.errorDescription, wfErr.description)

        let circErr = CDDError.arazzoCircularDependency(workflowId: "wfCycle")
        XCTAssertTrue(circErr.description.contains("wfCycle"))
        XCTAssertEqual(circErr.errorDescription, circErr.description)
    }
}
