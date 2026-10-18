import ArgumentParser
import CDDSwift
import Foundation

/// CLI command to bidirectionally synchronize Swift workflow classes and Arazzo 1.1.0 JSON definitions.
struct SyncArazzo: AsyncParsableCommand {
    /// The CommandConfiguration for `sync_arazzo`.
    static let configuration = CommandConfiguration(
        commandName: "sync_arazzo",
        abstract: "Bidirectionally reconcile Swift workflow classes and Arazzo 1.1.0 JSON definitions."
    )

    /// Path to the Swift workflow source file.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the Swift workflow source file.")
    var inputPath: String

    /// Path to the Arazzo 1.1.0 JSON specification file.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the Arazzo JSON file to synchronize.")
    var outputPath: String

    /// Designates the source of truth (`swift` or `arazzo`). Defaults to `"swift"`.
    @Option(name: .customLong("truth"), help: "Designate the source of truth ('swift' or 'arazzo').")
    var truth: String = "swift"

    /// Executes the `sync_arazzo` command.
    mutating func run() async throws {
        if truth.lowercased() == "arazzo" {
            let json = try WASIFileHelpers.readString(at: outputPath)
            let spec = try ArazzoEmitter.parse(json: json)
            let generatedSwift = ArazzoSdkEmitter.emitWorkflowClient(from: spec)
            if WASIFileHelpers.fileExists(at: inputPath) {
                let existingSwift = try WASIFileHelpers.readString(at: inputPath)
                let merged = ArazzoCodeMerger.merge(generatedCode: generatedSwift, into: existingSwift)
                try WASIFileHelpers.writeString(merged, to: inputPath)
            } else {
                try WASIFileHelpers.writeString(generatedSwift, to: inputPath)
            }
            print("✅ Synchronized Arazzo truth into Swift file \(inputPath)")
        } else {
            let swiftSource = try WASIFileHelpers.readString(at: inputPath)
            let parsedSpec = try SwiftASTArazzoParser().parseSpecification(from: swiftSource)
            var finalSpec = parsedSpec

            if WASIFileHelpers.fileExists(at: outputPath),
               let existingJson = try? WASIFileHelpers.readString(at: outputPath),
               let existingSpec = try? ArazzoEmitter.parse(json: existingJson)
            {
                var workflowMap: [String: ArazzoWorkflow] = [:]
                var orderedIds: [String] = []
                for wf in existingSpec.workflows {
                    workflowMap[wf.workflowId] = wf
                    orderedIds.append(wf.workflowId)
                }
                for wf in parsedSpec.workflows {
                    if workflowMap[wf.workflowId] == nil {
                        orderedIds.append(wf.workflowId)
                    }
                    workflowMap[wf.workflowId] = wf
                }
                let mergedWorkflows = orderedIds.compactMap { workflowMap[$0] }
                finalSpec = ArazzoSpecification(
                    arazzo: existingSpec.arazzo,
                    selfRef: existingSpec.selfRef,
                    info: existingSpec.info,
                    sourceDescriptions: existingSpec.sourceDescriptions,
                    workflows: mergedWorkflows,
                    components: existingSpec.components
                )
            }

            let serialized = try ArazzoEmitter.emitJSON(from: finalSpec)
            try WASIFileHelpers.writeString(serialized, to: outputPath)
            print("✅ Synchronized Swift workflow truth into \(outputPath)")
        }
    }
}
