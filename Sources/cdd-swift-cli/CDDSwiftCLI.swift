import ArgumentParser
import CDDSwift
import Foundation

@main
/// Documentation for CDDSwiftCLI
struct CDDSwiftCLI: AsyncParsableCommand {

    static func main() async {
        /// args
        var args = Array(CommandLine.arguments.dropFirst())
        /// env
        let env = ProcessInfo.processInfo.environment
        
        // Map env vars like CDD_SWIFT_PORT to --port
        for (key, value) in env {
            if key.hasPrefix("CDD_SWIFT_") {
                /// argName
                let argName = key.dropFirst("CDD_SWIFT_".count).lowercased().replacingOccurrences(of: "_", with: "-")
                /// flag
                let flag = "--\(argName)"
                if !args.contains(flag) && !args.contains(where: { $0.starts(with: "\(flag)=") }) {
                    if value.lowercased() == "true" {
                        args.append(flag)
                    } else if value.lowercased() != "false" {
                        args.append(flag)
                        args.append(value)
                    }
                }
            }
        }
        
        await CDDSwiftCLI.main(args)
    }

    static let configuration = CommandConfiguration(
        commandName: "cdd-swift",
        abstract: "A utility to convert between OpenAPI and Swift.",
        version: "0.0.1",
        subcommands: {
        #if os(WASI)
        return [FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self, ToDocsJson.self]
        #else
        return [FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self, ToDocsJson.self, ServerJsonRpc.self]
        #endif
    }()
    )
}

/// Documentation for MergeSwift
struct MergeSwift: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Merge generated Swift code from an OpenAPI document into an existing Swift file.")

    @Argument(help: "Path to the input OpenAPI JSON file.")
    /// Documentation for inputPath
    var inputPath: String

    @Argument(help: "Path to the existing Swift file to merge into.")
    /// Documentation for destinationPath
    var destinationPath: String

    mutating func run() async throws {
        /// Documentation for inputURL
        let inputURL = URL(fileURLWithPath: inputPath)
        /// Documentation for data
        let data = try Data(contentsOf: inputURL)

        do {
            /// Documentation for json
            let json = String(data: data, encoding: .utf8) ?? ""
            /// Documentation for document
            let document = try OpenAPIParser.parse(json: json)
            /// Documentation for generatedCode
            let generatedCode = OpenAPIToSwiftGenerator.generate(from: document)

            /// Documentation for destURL
            let destURL = URL(fileURLWithPath: destinationPath)
            /// Documentation for existingSource
            let existingSource = try String(contentsOf: destURL, encoding: .utf8)

            /// Documentation for mergedSource
            let mergedSource = SwiftCodeMerger.merge(generatedCode: generatedCode, into: existingSource)

            try mergedSource.write(to: destURL, atomically: true, encoding: .utf8)
            print("✅ Successfully merged OpenAPI code into \(destinationPath)")
        } catch {
            print("❌ Failed to process: \(error)")
            throw error
        }
    }
}

/// Documentation for ToOpenAPI
struct ToOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_openapi", abstract: "Parse a Swift file to extract Codable models and generate OpenAPI JSON.")

    @Option(name: [.customShort("f"), .customLong("file")], help: "Path to the input Swift file.")
    /// Documentation for inputPath
    var inputPath: String

    @Option(name: .shortAndLong, help: "Path to the output JSON file. Prints to stdout if not provided.")
    /// Documentation for outputPath
    var outputPath: String?

    mutating func run() async throws {
        /// Documentation for inputURL
        let inputURL = URL(fileURLWithPath: inputPath)
        /// Documentation for sourceCode
        let sourceCode = try String(contentsOf: inputURL, encoding: .utf8)

        /// Documentation for parser
        let parser = SwiftASTParser()
        /// Documentation for schemas
        let schemas = try parser.parseModels(from: sourceCode)

        /// Documentation for builder
        let builder = OpenAPIDocumentBuilder(title: "Parsed API", version: "0.0.1")
        for (name, schema) in schemas {
            _ = builder.addSchema(name, schema: schema)
        }

        /// Documentation for jsonString
        let jsonString = try builder.serialize()

        if let outputPath = outputPath {
            /// Documentation for outputURL
            let outputURL = URL(fileURLWithPath: outputPath)
            try jsonString.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}

/// Documentation for FromOpenAPI

/// Documentation for GenerateOpenAPI
struct GenerateOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate an example OpenAPI JSON document from Swift builder.")

    @Option(name: .shortAndLong, help: "Path to the output JSON file. Prints to stdout if not provided.")
    /// Documentation for outputPath
    var outputPath: String?

    mutating func run() async throws {
        /// Documentation for builder
        let builder = OpenAPIDocumentBuilder(title: "Sample CDD API", version: "0.0.1")
            .addPath("/users", item: PathItem(
                get: Operation(
                    summary: "Get all users",
                    operationId: "getUsers",
                    responses: ["200": Response(description: "A list of users", content: ["application/json": MediaType(schema: Schema(type: "array", items: SchemaItem(ref: "#/components/schemas/User")))])]
                )
            ))
            .addSchema("User", schema: Schema(
                type: "object",
                properties: [
                    "id": Schema(type: "string"),
                    "name": Schema(type: "string"),
                ],
                required: ["id", "name"]
            ))

        /// Documentation for jsonString
        let jsonString = try builder.serialize()

        if let outputPath = outputPath {
            /// Documentation for outputURL
            let outputURL = URL(fileURLWithPath: outputPath)
            try jsonString.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}
