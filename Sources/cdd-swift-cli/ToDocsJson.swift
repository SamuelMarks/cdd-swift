import ArgumentParser
import CDDSwift
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

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
                print("❌ Invalid URL: \(input)")
                throw ExitCode.failure
            }
            inputURL = url
        } else {
            inputURL = URL(fileURLWithPath: input)
        }

        /// data
        let data: Data
        if inputURL.scheme == "http" || inputURL.scheme == "https" {
            #if os(WASI)
                print("❌ HTTP/HTTPS is not supported in WASI")
                throw ExitCode.failure
            #else
                let (fetchedData, _) = try await URLSession.shared.data(from: inputURL)
                data = fetchedData
            #endif
        } else {
            data = try WASIFileHelpers.readFile(at: inputURL.path)
        }

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
                try WASIFileHelpers.writeString(resultJson, to: outputPath)
            } else {
                print(resultJson)
            }
        } catch {
            print("❌ Failed to process OpenAPI Document: \(error)")
            throw error
        }
    }
}
