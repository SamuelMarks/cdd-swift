/// Swift ArgumentParser CLI SDK emitter for OpenAPI documents.
import Foundation

/// Emits Swift code for a CLI SDK.
///
/// - Parameter document: The `OpenAPIDocument` describing the API endpoints and metadata.
/// - Returns: Generated Swift `ArgumentParser` CLI source code.
public func emitSDKCLI(document: OpenAPIDocument) -> String {
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
            let ops = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
            for op in ops {
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

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            let methods = [("GET", item.get), ("POST", item.post), ("PUT", item.put), ("DELETE", item.delete), ("PATCH", item.patch)]
            for (method, optionalOp) in methods {
                guard let op = optionalOp, let opId = op.operationId else { continue }

                let structName = opId.prefix(1).uppercased() + opId.dropFirst() + "Command"
                output += "struct \(structName): AsyncParsableCommand {\n"

                let summary = op.summary ?? ""
                output += "    static let configuration = CommandConfiguration(commandName: \"\(opId.lowercased())\", abstract: \"\(summary)\")\n\n"

                var args = [String]()
                if let params = op.parameters {
                    for param in params {
                        if let origName = param.name {
                            let name = origName.replacingOccurrences(of: "-", with: "_")
                            let paramDesc = param.description ?? ""
                            output += "    @Option(name: .customLong(\"\(origName.lowercased())\"), help: \"\(paramDesc)\")\n"

                            let type = param.schema?.type == "integer" ? "Int" : "String"
                            let isReq = param.required == true
                            output += "    var \(name): \(type)\(isReq ? "" : "?")\n\n"
                            args.append(name)
                        }
                    }
                }

                output += "    mutating func run() async throws {\n"
                output += "        // Call API endpoint: \(method) \(path)\n"

                if args.isEmpty {
                    output += "        print(\"Executing \(opId) with no args\")\n"
                } else {
                    let argStr = args.map { "\\(\($0))" }.joined(separator: ", ")
                    output += "        print(\"Executing \(opId) with args: \(argStr)\")\n"
                }

                output += "    }\n}\n\n"
            }
        }
    }

    output += "struct MCPCommand: AsyncParsableCommand {\n"
    output += "    static let configuration = CommandConfiguration(commandName: \"mcp\", abstract: \"Start the MCP server via stdio\")\n\n"
    output += "    mutating func run() async throws {\n"
    output += "        while let line = readLine() {\n"
    output += "            guard let data = line.data(using: .utf8),\n"
    output += "                  let req = try? JSONSerialization.jsonObject(with: data) as? [String: Any],\n"
    output += "                  let method = req[\"method\"] as? String else { continue }\n"
    output += "            let id = req[\"id\"] ?? NSNull()\n"
    output += "            let response: [String: Any] = [\"jsonrpc\": \"2.0\", \"id\": id, \"result\": [\"method\": method]]\n"
    output += "            if let outData = try? JSONSerialization.data(withJSONObject: response),\n"
    output += "               let outStr = String(data: outData, encoding: .utf8) {\n"
    output += "                print(outStr)\n"
    output += "            }\n"
    output += "        }\n"
    output += "    }\n}\n\n"

    return output
}
