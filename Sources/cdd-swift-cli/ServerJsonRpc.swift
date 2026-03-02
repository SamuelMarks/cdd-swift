#if !os(WASI)
import ArgumentParser
import Foundation
import Swifter

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// JSON RPC Server command
struct ServerJsonRpc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve_json_rpc", abstract: "Run a JSON-RPC HTTP server exposing the CLI capabilities.")

    @Option(help: "Port to listen on")
    /// port
    /// Documentation for port
    var port: UInt16 = 8082

    @Option(help: "Host to listen on")
    /// listen host
    /// Documentation for listen
    var listen: String = "0.0.0.0"

    mutating func run() async throws {
        /// Documentation for server
        let server = HttpServer()
        
        server.POST["/"] = { request in
            /// Documentation for bodyData
            let bodyData = Data(request.body)
            guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  /// Documentation for method
                  let method = json["method"] as? String,
                  /// Documentation for id
                  let id = json["id"] else {
                return .badRequest(.text("Invalid JSON-RPC format"))
            }
            
            /// Documentation for args
            var args = [method]
            if let params = json["params"] as? [String: Any] {
                for (k, v) in params {
                    if let b = v as? Bool, b {
                        args.append("--\(k)")
                    } else if let s = v as? String {
                        args.append("--\(k)")
                        args.append(s)
                    }
                }
            } else if let params = json["params"] as? [String] {
                args.append(contentsOf: params)
            }
            
            /// Documentation for process
            let process = Process()
            
            // To be safe we execute the Swift binary
            process.executableURL = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
            process.arguments = args
            
            /// Documentation for pipe
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                /// Documentation for data
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                /// Documentation for output
                let output = String(data: data, encoding: .utf8) ?? ""
                
                /// Documentation for response
                let response: [String: Any] = [
                    "jsonrpc": "2.0",
                    "result": output,
                    "id": id
                ]
                /// Documentation for respData
                let respData = try? JSONSerialization.data(withJSONObject: response)
                return .ok(.data(respData ?? Data(), contentType: "application/json"))
            } catch {
                /// Documentation for errorResponse
                let errorResponse: [String: Any] = [
                    "jsonrpc": "2.0",
                    "error": ["code": -32603, "message": error.localizedDescription],
                    "id": id
                ]
                /// Documentation for respData
                let respData = try? JSONSerialization.data(withJSONObject: errorResponse)
                return .ok(.data(respData ?? Data(), contentType: "application/json"))
            }
        }
        
        do {
            try server.start(port, forceIPv4: true, priority: .default)
            print("🚀 JSON-RPC server started on \(listen):\(port)")
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        } catch {
            print("Server start error: \(error)")
            throw error
        }
    }
}

#endif
