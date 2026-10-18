import ArgumentParser
import CDDSwift
import Foundation

/// CLI command to parse Swift workflow source code via AST and output an Arazzo 1.1.0 specification.
struct ToArazzo: AsyncParsableCommand {
    /// The CommandConfiguration for `to_arazzo`.
    static let configuration = CommandConfiguration(
        commandName: "to_arazzo",
        abstract: "Parse a Swift file to extract workflow orchestrators and generate Arazzo 1.1.0 JSON or YAML."
    )

    /// Path to the input Swift workflow source file.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Swift file.")
    var inputPath: String

    /// Path to the output Arazzo JSON or YAML file. Prints to stdout if omitted.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output Arazzo file. Prints to stdout if not provided.")
    var outputPath: String?

    /// Output serialization format (`json` or `yaml`). Defaults to `"json"`.
    @Option(name: .customLong("format"), help: "Output serialization format: json or yaml.")
    var format: String = "json"

    /// Executes the `to_arazzo` command.
    mutating func run() async throws {
        let sourceCode = try WASIFileHelpers.readString(at: inputPath)
        let parser = SwiftASTArazzoParser()
        let specification = try parser.parseSpecification(from: sourceCode)

        let serialized: String
        if format.lowercased() == "yaml" {
            serialized = ArazzoEmitter.emitYAML(from: specification)
        } else {
            serialized = try ArazzoEmitter.emitJSON(from: specification)
        }

        if let outputPath = outputPath {
            try WASIFileHelpers.writeString(serialized, to: outputPath)
            print("✅ Arazzo specification successfully written to \(outputPath)")
        } else {
            print(serialized)
        }
    }
}
