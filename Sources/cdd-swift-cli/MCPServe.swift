/// CLI subcommand starting the Model Context Protocol (MCP) server over standard I/O.
import ArgumentParser
import CDDSwift

/// Thread-safe actor container managing transport dependency injection for `MCPServe`.
public actor MCPServeRuntime {
    /// Shared singleton runtime instance.
    public static let shared = MCPServeRuntime()

    /// Optional custom transport override used when starting `MCPServe`.
    private var transportOverride: MCPTransport?

    /// Initializes the `MCPServeRuntime` actor.
    public init() {}

    /// Sets or clears the custom `MCPTransport` override.
    ///
    /// - Parameter transport: The `MCPTransport` to inject, or `nil` to revert to `MCPStdioTransport`.
    public func setTransport(_ transport: MCPTransport?) {
        transportOverride = transport
    }

    /// Resolves the active `MCPTransport`, returning the injected override or a default `MCPStdioTransport`.
    ///
    /// - Returns: The resolved `MCPTransport` instance.
    public func resolveTransport() -> MCPTransport {
        transportOverride ?? MCPStdioTransport()
    }
}

/// MCP Server command.
struct MCPServe: AsyncParsableCommand {
    /// Command configuration for the `mcp` CLI subcommand.
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the Model Context Protocol (MCP) server via stdio."
    )

    /// Starts the MCP server session using the transport resolved from `MCPServeRuntime.shared`.
    ///
    /// - Throws: An error if the transport or server session fails to start.
    mutating func run() async throws {
        let transport = await MCPServeRuntime.shared.resolveTransport()
        try await run(using: transport)
    }

    /// Starts the MCP server session over the specified `MCPTransport` and registers tool and resource handlers.
    ///
    /// - Parameter transport: The `MCPTransport` over which JSON-RPC messages are exchanged.
    /// - Throws: An error if the transport or server session fails to start.
    func run(using transport: MCPTransport) async throws {
        var router = DefaultMCPServerRouter()
        let serverInfo = Implementation(name: "cdd-swift", version: CDDVersion.current)

        router.requestHandlers["initialize"] = { _ in
            AnyCodable([
                "protocolVersion": .string("2024-11-05"),
                "capabilities": .object([
                    "prompts": .object(["listChanged": .bool(false)]),
                    "resources": .object(["listChanged": .bool(false), "subscribe": .bool(false)]),
                    "tools": .object(["listChanged": .bool(false)])
                ]),
                "serverInfo": .object([
                    "name": .string(serverInfo.name),
                    "version": .string(serverInfo.version)
                ])
            ])
        }
        router.requestHandlers["ping"] = { _ in AnyCodable([String: JSONValue]()) }
        router.requestHandlers["tools/list"] = { _ in Self.buildToolsListResponse() }
        router.requestHandlers["tools/call"] = { req in try await Self.handleToolCall(req) }
        router.requestHandlers["resources/list"] = { _ in Self.buildResourcesListResponse() }
        router.requestHandlers["resources/read"] = { req in try Self.handleResourceRead(req) }
        router.notificationHandlers["notifications/initialized"] = { _ in }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()
    }

    /// Builds the `tools/list` response payload describing all available MCP tools.
    ///
    /// - Returns: An `AnyCodable` dictionary containing the `tools` array.
    private static func buildToolsListResponse() -> AnyCodable {
        let tools: [JSONValue] = [
            .object([
                "name": .string("generate_from_openapi"),
                "description": .string("Generate Swift code from an OpenAPI specification"),
                "inputSchema": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "input_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the input OpenAPI JSON file")
                        ]),
                        "output_dir": .object(["type": .string("string"), "description": .string("Path to the output directory")])
                    ]),
                    "required": .array([.string("input_path"), .string("output_dir")])
                ])
            ]),
            .object([
                "name": .string("to_openapi"),
                "description": .string("Parse a Swift file to extract Codable models and generate OpenAPI JSON"),
                "inputSchema": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "input_path": .object(["type": .string("string"), "description": .string("Path to the input Swift file")]),
                        "output_path": .object(["type": .string("string"), "description": .string("Path to the output JSON file")])
                    ]),
                    "required": .array([.string("input_path"), .string("output_path")])
                ])
            ]),
            .object([
                "name": .string("to_docs_json"),
                "description": .string("Generate JSON documentation from an OpenAPI JSON file"),
                "inputSchema": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "input_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the input OpenAPI JSON file")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the output JSON documentation file")
                        ])
                    ]),
                    "required": .array([.string("input_path"), .string("output_path")])
                ])
            ])
        ]
        return AnyCodable(["tools": .array(tools)])
    }

    /// Executes an MCP `tools/call` request and returns the result payload.
    ///
    /// - Parameter req: The incoming `JSONRPCRequest`.
    /// - Returns: An `AnyCodable` tool result object.
    /// - Throws: `JSONRPCErrorDetail` if parameters are invalid or the tool name is unrecognized.
    private static func handleToolCall(_ req: JSONRPCRequest<AnyCodable>) async throws -> AnyCodable {
        guard let paramsObj = req.params?.objectValue,
              let name = paramsObj["name"]?.stringValue
        else {
            throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing or invalid tool name")
        }

        let arguments = paramsObj["arguments"]?.objectValue ?? [:]

        if name == "generate_from_openapi" {
            guard let inputPath = arguments["input_path"]?.stringValue,
                  let outputDir = arguments["output_dir"]?.stringValue
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for generate_from_openapi")
            }
            await CDDSwiftCLI.main(["from_openapi", "to_sdk", "--input", inputPath, "-o", outputDir])
            let textContent = TextContent(text: "Successfully executed generate_from_openapi to \(outputDir)")
            return AnyCodable(["content": .array([.object(["type": .string(textContent.type), "text": .string(textContent.text)])])])
        } else if name == "to_openapi" {
            guard let inputPath = arguments["input_path"]?.stringValue,
                  let outputPath = arguments["output_path"]?.stringValue
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for to_openapi")
            }
            await CDDSwiftCLI.main(["to_openapi", "--input", inputPath, "-o", outputPath])
            let textContent = TextContent(text: "Successfully executed to_openapi to \(outputPath)")
            return AnyCodable(["content": .array([.object(["type": .string(textContent.type), "text": .string(textContent.text)])])])
        } else if name == "to_docs_json" {
            guard let inputPath = arguments["input_path"]?.stringValue,
                  let outputPath = arguments["output_path"]?.stringValue
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for to_docs_json")
            }
            await CDDSwiftCLI.main(["to_docs_json", "--input", inputPath, "-o", outputPath])
            let textContent = TextContent(text: "Successfully executed to_docs_json to \(outputPath)")
            return AnyCodable(["content": .array([.object(["type": .string(textContent.type), "text": .string(textContent.text)])])])
        }

        throw JSONRPCErrorDetail(code: .methodNotFound, message: "Tool \(name) not found")
    }

    /// Builds the `resources/list` response payload describing all available MCP resources.
    ///
    /// - Returns: An `AnyCodable` dictionary containing the `resources` array.
    private static func buildResourcesListResponse() -> AnyCodable {
        AnyCodable([
            "resources": .array([
                .object([
                    "uri": .string("cdd-swift://ast"),
                    "name": .string("Swift AST Query"),
                    "description": .string("Internal AST structures representing Swift code"),
                    "mimeType": .string("application/json")
                ])
            ])
        ])
    }

    /// Handles an MCP `resources/read` request for a given resource URI.
    ///
    /// - Parameter req: The incoming `JSONRPCRequest`.
    /// - Returns: An `AnyCodable` resource contents payload.
    /// - Throws: `JSONRPCErrorDetail` if the resource URI is missing or unrecognized.
    private static func handleResourceRead(_ req: JSONRPCRequest<AnyCodable>) throws -> AnyCodable {
        guard let paramsObj = req.params?.objectValue,
              let uri = paramsObj["uri"]?.stringValue
        else {
            throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing or invalid resource uri")
        }

        if uri == "cdd-swift://ast" {
            return AnyCodable([
                "contents": .array([
                    .object([
                        "uri": .string(uri),
                        "mimeType": .string("application/json"),
                        "text": .string(#"{"type": "AST", "description": "AST Query Resource is available."}"#)
                    ])
                ])
            ])
        }

        throw JSONRPCErrorDetail(code: .invalidParams, message: "Resource \(uri) not found")
    }
}
