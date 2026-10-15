#if !os(WASI)
    import ArgumentParser
    import CDDSwift
    import Foundation
    import Swifter

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #endif

    /// Protocol abstracting command execution for JSON-RPC CLI invocation.
    public protocol CommandExecutor: Sendable {
        /// Executes a CLI command with the provided arguments and returns its combined stdout/stderr output.
        ///
        /// - Parameter args: The command-line arguments to pass to the CLI binary.
        /// - Returns: The UTF-8 decoded output string.
        /// - Throws: `CDDError.processExecutionFailed` if launching the process fails.
        func execute(args: [String]) throws -> String
    }

    /// Default process-based command executor that invokes the current executable binary.
    public struct DefaultCommandExecutor: CommandExecutor {
        /// Optional override executable path for testing or custom invocation.
        public var executablePathOverride: String?

        /// Initializes a `DefaultCommandExecutor`.
        ///
        /// - Parameter executablePathOverride: Optional path to use instead of `Bundle.main.executablePath`.
        public init(executablePathOverride: String? = nil) {
            self.executablePathOverride = executablePathOverride
        }

        /// Executes the CLI binary with the given arguments.
        ///
        /// - Parameter args: The command-line arguments to pass.
        /// - Returns: The combined stdout and stderr output as a UTF-8 string.
        /// - Throws: `CDDError.processExecutionFailed` if the executable path is missing or launching fails.
        public func execute(args: [String]) throws -> String {
            var execPath = CommandLine.arguments[0]
            if let overridePath = executablePathOverride {
                execPath = overridePath
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(decoding: data, as: UTF8.self)
            } catch {
                throw CDDError.processExecutionFailed(executable: execPath, message: error.localizedDescription)
            }
        }
    }

    /// Exposes the `cdd-swift` CLI interface as an HTTP JSON-RPC 2.0 server.
    struct ServeJsonRpc: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve_json_rpc",
            abstract: "Expose CLI interface as a JSON-RPC server.",
            usage: "cdd-swift serve_json_rpc [-p <port>|--port <port>] [-l <listen>|--listen <listen>]"
        )

        /// Injectable command executor used by `ServeJsonRpc` when handling requests.
        nonisolated(unsafe) static var executor: CommandExecutor = DefaultCommandExecutor()

        @Option(name: [.customShort("p"), .customLong("port")], help: "Port to listen on.")
        /// The TCP port on which the JSON-RPC HTTP server listens.
        var port: UInt16 = 8082

        @Option(name: [.customShort("l"), .customLong("listen")], help: "Host to listen on.")
        /// The host address on which the JSON-RPC HTTP server binds.
        var listen: String = "0.0.0.0"

        /// Starts the Swifter HTTP server and processes incoming JSON-RPC 2.0 POST requests until the task is cancelled.
        ///
        /// - Throws: An error if the HTTP server fails to bind to the requested port.
        mutating func run() async throws {
            let server = HttpServer()

            server.POST["/"] = { request in
                let bodyData = Data(request.body)
                guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                      let method = json["method"] as? String,
                      let rawId = json["id"]
                else {
                    return .badRequest(.text("Invalid JSON-RPC format"))
                }

                let rpcId: JSONRPCId
                if let intId = rawId as? Int {
                    rpcId = .integer(intId)
                } else {
                    rpcId = .string(String(describing: rawId))
                }

                var args = [method]
                if let params = json["params"] as? [String: Any] {
                    for (k, v) in params.sorted(by: { $0.key < $1.key }) {
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

                let encoder = JSONEncoder()
                do {
                    let output = try ServeJsonRpc.executor.execute(args: args)
                    let response = JSONRPCResponse(id: rpcId, result: output)
                    var respData = Data()
                    if let encoded = try? encoder.encode(response) {
                        respData = encoded
                    }
                    return .ok(.data(respData, contentType: "application/json"))
                } catch {
                    let detail = JSONRPCErrorDetail(code: .internalError, message: error.localizedDescription)
                    let errorResponse = JSONRPCError(id: rpcId, error: detail)
                    var respData = Data()
                    if let encoded = try? encoder.encode(errorResponse) {
                        respData = encoded
                    }
                    return .ok(.data(respData, contentType: "application/json"))
                }
            }

            do {
                try server.start(port, forceIPv4: true, priority: .default)
                print("🚀 JSON-RPC server started on \(listen):\(port)")
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            } catch {
                print("Server start error: \(error)")
                throw error
            }
        }
    }

#endif
