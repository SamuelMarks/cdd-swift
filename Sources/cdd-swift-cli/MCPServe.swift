import ArgumentParser
import CDDSwift
import Foundation

/// MCP Server command
struct MCPServe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "mcp", abstract: "Start the Model Context Protocol (MCP) server via stdio")

    /// For testing purposes to inject a mock transport
    nonisolated(unsafe) static var mockTransport: MCPTransport?

    mutating func run() async throws {
        let transport = MCPServe.mockTransport ?? MCPStdioTransport()

        var router = DefaultMCPServerRouter()

        // Setup initial MCP capabilities
        let serverInfo = Implementation(name: "cdd-swift", version: "0.0.2")
        let capabilities = ServerCapabilities(
            prompts: .init(listChanged: false),
            resources: .init(listChanged: false, subscribe: false),
            tools: .init(listChanged: false)
        )

        router.requestHandlers["initialize"] = { _ in
            let result = InitializeResult(protocolVersion: "2024-11-05", capabilities: capabilities, serverInfo: serverInfo)
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }

        router.requestHandlers["ping"] = { _ in
            let result = EmptyResult()
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }

        router.requestHandlers["tools/list"] = { _ in
            let tools = [
                Tool(
                    name: "generate_from_openapi",
                    description: "Generate Swift code from an OpenAPI specification",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "input_path": AnyCodable(["type": "string", "description": "Path to the input OpenAPI JSON file"]),
                            "output_dir": AnyCodable(["type": "string", "description": "Path to the output directory"])
                        ],
                        required: ["input_path", "output_dir"]
                    )
                ),
                Tool(
                    name: "to_openapi",
                    description: "Parse a Swift file to extract Codable models and generate OpenAPI JSON",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "input_path": AnyCodable(["type": "string", "description": "Path to the input Swift file"]),
                            "output_path": AnyCodable(["type": "string", "description": "Path to the output JSON file"])
                        ],
                        required: ["input_path", "output_path"]
                    )
                ),
                Tool(
                    name: "to_docs_json",
                    description: "Generate JSON documentation from an OpenAPI JSON file",
                    inputSchema: ToolInputSchema(
                        type: "object",
                        properties: [
                            "input_path": AnyCodable(["type": "string", "description": "Path to the input OpenAPI JSON file"]),
                            "output_path": AnyCodable(["type": "string", "description": "Path to the output JSON documentation file"])
                        ],
                        required: ["input_path", "output_path"]
                    )
                )
            ]
            let result = ListToolsResult(tools: tools)
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }

        router.requestHandlers["tools/call"] = { req in
            guard let paramsAny = req.params?.value as? [String: Any],
                  let name = paramsAny["name"] as? String
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing or invalid tool name")
            }

            if name == "generate_from_openapi" {
                let arguments = paramsAny["arguments"] as? [String: Any] ?? [:]
                guard let inputPath = arguments["input_path"] as? String,
                      let outputDir = arguments["output_dir"] as? String
                else {
                    throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for generate_from_openapi")
                }

                // Execute the actual SDK method/command
                var commandArgs = ["from_openapi", "to_sdk"]
                commandArgs.append(contentsOf: ["--input", inputPath, "-o", outputDir])

                do {
                    await CDDSwiftCLI.main(commandArgs)
                    let textContent = TextContent(text: "Successfully executed generate_from_openapi to \(outputDir)")
                    let result = CallToolResult(content: [AnyCodable(["type": textContent.type, "text": textContent.text])])
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(result)
                    return try JSONDecoder().decode(AnyCodable.self, from: data)
                }
            } else if name == "to_openapi" {
                let arguments = paramsAny["arguments"] as? [String: Any] ?? [:]
                guard let inputPath = arguments["input_path"] as? String,
                      let outputPath = arguments["output_path"] as? String
                else {
                    throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for to_openapi")
                }

                var commandArgs = ["to_openapi"]
                commandArgs.append(contentsOf: ["--input", inputPath, "-o", outputPath])

                do {
                    await CDDSwiftCLI.main(commandArgs)
                    let textContent = TextContent(text: "Successfully executed to_openapi to \(outputPath)")
                    let result = CallToolResult(content: [AnyCodable(["type": textContent.type, "text": textContent.text])])
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(result)
                    return try JSONDecoder().decode(AnyCodable.self, from: data)
                }
            } else if name == "to_docs_json" {
                let arguments = paramsAny["arguments"] as? [String: Any] ?? [:]
                guard let inputPath = arguments["input_path"] as? String,
                      let outputPath = arguments["output_path"] as? String
                else {
                    throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for to_docs_json")
                }

                var commandArgs = ["to_docs_json"]
                commandArgs.append(contentsOf: ["--input", inputPath, "-o", outputPath])

                do {
                    await CDDSwiftCLI.main(commandArgs)
                    let textContent = TextContent(text: "Successfully executed to_docs_json to \(outputPath)")
                    let result = CallToolResult(content: [AnyCodable(["type": textContent.type, "text": textContent.text])])
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(result)
                    return try JSONDecoder().decode(AnyCodable.self, from: data)
                }
            }

            throw JSONRPCErrorDetail(code: .methodNotFound, message: "Tool \(name) not found")
        }

        router.requestHandlers["resources/list"] = { _ in
            let resources = [
                Resource(
                    uri: "cdd-swift://ast",
                    name: "Swift AST Query",
                    description: "Internal AST structures representing Swift code",
                    mimeType: "application/json"
                )
            ]
            let result = ListResourcesResult(resources: resources)
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }

        router.requestHandlers["resources/read"] = { req in
            guard let paramsAny = req.params?.value as? [String: Any],
                  let uri = paramsAny["uri"] as? String
            else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing or invalid resource uri")
            }

            if uri == "cdd-swift://ast" {
                let content = TextResourceContents(
                    uri: uri,
                    mimeType: "application/json",
                    text: "{\"type\": \"AST\", \"description\": \"AST Query Resource is available.\"}"
                )
                let result = ReadResourceResult(contents: [.text(content)])
                let encoder = JSONEncoder()
                let data = try encoder.encode(result)
                return try JSONDecoder().decode(AnyCodable.self, from: data)
            }

            throw JSONRPCErrorDetail(code: .invalidParams, message: "Resource \(uri) not found")
        }

        router.notificationHandlers["notifications/initialized"] = { _ in
            // Client is ready
        }

        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()

        // Wait indefinitely for stdio transport
        if ProcessInfo.processInfo.environment["CDD_TEST_BLOCK"] == "1" || MCPServe.mockTransport == nil {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }
}
