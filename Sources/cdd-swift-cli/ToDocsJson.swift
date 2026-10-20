/// CLI command for generating JSON-formatted API documentation snippets from OpenAPI specifications.
import ArgumentParser
import CDDSwift
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Subcommand that generates JSON documentation with executable Swift code snippets for an OpenAPI specification.
struct ToDocsJson: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to_docs_json",
        abstract: "Generate JSON documentation with code snippets for an OpenAPI specification."
    )

    @Option(name: [.customShort("i"), .customLong("input")], help: "Path or URL to the input OpenAPI specification.")
    /// Filesystem path or HTTP/HTTPS URL to the input OpenAPI specification.
    var input: String

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output JSON file. Prints to stdout if not provided.")
    /// Optional filesystem path where the generated documentation JSON will be written.
    var outputPath: String?

    @Flag(help: "If provided, omit the imports field in the code object.")
    /// When `true`, omits the `imports` field in generated `DocsJsonCode` objects.
    var noImports: Bool = false

    @Flag(help: "If provided, omit the wrapper_start and wrapper_end fields in the code object.")
    /// When `true`, omits the `wrapper_start` and `wrapper_end` fields in generated `DocsJsonCode` objects.
    var noWrapping: Bool = false

    /// Fetches or reads the OpenAPI specification, generates documentation snippets, and writes or prints the JSON output.
    ///
    /// - Throws: `ExitCode.failure` or `CDDError` if loading or parsing the OpenAPI document fails.
    mutating func run() async throws {
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
            let json = String(decoding: data, as: UTF8.self)
            let document = try OpenAPIParser.parse(json: json)

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
