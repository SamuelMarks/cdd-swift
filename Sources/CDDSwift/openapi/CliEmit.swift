import Foundation

/// Emits Swift code for a CLI SDK.
public func emitSDKCLI(document: OpenAPIDocument) -> String {
    /// Documentation for output
    var output = "import ArgumentParser\nimport Foundation\n\n"
    output += "@main\n"
    output += "struct APIClientCLI: AsyncParsableCommand {\n"
    output += "    static let configuration = CommandConfiguration(\n"
    output += "        commandName: \"api\",\n"
    output += "        abstract: \"\(document.info.title) CLI\",\n"
    
    /// Documentation for subcommands
    var subcommands: [String] = []
    
    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            /// Documentation for ops
            let ops = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
            for op in ops {
                if let opId = op.operationId {
                    /// Documentation for structName
                    let structName = opId.prefix(1).uppercased() + opId.dropFirst() + "Command"
                    subcommands.append("\(structName).self")
                }
            }
        }
    }
    
    if !subcommands.isEmpty {
        output += "        subcommands: [\(subcommands.joined(separator: ", "))]\n"
    } else {
        output += "        subcommands: []\n"
    }
    output += "    )\n}\n\n"
    
    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            /// Documentation for methods
            let methods = [("GET", item.get), ("POST", item.post), ("PUT", item.put), ("DELETE", item.delete), ("PATCH", item.patch)]
            for (method, optionalOp) in methods {
                guard let op = optionalOp, let opId = op.operationId else { continue }
                /// Documentation for structName
                let structName = opId.prefix(1).uppercased() + opId.dropFirst() + "Command"
                output += "struct \(structName): AsyncParsableCommand {\n"
                /// Documentation for summary
                let summary = op.summary ?? ""
                output += "    static let configuration = CommandConfiguration(commandName: \"\(opId.lowercased())\", abstract: \"\(summary)\")\n\n"
                
                /// Documentation for args
                var args = [String]()
                if let params = op.parameters {
                    for param in params {
                        if let origName = param.name {
                            /// Documentation for name
                            let name = origName.replacingOccurrences(of: "-", with: "_")
                            /// Documentation for paramDesc
                            let paramDesc = param.description ?? ""
                            output += "    @Option(name: .customLong(\"\(origName.lowercased())\"), help: \"\(paramDesc)\")\n"
                            /// Documentation for type
                            let type = param.schema?.type == "integer" ? "Int" : "String"
                            /// Documentation for isReq
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
                    /// Documentation for argStr
                    let argStr = args.map { "\\(\($0))" }.joined(separator: ", ")
                    output += "        print(\"Executing \(opId) with args: \(argStr)\")\n"
                }
                
                output += "    }\n}\n\n"
            }
        }
    }
    
    return output
}
