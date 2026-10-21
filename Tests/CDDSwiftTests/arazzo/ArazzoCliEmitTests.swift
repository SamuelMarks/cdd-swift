/// Unit tests for `ArazzoCliEmitter` CLI code generation and identifier formatting.
import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `ArazzoCliEmitter`.
final class ArazzoCliEmitTests: XCTestCase {
    /// Verifies `kebabCase` and `pascalCase` conversion helpers on `ArazzoCliEmitter`.
    func testKebabCaseAndPascalCase() {
        XCTAssertEqual(ArazzoCliEmitter.kebabCase("userPurchase"), "user-purchase")
        XCTAssertEqual(ArazzoCliEmitter.kebabCase("user-id"), "user-id")
        XCTAssertEqual(ArazzoCliEmitter.kebabCase("snake_case_id"), "snake-case-id")
        XCTAssertEqual(ArazzoCliEmitter.kebabCase("---"), "arg")
        XCTAssertEqual(ArazzoCliEmitter.kebabCase(""), "arg")

        XCTAssertEqual(ArazzoCliEmitter.pascalCase("orderCheckout"), "OrderCheckoutCommand")
        XCTAssertEqual(ArazzoCliEmitter.pascalCase(""), "WorkflowCommand")
    }

    /// Verifies `emitWorkflowCLI` output and syntax validity.
    func testEmitWorkflowCLI() {
        let step = ArazzoStep(
            stepId: "step1",
            operationId: "executeJob"
        )
        let inputSchema = Schema(
            type: "object",
            properties: [
                "username": Schema(type: "string"),
                "limit": Schema(type: "integer"),
                "threshold": Schema(type: "number"),
                "dryRun": Schema(type: "boolean")
            ]
        )
        let workflowWithInputs = ArazzoWorkflow(
            workflowId: "syncCatalog",
            summary: "Syncs remote catalog data",
            inputs: inputSchema,
            steps: [step],
            outputs: ["synced": AnyCodable(true)]
        )
        let workflowSimple = ArazzoWorkflow(
            workflowId: "healthCheck",
            steps: [step]
        )
        let spec = ArazzoSpecification(
            arazzo: "1.1.0",
            info: ArazzoInfo(title: "Catalog Operations", version: "1.0.0"),
            sourceDescriptions: [
                ArazzoSourceDescription(name: "catalogApi", url: "https://example.com/api", type: .openapi)
            ],
            workflows: [workflowWithInputs, workflowSimple]
        )

        let emittedDefault = ArazzoCliEmitter.emitWorkflowCLI(from: spec)
        XCTAssertTrue(emittedDefault.contains("commandName: \"workflow\""))
        XCTAssertTrue(emittedDefault.contains("SyncCatalogCommand.self"))
        XCTAssertTrue(emittedDefault.contains("HealthCheckCommand.self"))
        XCTAssertTrue(emittedDefault.contains("@Flag(name: .customLong(\"dry-run\"), help: \"Enable dryRun\")"))
        XCTAssertTrue(emittedDefault.contains("@Option(name: .customLong(\"limit\"), help: \"The limit value\")"))
        XCTAssertTrue(emittedDefault.contains("@Option(name: .customLong(\"threshold\"), help: \"The threshold value\")"))
        XCTAssertTrue(emittedDefault.contains("@Option(name: .customLong(\"username\"), help: \"The username value\")"))
        XCTAssertTrue(emittedDefault.contains("public enum WorkflowOutputFormatter"))

        let emittedCustom = ArazzoCliEmitter.emitWorkflowCLI(from: spec, rootCommandName: "mytools")
        XCTAssertTrue(emittedCustom.contains("commandName: \"mytools\""))

        let parsedSyntax = Parser.parse(source: emittedDefault)
        XCTAssertFalse(parsedSyntax.hasError)
    }
}
