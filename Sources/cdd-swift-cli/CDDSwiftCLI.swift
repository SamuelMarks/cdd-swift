import ArgumentParser
import CDDSwift
import Foundation

@main
/// Documentation for CDDSwiftCLI
struct CDDSwiftCLI: AsyncParsableCommand {
    static func buildArgs(from arguments: [String], env: [String: String]) -> [String] {
        var args = arguments
        for (key, value) in env where key.hasPrefix("CDD_") {
            if key == "CDD_COMMAND" || key == "CDD_ARGS" { continue }
            let argName = key.dropFirst("CDD_".count).lowercased().replacingOccurrences(of: "_", with: "-")
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
        return args
    }

    static func main() async {
        let args = buildArgs(from: Array(CommandLine.arguments.dropFirst()), env: ProcessInfo.processInfo.environment)
        await CDDSwiftCLI.main(args)
    }

    static let configuration = CommandConfiguration(
        commandName: "cdd-swift",
        abstract: "A utility to convert between OpenAPI and Swift.",
        version: "0.0.3",
        subcommands: {
            #if os(WASI)
                return [FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self, ToDocsJson.self, MCPServe.self, SyncOpenAPI.self]
            #else
                return [FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self, ToDocsJson.self, ServeJsonRpc.self, MCPServe.self, SyncOpenAPI.self]
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
        let jsonString = String(decoding: data, as: UTF8.self)

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
        let builder = OpenAPIDocumentBuilder(title: "Sample CDD API", version: "0.0.3")
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

/// Documentation for CDDCLI
public enum CDDCLI {
    public static func generateFromOpenApi(_ args: [String]) async throws {
        var commandArgs = ["from_openapi"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    public static func generateToOpenApi(_ args: [String]) async throws {
        var commandArgs = ["to_openapi"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    public static func generateDocsJson(_ args: [String]) async throws {
        var commandArgs = ["to_docs_json"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    public static func syncOpenApi(_ args: [String]) async throws {
        var commandArgs = ["sync"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    #if !os(WASI)
        public static func serveJsonRpc(_ args: [String]) async throws {
            var commandArgs = ["serve_json_rpc"]
            commandArgs.append(contentsOf: args)
            await CDDSwiftCLI.main(commandArgs)
        }
    #endif
}

/// Bi-directional synchronization of OpenAPI models and Swift definitions.
struct SyncOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync", abstract: "Bi-directional synchronization of OpenAPI models and Swift definitions.")

    @Option(name: .customLong("truth"), help: "Designate the single source of truth ('class', 'sqlalchemy', 'function'). Currently defaults to 'class'.")
    var truth: String = "class"

    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Swift file containing the source of truth.")
    var inputPath: String

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output OpenAPI JSON file to synchronize.")
    var outputPath: String

    mutating func run() async throws {
        let parser = SwiftASTParser()

        var sourceCode = ""
        if WASIFileHelpers.fileExists(at: inputPath) {
            sourceCode = try WASIFileHelpers.readString(at: inputPath)
        } else {
            let parentDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent().path
            if WASIFileHelpers.fileExists(at: parentDir) {
                let files = try WASIFileHelpers.listDirectory(at: parentDir)
                for file in files where file.hasSuffix(".swift") {
                    if let content = try? WASIFileHelpers.readString(at: file) {
                        sourceCode += "\n" + content
                    }
                }
            } else {
                throw NSError(domain: "SyncOpenAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input file or directory not found: \(inputPath)"])
            }
        }

        let document = try parser.parseDocument(from: sourceCode)

        // Read existing spec if it exists to preserve non-code synced data
        var existingDocument: OpenAPIDocument? = nil
        if WASIFileHelpers.fileExists(at: outputPath) {
            let existingJSON = try WASIFileHelpers.readString(at: outputPath)
            existingDocument = try? OpenAPIParser.parse(json: existingJSON)
        }

        var finalDocument = document
        if let existing = existingDocument {
            // Basic merge keeping existing paths if code doesn't redefine them
            var mergedPaths = existing.paths ?? [:]
            if let parsedPaths = document.paths {
                for (k, v) in parsedPaths {
                    mergedPaths[k] = v
                }
            }

            var mergedComponents = existing.components ?? Components()
            if let parsedComponents = document.components {
                var schemas = mergedComponents.schemas ?? [:]
                if let parsedSchemas = parsedComponents.schemas {
                    for (k, v) in parsedSchemas {
                        schemas[k] = v
                    }
                }
                let newComponents = Components(
                    schemas: schemas,
                    responses: mergedComponents.responses,
                    parameters: mergedComponents.parameters,
                    examples: mergedComponents.examples,
                    requestBodies: mergedComponents.requestBodies,
                    headers: mergedComponents.headers,
                    securitySchemes: mergedComponents.securitySchemes,
                    links: mergedComponents.links,
                    callbacks: mergedComponents.callbacks,
                    pathItems: mergedComponents.pathItems
                )

                finalDocument = OpenAPIDocument(
                    openapi: existing.openapi,
                    swagger: existing.swagger,
                    selfRef: existing.selfRef,
                    info: existing.info,
                    jsonSchemaDialect: existing.jsonSchemaDialect,
                    servers: existing.servers,
                    paths: mergedPaths,
                    webhooks: existing.webhooks,
                    components: newComponents,
                    security: existing.security,
                    tags: existing.tags,
                    externalDocs: existing.externalDocs,
                    definitions: existing.definitions,
                    parameters: existing.parameters,
                    responses: existing.responses,
                    securityDefinitions: existing.securityDefinitions
                )
            } else {
                finalDocument = OpenAPIDocument(
                    openapi: existing.openapi,
                    swagger: existing.swagger,
                    selfRef: existing.selfRef,
                    info: existing.info,
                    jsonSchemaDialect: existing.jsonSchemaDialect,
                    servers: existing.servers,
                    paths: mergedPaths,
                    webhooks: existing.webhooks,
                    components: mergedComponents,
                    security: existing.security,
                    tags: existing.tags,
                    externalDocs: existing.externalDocs,
                    definitions: existing.definitions,
                    parameters: existing.parameters,
                    responses: existing.responses,
                    securityDefinitions: existing.securityDefinitions
                )
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(finalDocument)
        let jsonString = String(decoding: data, as: UTF8.self)

        try WASIFileHelpers.writeString(jsonString, to: outputPath)
        print("✅ Successfully synchronized \(truth) truth to \(outputPath)")
    }
}
