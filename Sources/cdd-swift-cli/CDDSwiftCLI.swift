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

        // Map env vars like CDD_PORT to --port
        for (key, value) in env where key.hasPrefix("CDD_") {
            if key == "CDD_COMMAND" || key == "CDD_ARGS" { continue }
            /// argName
            let argName = key.dropFirst("CDD_".count).lowercased().replacingOccurrences(of: "_", with: "-")
            /// flag
            let flag = "--\(argName)"
            if !args.contains(flag), !args.contains(where: { $0.starts(with: "\(flag)=") }) {
                if value.lowercased() == "true" {
                    args.append(flag)
                } else if value.lowercased() != "false" {
                    args.append(flag)
                    args.append(value)
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
                return [FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self, ToDocsJson.self, ServeJsonRpc.self]
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
        /// Documentation for data
        let data = try WASIFileHelpers.readFile(at: inputPath)

        do {
            /// Documentation for json
            let json = String(data: data, encoding: .utf8) ?? ""
            /// Documentation for document
            let document = try OpenAPIParser.parse(json: json)
            /// Documentation for generatedCode
            let generatedCode = OpenAPIToSwiftGenerator.generate(from: document)

            /// Documentation for existingSource
            let existingSource = try WASIFileHelpers.readString(at: destinationPath)

            /// Documentation for mergedSource
            let mergedSource = SwiftCodeMerger.merge(generatedCode: generatedCode, into: existingSource)

            try WASIFileHelpers.writeString(mergedSource, to: destinationPath)
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

    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Swift file.")
    /// Documentation for inputPath
    var inputPath: String

    @Option(name: .shortAndLong, help: "Path to the output JSON file. Prints to stdout if not provided.")
    /// Documentation for outputPath
    var outputPath: String?

    mutating func run() async throws {
        /// Documentation for parser
        let parser = SwiftASTParser()

        var sourceCode = ""
        if WASIFileHelpers.fileExists(at: inputPath) {
            sourceCode = try WASIFileHelpers.readString(at: inputPath)
        } else {
            // Fallback: If the exact file doesn't exist, check its directory
            let parentDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent().path
            if WASIFileHelpers.fileExists(at: parentDir) {
                let files = try WASIFileHelpers.listDirectory(at: parentDir)
                for file in files where file.hasSuffix(".swift") {
                    if let content = try? WASIFileHelpers.readString(at: file) {
                        sourceCode += "\n" + content
                    }
                }
            } else {
                throw NSError(domain: "ToOpenAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input file or directory not found: \(inputPath)"])
            }
        }

        /// Documentation for document
        let document = try parser.parseDocument(from: sourceCode)

        /// Documentation for encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        /// Documentation for data
        let data = try encoder.encode(document)
        /// Documentation for jsonString
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"

        if let outputPath = outputPath {
            try WASIFileHelpers.writeString(jsonString, to: outputPath)
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
                    "name": Schema(type: "string")
                ],
                required: ["id", "name"]
            ))

        /// Documentation for jsonString
        let jsonString = try builder.serialize()

        if let outputPath = outputPath {
            try WASIFileHelpers.writeString(jsonString, to: outputPath)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}

public enum CDDCLI {
    public static func generateFromOpenApi(_ args: [String]) async throws {
        var commandArgs = ["from_openapi"]
        commandArgs.append(contentsOf: args)
        try await CDDSwiftCLI.main(commandArgs)
    }

    public static func generateToOpenApi(_ args: [String]) async throws {
        var commandArgs = ["to_openapi"]
        commandArgs.append(contentsOf: args)
        try await CDDSwiftCLI.main(commandArgs)
    }

    public static func generateDocsJson(_ args: [String]) async throws {
        var commandArgs = ["to_docs_json"]
        commandArgs.append(contentsOf: args)
        try await CDDSwiftCLI.main(commandArgs)
    }

    #if !os(WASI)
        public static func serveJsonRpc(_ args: [String]) async throws {
            var commandArgs = ["serve_json_rpc"]
            commandArgs.append(contentsOf: args)
            try await CDDSwiftCLI.main(commandArgs)
        }
    #endif
}
