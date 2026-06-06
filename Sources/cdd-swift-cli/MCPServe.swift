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
        let serverInfo = Implementation(name: "cdd-swift", version: "0.0.1")
        let capabilities = ServerCapabilities(
            prompts: .init(listChanged: false),
            resources: .init(listChanged: false, subscribe: false),
            tools: .init(listChanged: false)
        )
        
        router.requestHandlers["initialize"] = { req in
            let result = InitializeResult(protocolVersion: "2024-11-05", capabilities: capabilities, serverInfo: serverInfo)
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            let anyCodable = try JSONDecoder().decode(AnyCodable.self, from: data)
            return anyCodable
        }
        
        router.requestHandlers["ping"] = { req in
            let result = EmptyResult()
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            let anyCodable = try JSONDecoder().decode(AnyCodable.self, from: data)
            return anyCodable
        }

        router.requestHandlers["tools/list"] = { req in
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
                )
            ]
            let result = ListToolsResult(tools: tools)
            let encoder = JSONEncoder()
            let data = try encoder.encode(result)
            return try JSONDecoder().decode(AnyCodable.self, from: data)
        }

        router.requestHandlers["tools/call"] = { req in
            guard let paramsAny = req.params?.value as? [String: Any],
                  let name = paramsAny["name"] as? String else {
                throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing or invalid tool name")
            }
            
            if name == "generate_from_openapi" {
                let arguments = paramsAny["arguments"] as? [String: Any] ?? [:]
                guard let inputPath = arguments["input_path"] as? String,
                      let outputDir = arguments["output_dir"] as? String else {
                    throw JSONRPCErrorDetail(code: .invalidParams, message: "Missing required arguments for generate_from_openapi")
                }
                
                // Execute the actual SDK method/command
                var commandArgs = ["from_openapi"]
                commandArgs.append(contentsOf: ["--input-path", inputPath, "--output-dir", outputDir])
                
                do {
                    await CDDSwiftCLI.main(commandArgs)
                    let textContent = TextContent(text: "Successfully executed generate_from_openapi to \(outputDir)")
                    let result = CallToolResult(content: [AnyCodable(["type": textContent.type, "text": textContent.text])])
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(result)
                    return try JSONDecoder().decode(AnyCodable.self, from: data)
                }
            }
            
            throw JSONRPCErrorDetail(code: .methodNotFound, message: "Tool \(name) not found")
        }
        
        router.notificationHandlers["notifications/initialized"] = { notif in
            // Client is ready
        }
        
        let session = MCPServerSession(transport: transport, router: router)
        try await session.start()
        
        // Wait indefinitely for stdio transport
        if MCPServe.mockTransport == nil {
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
