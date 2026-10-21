/// Swift ArgumentParser CLI SDK emitter for OpenAPI documents.
import Foundation

/// Emits Swift code for a CLI SDK.
///
/// - Parameter document: The `OpenAPIDocument` describing the API endpoints and metadata.
/// - Returns: Generated Swift `ArgumentParser` CLI source code.
public func emitSDKCLI(document: OpenAPIDocument) -> String {
    var output = emitCLIRootCommand(for: document)
    let defaultServerURL = document.servers?.first?.url ?? "http://localhost:8080"

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (httpMethod, op) in item.operationsByMethod {
                if let opId = op.operationId {
                    output += emitCLISubcommand(
                        path: path,
                        method: httpMethod.rawValue.uppercased(),
                        opId: opId,
                        op: op,
                        defaultServerURL: defaultServerURL
                    )
                }
            }
        }
    }

    output += emitCLIMCPCommandFooter()
    return output
}

/// Emits the imports and `@main struct APIClientCLI` declaration with its registered subcommands.
///
/// - Parameter document: The `OpenAPIDocument` providing CLI metadata and paths.
/// - Returns: Generated Swift source code for `APIClientCLI`.
private func emitCLIRootCommand(for document: OpenAPIDocument) -> String {
    var output = "import ArgumentParser\nimport Foundation\n\n"
    output += "@main\n"
    output += "struct APIClientCLI: AsyncParsableCommand {\n"
    output += "    static let configuration = CommandConfiguration(\n"
    output += "        commandName: \"api\",\n"
    output += "        abstract: \"\(document.info.title) CLI\",\n"
    output += "        version: \"\(document.info.version)\",\n"

    var subcommands: [String] = []
    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (_, op) in item.operationsByMethod {
                if let opId = op.operationId {
                    let structName = opId.prefix(1).uppercased() + opId.dropFirst() + "Command"
                    subcommands.append("\(structName).self")
                }
            }
        }
    }
    subcommands.append("MCPCommand.self")

    output += "        subcommands: [\(subcommands.joined(separator: ", "))]\n"
    output += "    )\n}\n\n"
    return output
}

/// Emits an `AsyncParsableCommand` struct for a single OpenAPI operation.
///
/// - Parameters:
///   - path: The URL path template string.
///   - method: The uppercase HTTP method name.
///   - opId: The operation identifier.
///   - op: The OpenAPI `Operation` descriptor.
///   - defaultServerURL: Default `--server-url` option value.
/// - Returns: Generated Swift command struct source code.
private func emitCLISubcommand(
    path: String,
    method: String,
    opId: String,
    op: Operation,
    defaultServerURL: String
) -> String {
    let structName = opId.prefix(1).uppercased() + opId.dropFirst() + "Command"
    var output = "struct \(structName): AsyncParsableCommand {\n"

    let summary = op.summary ?? ""
    output += "    static let configuration = CommandConfiguration(commandName: \"\(opId.lowercased())\", abstract: \"\(summary)\")\n\n"
    output += "    @Option(name: .customLong(\"server-url\"), help: \"Base URL of the API server\")\n"
    output += "    var serverUrl: String = \"\(defaultServerURL)\"\n\n"

    var callArgs: [String] = []
    var printArgs: [String] = []
    if let params = op.parameters {
        for param in params {
            if let origName = param.name {
                let name = origName.replacingOccurrences(of: "-", with: "_")
                let paramDesc = param.description ?? ""
                output += "    @Option(name: .customLong(\"\(origName.lowercased())\"), help: \"\(paramDesc)\")\n"

                let type = param.schema?.type == "integer" ? "Int" : "String"
                let isReq = param.required == true
                output += "    var \(name): \(type)\(isReq ? "" : "?")\n\n"
                callArgs.append("\(name): \(name)")
                printArgs.append(#"\(\#(name))"#)
            }
        }
    }

    output += "    mutating func run() async throws {\n"
    output += "        // Call API endpoint: \(method) \(path)\n"
    output += "        guard let baseURL = URL(string: serverUrl) else { throw URLError(.badURL) }\n"
    output += "        let client = APIClient(baseURL: baseURL)\n"
    output += "        _ = try await client.\(opId)(\(callArgs.joined(separator: ", ")))\n"

    if printArgs.isEmpty {
        output += "        print(\"Executing \(opId) with no args\")\n"
    } else {
        output += "        print(\"Executing \(opId) with args: \(printArgs.joined(separator: ", "))\")\n"
    }

    output += "    }\n}\n\n"
    return output
}

/// Emits the `MCPStdioRequest`, `MCPStdioResponse`, and `MCPCommand` footer structs for the CLI SDK.
///
/// - Returns: Generated Swift source code for the embedded MCP stdio subcommand.
private func emitCLIMCPCommandFooter() -> String {
    return """
    struct MCPStdioRequest: Codable, Sendable {
        let jsonrpc: String?
        let id: String?
        let method: String
    }

    struct MCPStdioResponse: Codable, Sendable {
        let jsonrpc: String
        let id: String?
        let result: [String: String]
    }

    struct MCPCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "mcp", abstract: "Start the MCP server via stdio")

        mutating func run() async throws {
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let req = try? decoder.decode(MCPStdioRequest.self, from: data) else { continue }
                let response = MCPStdioResponse(jsonrpc: "2.0", id: req.id, result: ["method": req.method])
                let outData = try encoder.encode(response)
                print(String(decoding: outData, as: UTF8.self))
            }
        }
    }

    """
}
