/// Root CLI entrypoint, subcommand routing, and programmatic API for `cdd-swift`.
import ArgumentParser
import CDDSwift

@main
/// Root command-line interface command for converting and synchronizing OpenAPI, Arazzo, and Swift code.
struct CDDSwiftCLI: AsyncParsableCommand {
    /// Expands `CDD_*` environment variables into CLI flags when not already specified on the command line.
    ///
    /// - Parameters:
    ///   - arguments: Raw command-line arguments array.
    ///   - env: Process environment variable dictionary.
    /// - Returns: The combined array of explicit arguments and environment-derived flags.
    static func buildArgs(from arguments: [String], env: [String: String]) -> [String] {
        var args = arguments
        for (key, value) in env where key.hasPrefix("CDD_") {
            if key == "CDD_COMMAND" || key == "CDD_ARGS" {
                continue
            }
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

    /// Default `@main` asynchronous entrypoint reading `CommandLine.arguments` and `ProcessInfo.processInfo.environment`.
    static func main() async {
        await main(arguments: CommandLine.arguments, environment: ProcessInfo.processInfo.environment)
    }

    /// Entrypoint accepting explicit arguments and environment variables, bypassing execution when invoked inside an `xctest` runner.
    ///
    /// - Parameters:
    ///   - arguments: Full process arguments including executable path at index 0.
    ///   - environment: Process environment dictionary.
    static func main(arguments: [String], environment: [String: String]) async {
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil || arguments.first?
            .hasSuffix("xctest") == true {
            return
        }
        await _main(arguments: Array(arguments.dropFirst()), environment: environment)
    }

    /// Merges environment flags with CLI arguments and invokes `ArgumentParser` execution.
    ///
    /// - Parameters:
    ///   - arguments: Subcommand arguments excluding the executable name.
    ///   - environment: Process environment dictionary.
    static func _main(arguments: [String], environment: [String: String]) async {
        let args = buildArgs(from: arguments, env: environment)
        await CDDSwiftCLI.main(args)
    }

    /// Top-level `ArgumentParser` command configuration registering all subcommands.
    static let configuration = CommandConfiguration(
        commandName: "cdd-swift",
        abstract: "A utility to convert between OpenAPI and Swift.",
        version: "0.0.4",
        subcommands: {
            #if os(WASI)
                return [
                    FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self,
                    ToDocsJson.self, MCPServe.self, SyncOpenAPI.self,
                    FromArazzo.self, ToArazzo.self, GenerateArazzo.self, SyncArazzo.self
                ]
            #else
                return [
                    FromOpenAPI.self, GenerateOpenAPI.self, ToOpenAPI.self, MergeSwift.self,
                    ToDocsJson.self, ServeJsonRpc.self, MCPServe.self, SyncOpenAPI.self,
                    FromArazzo.self, ToArazzo.self, GenerateArazzo.self, SyncArazzo.self
                ]
            #endif
        }()
    )
}

/// CLI subcommand that merges generated Swift SDK code from an OpenAPI specification into an existing Swift source file.
struct MergeSwift: AsyncParsableCommand {
    /// Command configuration for `merge_swift`.
    static let configuration = CommandConfiguration(
        commandName: "merge_swift",
        abstract: "Merge generated Swift code from an OpenAPI document into an existing Swift file."
    )

    /// Path to the input OpenAPI JSON file.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input OpenAPI JSON file.")
    var inputPath: String

    /// Path to the existing Swift file to merge into.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the existing Swift file to merge into.")
    var destinationPath: String

    /// Executes the non-destructive AST merge of generated OpenAPI models and routes into `destinationPath`.
    ///
    /// - Throws: `CDDError` if reading, parsing, or writing files fails.
    mutating func run() async throws {
        let data = try WASIFileHelpers.readFile(at: inputPath)

        do {
            let json = String(decoding: data, as: UTF8.self)
            let document = try OpenAPIParser.parse(json: json)
            let generatedCode = OpenAPIToSwiftGenerator.generate(from: document)

            let existingSource = try WASIFileHelpers.readString(at: destinationPath)

            let mergedSource = SwiftCodeMerger.merge(generatedCode: generatedCode, into: existingSource)

            try WASIFileHelpers.writeString(mergedSource, to: destinationPath)
            print("✅ Successfully merged OpenAPI code into \(destinationPath)")
        } catch {
            print("❌ Failed to process: \(error)")
            throw error
        }
    }
}

/// CLI subcommand that parses a Swift source file or directory via `SwiftSyntax` and emits an OpenAPI JSON specification.
struct ToOpenAPI: AsyncParsableCommand {
    /// Command configuration for `to_openapi`.
    static let configuration = CommandConfiguration(
        commandName: "to_openapi",
        abstract: "Parse a Swift file to extract Codable models and generate OpenAPI JSON."
    )

    /// Path to the input Swift file or directory.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Swift file.")
    var inputPath: String

    /// Optional path to the output OpenAPI JSON file; prints to stdout when omitted.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output JSON file. Prints to stdout if not provided.")
    var outputPath: String?

    /// Parses the Swift source at `inputPath` and writes or prints the reconstructed OpenAPI JSON.
    ///
    /// - Throws: `CDDError` if the input file does not exist or AST parsing/encoding fails.
    mutating func run() async throws {
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
                    let content = try WASIFileHelpers.readString(at: file)
                    sourceCode += String(UnicodeScalar(10)) + content
                }
            } else {
                throw CDDError.fileIOError(
                    path: inputPath,
                    operation: "read",
                    errno: 2,
                    message: "Input file or directory not found: \(inputPath)"
                )
            }
        }

        let document = try parser.parseDocument(from: sourceCode)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        let jsonString = String(decoding: data, as: UTF8.self)

        if let outputPath {
            try WASIFileHelpers.writeString(jsonString, to: outputPath)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}

/// CLI subcommand that emits a sample OpenAPI 3.2.0 JSON specification constructed with `OpenAPIDocumentBuilder`.
struct GenerateOpenAPI: AsyncParsableCommand {
    /// Command configuration for `generate_openapi`.
    static let configuration = CommandConfiguration(
        commandName: "generate_openapi",
        abstract: "Generate an example OpenAPI JSON document from Swift builder."
    )

    /// Optional output file path for the generated OpenAPI JSON; prints to stdout when omitted.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output JSON file. Prints to stdout if not provided.")
    var outputPath: String?

    /// Builds and outputs the sample OpenAPI document.
    ///
    /// - Throws: An error if JSON serialization or file writing fails.
    mutating func run() async throws {
        let builder = OpenAPIDocumentBuilder(title: "Sample CDD API", version: "0.0.4")
            .addPath("/users", item: PathItem(
                get: Operation(
                    summary: "Get all users",
                    operationId: "getUsers",
                    responses: ["200": Response(
                        description: "A list of users",
                        content: ["application/json": MediaType(schema: Schema(
                            type: "array",
                            items: SchemaItem(ref: "#/components/schemas/User")
                        ))]
                    )]
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

        let jsonString = try builder.serialize()

        if let outputPath {
            try WASIFileHelpers.writeString(jsonString, to: outputPath)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}

/// Programmatic facade for invoking `cdd-swift` CLI subcommands from Swift code or WASI exports.
public enum CDDCLI {
    /// Programmatically invokes the `from_openapi` subcommand group.
    ///
    /// - Parameters:
    ///   - subcommand: Optional target subcommand (`to_sdk`, `to_sdk_cli`, `to_server`).
    ///   - args: CLI arguments passed to the subcommand.
    /// - Throws: An error if command execution fails.
    public static func generateFromOpenApi(subcommand: String? = nil, _ args: [String]) async throws {
        var commandArgs = ["from_openapi"]
        if let subcommand {
            commandArgs.append(subcommand)
        }
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `to_openapi` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `to_openapi`.
    /// - Throws: An error if command execution fails.
    public static func generateToOpenApi(_ args: [String]) async throws {
        var commandArgs = ["to_openapi"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `to_docs_json` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `to_docs_json`.
    /// - Throws: An error if command execution fails.
    public static func generateDocsJson(_ args: [String]) async throws {
        var commandArgs = ["to_docs_json"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `mcp` server subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `mcp`.
    /// - Throws: An error if command execution fails.
    public static func mcp(_ args: [String]) async throws {
        var commandArgs = ["mcp"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `sync` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `sync`.
    /// - Throws: An error if command execution fails.
    public static func syncOpenApi(_ args: [String]) async throws {
        var commandArgs = ["sync"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `from_arazzo` subcommand group.
    ///
    /// - Parameters:
    ///   - subcommand: Optional target subcommand (`to_sdk`, `to_sdk_cli`, `to_test`, `to_server`).
    ///   - args: CLI arguments passed to the subcommand.
    /// - Throws: An error if command execution fails.
    public static func generateFromArazzo(subcommand: String? = nil, _ args: [String]) async throws {
        var commandArgs = ["from_arazzo"]
        if let subcommand {
            commandArgs.append(subcommand)
        }
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `to_arazzo` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `to_arazzo`.
    /// - Throws: An error if command execution fails.
    public static func generateToArazzo(_ args: [String]) async throws {
        var commandArgs = ["to_arazzo"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `generate_arazzo` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `generate_arazzo`.
    /// - Throws: An error if command execution fails.
    public static func generateArazzo(_ args: [String]) async throws {
        var commandArgs = ["generate_arazzo"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    /// Programmatically invokes the `sync_arazzo` subcommand.
    ///
    /// - Parameter args: CLI arguments passed to `sync_arazzo`.
    /// - Throws: An error if command execution fails.
    public static func syncArazzo(_ args: [String]) async throws {
        var commandArgs = ["sync_arazzo"]
        commandArgs.append(contentsOf: args)
        await CDDSwiftCLI.main(commandArgs)
    }

    #if !os(WASI)
        /// Programmatically invokes the `serve_json_rpc` subcommand on non-WASI platforms.
        ///
        /// - Parameter args: CLI arguments passed to `serve_json_rpc`.
        /// - Throws: An error if command execution fails.
        public static func serveJsonRpc(_ args: [String]) async throws {
            var commandArgs = ["serve_json_rpc"]
            commandArgs.append(contentsOf: args)
            await CDDSwiftCLI.main(commandArgs)
        }
    #endif
}

/// Bi-directional synchronization of OpenAPI models and Swift definitions.
struct SyncOpenAPI: AsyncParsableCommand {
    /// Command configuration for `sync`.
    static let configuration = CommandConfiguration(commandName: "sync", abstract: "Synchronize an OpenAPI specification with source code.")

    /// Designates the single source of truth (`class`, `struct`, or `function`).
    @Option(
        name: .customLong("truth"),
        help: "Designate the single source of truth ('class', 'struct', 'function'). Currently defaults to 'class'."
    )
    var truth: String?

    /// Path to the input Swift file containing the source of truth.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Swift file containing the source of truth.")
    var inputPath: String

    /// Path to the output OpenAPI JSON file to synchronize.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output OpenAPI JSON file to synchronize.")
    var outputPath: String

    /// Synchronizes Swift AST models and routes into the OpenAPI document at `outputPath`.
    ///
    /// - Throws: `CDDError` if reading, parsing, or writing files fails.
    mutating func run() async throws {
        let selectedTruth = truth ?? "class"
        let parser = SwiftASTParser()

        var sourceCode = ""
        if WASIFileHelpers.fileExists(at: inputPath) {
            sourceCode = try WASIFileHelpers.readString(at: inputPath)
        } else {
            let parentDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent().path
            if WASIFileHelpers.fileExists(at: parentDir) {
                let files = try WASIFileHelpers.listDirectory(at: parentDir)
                for file in files where file.hasSuffix(".swift") {
                    let content = try WASIFileHelpers.readString(at: file)
                    sourceCode += String(UnicodeScalar(10)) + content
                }
            } else {
                throw CDDError.fileIOError(
                    path: inputPath,
                    operation: "read",
                    errno: 2,
                    message: "Input file or directory not found: \(inputPath)"
                )
            }
        }

        let document = try parser.parseDocument(from: sourceCode)

        // Read existing spec if it exists to preserve non-code synced data
        var existingDocument: OpenAPIDocument?
        if WASIFileHelpers.fileExists(at: outputPath) {
            let existingJSON = try WASIFileHelpers.readString(at: outputPath)
            existingDocument = try OpenAPIParser.parse(json: existingJSON)
        }

        var finalDocument = document
        if let existing = existingDocument {
            finalDocument = Self.mergeDocuments(parsed: document, existing: existing)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(finalDocument)
        let jsonString = String(decoding: data, as: UTF8.self)

        try WASIFileHelpers.writeString(jsonString, to: outputPath)
        print("✅ Successfully synchronized \(selectedTruth) truth to \(outputPath)")
    }

    /// Merges a parsed `OpenAPIDocument` into an existing `OpenAPIDocument`, preserving existing metadata.
    ///
    /// - Parameters:
    ///   - parsed: The newly parsed `OpenAPIDocument` from Swift source code.
    ///   - existing: The pre-existing `OpenAPIDocument` loaded from disk.
    /// - Returns: The merged `OpenAPIDocument`.
    private static func mergeDocuments(parsed: OpenAPIDocument, existing: OpenAPIDocument) -> OpenAPIDocument {
        var mergedPaths = existing.paths ?? [:]
        if let parsedPaths = parsed.paths {
            for (k, v) in parsedPaths {
                mergedPaths[k] = v
            }
        }

        let baseComponents = existing.components ?? Components()
        let finalComponents: Components
        if let parsedComponents = parsed.components {
            var schemas = baseComponents.schemas ?? [:]
            if let parsedSchemas = parsedComponents.schemas {
                for (k, v) in parsedSchemas {
                    schemas[k] = v
                }
            }
            finalComponents = Components(
                schemas: schemas,
                responses: baseComponents.responses,
                parameters: baseComponents.parameters,
                examples: baseComponents.examples,
                requestBodies: baseComponents.requestBodies,
                headers: baseComponents.headers,
                securitySchemes: baseComponents.securitySchemes,
                links: baseComponents.links,
                callbacks: baseComponents.callbacks,
                pathItems: baseComponents.pathItems
            )
        } else {
            finalComponents = baseComponents
        }

        return OpenAPIDocument(
            openapi: existing.openapi,
            swagger: existing.swagger,
            selfRef: existing.selfRef,
            info: existing.info,
            jsonSchemaDialect: existing.jsonSchemaDialect,
            servers: existing.servers,
            paths: mergedPaths,
            webhooks: existing.webhooks,
            components: finalComponents,
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
