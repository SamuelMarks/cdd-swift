import ArgumentParser
import CDDSwift
import Foundation

/// Documentation for ToDocsJson
struct ToDocsJson: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to_docs_json",
        abstract: "Generate a JSON document containing idiomatic Swift code examples for an OpenAPI specification."
    )

    @Option(name: [.customShort("i"), .customLong("input")], help: "Path or URL to the input OpenAPI specification.")
    /// Documentation for input
    var input: String

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output JSON file. Prints to stdout if not provided.")
    /// Documentation for outputPath
    var outputPath: String?

    @Flag(help: "If provided, omit the imports field in the code object.")
    /// Documentation for noImports
    var noImports: Bool = false

    @Flag(help: "If provided, omit the wrapper_start and wrapper_end fields in the code object.")
    /// Documentation for noWrapping
    var noWrapping: Bool = false

    mutating func run() async throws {
        /// inputURL
        let inputURL: URL
        if input.starts(with: "http://") || input.starts(with: "https://") {
            guard let url = URL(string: input) else {
                fputs("❌ Invalid URL: \(input)\n", stderr)
                throw ExitCode.failure
            }
            inputURL = url
        } else {
            inputURL = URL(fileURLWithPath: input)
        }

        /// data
        let data = try Data(contentsOf: inputURL)

        do {
            /// json
            let json = String(data: data, encoding: .utf8) ?? ""
            /// document
            let document = try OpenAPIParser.parse(json: json)

            /// resultJson
            let resultJson = DocsJsonGenerator.generate(
                from: document,
                includeImports: !noImports,
                includeWrapping: !noWrapping
            )

            if let outputPath = outputPath {
                /// outputURL
                let outputURL = URL(fileURLWithPath: outputPath)
                try resultJson.write(to: outputURL, atomically: true, encoding: .utf8)
            } else {
                print(resultJson)
            }
        } catch {
            fputs("❌ Failed to process OpenAPI Document: \(error)\n", stderr)
            throw error
        }
    }
}
