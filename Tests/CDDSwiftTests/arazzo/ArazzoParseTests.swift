@testable import CDDSwift
import XCTest

final class ArazzoParseTests: XCTestCase {
    func testArazzoDocumentBuilder() throws {
        let comp = ArazzoComponents(
            parameters: ["auth": ArazzoParameter(name: "Authorization", in: .header, value: AnyCodable("Bearer token"))]
        )
        let builder = ArazzoDocumentBuilder(
            title: "Builder Title",
            version: "1.1.0",
            summary: "Builder Summary",
            description: "Builder Description"
        )
        .withSelfRef("https://example.com/arazzo.json")
        .addSourceDescription(name: "petstore", url: "./petstore.json", type: .openapi)
        .withComponents(comp)
        .addWorkflow(
            ArazzoWorkflow(
                workflowId: "adoptPet",
                summary: "Adopt a pet",
                steps: [ArazzoStep(stepId: "findPet", operationId: "getPetById")]
            )
        )

        let spec = builder.build()
        XCTAssertEqual(spec.info.title, "Builder Title")
        XCTAssertEqual(spec.selfRef, "https://example.com/arazzo.json")
        XCTAssertEqual(spec.sourceDescriptions.count, 1)
        XCTAssertEqual(spec.workflows.count, 1)
        XCTAssertNotNil(spec.components)

        let json = try builder.serialize()
        XCTAssertTrue(json.contains(#""adoptPet""#))

        // Test default sourceDescription fallback when none added
        let emptyBuilder = ArazzoDocumentBuilder(title: "Fallback", version: "1.0.0")
        let fallbackSpec = emptyBuilder.build()
        XCTAssertEqual(fallbackSpec.sourceDescriptions.first?.name, "defaultApi")
    }

    func testSwiftASTArazzoParserOnGeneratedSDK() throws {
        let originalSpec = ArazzoSpecification(
            info: ArazzoInfo(title: "Petstore Workflows", version: "1.1.0"),
            sourceDescriptions: [
                ArazzoSourceDescription(name: "petstore", url: "./openapi.json", type: .openapi)
            ],
            workflows: [
                ArazzoWorkflow(
                    workflowId: "registerPet",
                    summary: "Registers and verifies a pet",
                    inputs: Schema(
                        type: "object",
                        properties: [
                            "name": Schema(type: "string"),
                            "age": Schema(type: "integer"),
                            "weight": Schema(type: "number"),
                            "vaccinated": Schema(type: "boolean")
                        ]
                    ),
                    steps: [
                        ArazzoStep(
                            stepId: "createPetStep",
                            operationId: "addPet",
                            successCriteria: [ArazzoCriterion(context: "$statusCode", condition: "== 200")],
                            onFailure: [ArazzoFailureAction(name: "retryAdd", type: .retry, retryAfter: 1.0, retryLimit: 2)],
                            outputs: ["petId": AnyCodable("$response.body#/id")]
                        )
                    ]
                )
            ]
        )

        let swiftCode = ArazzoSdkEmitter.emitWorkflowClient(from: originalSpec)
        let parser = SwiftASTArazzoParser()
        let parsedSpec = try parser.parseSpecification(from: swiftCode)

        XCTAssertEqual(parsedSpec.workflows.count, 1)
        let wf = try XCTUnwrap(parsedSpec.workflows.first)
        XCTAssertEqual(wf.workflowId, "registerPet")
        XCTAssertNotNil(wf.inputs?.properties?["name"])
        XCTAssertEqual(wf.inputs?.properties?["age"]?.type, "integer")
        XCTAssertEqual(wf.inputs?.properties?["weight"]?.type, "number")
        XCTAssertEqual(wf.inputs?.properties?["vaccinated"]?.type, "boolean")
        XCTAssertEqual(wf.steps.first?.stepId, "createPetStep")
        XCTAssertEqual(wf.steps.first?.operationId, "addPet")
        XCTAssertEqual(wf.steps.first?.onFailure?.first?.retryLimit, 2)
        XCTAssertEqual(wf.steps.first?.outputs?["petId"], AnyCodable("$response.body#/id"))
    }

    func testSwiftASTArazzoParserAnnotationsAndTestSuites() throws {
        let customSwift = """
        import Foundation
        import XCTest

        public struct EmptyInputs {
            public let parameters: [String: AnyCodable]
            public var computed: String { "ignore" }
        }

        /// End-to-end integration test suite for `Custom Suite` (v1.1.0).
        public final class CustomWorkflowTests: XCTestCase {
            override public func setUp() {}
            public func helperNotAWorkflow() {}
            public func helperWithParam(x: Int) {}
            public func probeSomething() {}
            public func bareDeclarationWithoutBody(inputs: EmptyInputs)

            /// @Workflow(id: "annotatedFlow", summary: "Custom annotated workflow")
            public func runAnnotated() async throws {
                /// @Step(id: "firstStep", operationId: "loginUser")
                let _ = try await client.loginUser()
                /// @Step(id: "secondStep", operationId: "fetchProfile")
                let _ = try await client.fetchProfile()
            }

            /// Tests checkout assertions
            public func testCheckoutScenario() async throws {
                let res = try await client.createCart()
                XCTAssertEqual(res.statusCode, 201)
            }

            /// @Workflow(id: "emptyBodyFlow")
            public func emptyFlow() {
            }
        }
        """

        let parser = SwiftASTArazzoParser()
        let parsedSpec = try parser.parseSpecification(from: customSwift)

        XCTAssertEqual(parsedSpec.info.title, "Custom Suite")
        XCTAssertEqual(parsedSpec.workflows.count, 4)

        let annotated = try XCTUnwrap(parsedSpec.workflows.first { $0.workflowId == "annotatedFlow" })
        XCTAssertEqual(annotated.steps.count, 2)
        XCTAssertEqual(annotated.steps[0].stepId, "firstStep")
        XCTAssertEqual(annotated.steps[0].operationId, "loginUser")

        let testWf = try XCTUnwrap(parsedSpec.workflows.first { $0.workflowId == "checkoutScenario" })
        XCTAssertEqual(testWf.steps.first?.operationId, "createCart")
        XCTAssertEqual(testWf.steps.first?.successCriteria?.first?.condition, "== 201")

        let emptyWf = try XCTUnwrap(parsedSpec.workflows.first { $0.workflowId == "emptyBodyFlow" })
        XCTAssertEqual(emptyWf.steps.first?.stepId, "step1")

        // Also test visitor with pre-populated sourceDescriptions via direct walk
        let customSourceCode = """
        /// Suite for `ArazzoSpecification`
        /// Workflows for `RealTitle`
        public class MyOrchestrator {
            public func customAction(inputs: UnknownInputs) {
                XCTAssertEqual(resp.statusCode, 200)
            }
        }
        """
        let spec2 = try parser.parseSpecification(from: customSourceCode)
        XCTAssertEqual(spec2.info.title, "RealTitle")
        XCTAssertEqual(spec2.workflows.first?.workflowId, "customAction")
    }
}
