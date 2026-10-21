/// CLI command for emitting an example Arazzo 1.1.0 workflow specification document.
import ArgumentParser
import CDDSwift
import Foundation

/// CLI command to emit an example/template Arazzo 1.1.0 workflow specification document.
struct GenerateArazzo: AsyncParsableCommand {
    /// The CommandConfiguration for `generate_arazzo`.
    static let configuration = CommandConfiguration(
        commandName: "generate_arazzo",
        abstract: "Generate an example Arazzo 1.1.0 workflow specification document."
    )

    /// Path to the output JSON file. Prints to stdout if omitted.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output JSON file. Prints to stdout if not provided.")
    var outputPath: String?

    /// Executes the `generate_arazzo` command.
    ///
    /// - Throws: `CDDError` if serializing or writing the output file fails.
    mutating func run() async throws {
        let builder = ArazzoDocumentBuilder(
            title: "Sample CDD Arazzo Workflows",
            version: "1.0.0",
            summary: "Example multi-step API workflow specification"
        )
        .addSourceDescription(name: "petstoreApi", url: "./openapi.json", type: .openapi)
        .addWorkflow(
            ArazzoWorkflow(
                workflowId: "createAndFetchUser",
                summary: "Creates a new user and fetches their profile",
                inputs: Schema(
                    type: "object",
                    properties: ["username": Schema(type: "string")],
                    required: ["username"]
                ),
                steps: [
                    ArazzoStep(
                        stepId: "createUserStep",
                        operationId: "createUser",
                        successCriteria: [ArazzoCriterion(context: "$statusCode", condition: "== 201")],
                        outputs: ["userId": AnyCodable("$response.body#/id")]
                    ),
                    ArazzoStep(
                        stepId: "getUserStep",
                        operationId: "getUserById",
                        parameters: [ArazzoParameter(name: "id", in: .path, value: AnyCodable("$steps.createUserStep.outputs.userId"))],
                        successCriteria: [ArazzoCriterion(context: "$statusCode", condition: "== 200")]
                    )
                ],
                outputs: ["createdUserId": AnyCodable("$steps.createUserStep.outputs.userId")]
            )
        )

        let jsonString = try builder.serialize()

        if let outputPath = outputPath {
            try WASIFileHelpers.writeString(jsonString, to: outputPath)
            print("✅ Arazzo JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}
