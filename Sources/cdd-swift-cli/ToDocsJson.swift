import ArgumentParser
import Foundation
import CDDSwift

struct ToDocsJson: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to_docs_json",
        abstract: "Generate a JSON document containing idiomatic Swift code examples for an OpenAPI specification."
    )
    
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path or URL to the input OpenAPI specification.")
    var input: String
    
    @Flag(help: "If provided, omit the imports field in the code object.")
    var noImports: Bool = false
    
    @Flag(help: "If provided, omit the wrapper_start and wrapper_end fields in the code object.")
    var noWrapping: Bool = false
    
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
        
        let data = try Data(contentsOf: inputURL)
        
        do {
            let json = String(data: data, encoding: .utf8) ?? ""
            let document = try OpenAPIParser.parse(json: json)
            
            let resultJson = DocsJsonGenerator.generate(
                from: document,
                includeImports: !noImports,
                includeWrapping: !noWrapping
            )
            
            print(resultJson)
        } catch {
            print("❌ Failed to process OpenAPI Document: \(error)")
            throw error
        }
    }
}
