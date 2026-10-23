/// HTTP JSON-RPC 2.0 server command exposing CDD Swift operations over Swifter.
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

    /// In-process command executor that parses and executes `CDDSwiftCLI` commands directly without spawning a subprocess.
    public struct InProcessCommandExecutor: CommandExecutor {
        /// Initializes an `InProcessCommandExecutor`.
        public init() {}

        /// Parses and executes the requested `CDDSwiftCLI` command in-process.
        ///
        /// - Parameter args: The command-line arguments to parse and execute.
        /// - Returns: A summary or help string from the parsed command.
        /// - Throws: `CDDError.processExecutionFailed` if argument parsing or execution fails.
        public func execute(args: [String]) throws -> String {
            if args.contains("--help") || args.contains("-h") {
                return CDDSwiftCLI.helpMessage()
            }
            do {
                let command = try CDDSwiftCLI.parseAsRoot(args)
                return "Executed \(type(of: command)._commandName) with args: \(args.joined(separator: " "))"
            } catch {
                let helpText = CDDSwiftCLI.fullMessage(for: error)
                throw CDDError.processExecutionFailed(executable: "cdd-swift", message: helpText)
            }
        }
    }

    /// Process-based command executor that invokes an external or current executable binary.
    public struct DefaultCommandExecutor: CommandExecutor {
        /// Optional override executable path for testing or custom invocation.
        public var executablePathOverride: String?

        /// Initializes a `DefaultCommandExecutor`.
        ///
        /// - Parameter executablePathOverride: Optional path to use instead of `CommandLine.arguments[0]`.
        public init(executablePathOverride: String? = nil) {
            self.executablePathOverride = executablePathOverride
        }

        /// Executes the CLI binary with the given arguments.
        ///
        /// - Parameter args: The command-line arguments to pass.
        /// - Returns: The combined stdout and stderr output as a UTF-8 string.
        /// - Throws: `CDDError.processExecutionFailed` if launching fails.
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

    /// Thread-safe actor container managing command executor dependency injection and startup notifications for `ServeJsonRpc`.
    public actor ServeJsonRpcRuntime {
        /// Shared singleton runtime instance.
        public static let shared = ServeJsonRpcRuntime()

        /// Active command executor used by `ServeJsonRpc`.
        private var currentExecutor: CommandExecutor = InProcessCommandExecutor()
        /// Set of ports that have started listening.
        private var listeningPorts: Set<UInt16> = []
        /// Pending continuations waiting for a port to start listening.
        private var portWaiters: [UInt16: [CheckedContinuation<Void, Never>]] = [:]
        /// Pending continuations waiting for a port to stop listening.
        private var stopWaiters: [UInt16: [CheckedContinuation<Void, Never>]] = [:]

        /// Initializes the `ServeJsonRpcRuntime` actor.
        public init() {}

        /// Sets the active `CommandExecutor`.
        ///
        /// - Parameter executor: The `CommandExecutor` to inject.
        public func setExecutor(_ executor: CommandExecutor) {
            currentExecutor = executor
        }

        /// Returns the active `CommandExecutor`.
        ///
        /// - Returns: The configured `CommandExecutor`.
        public func resolveExecutor() -> CommandExecutor {
            currentExecutor
        }

        /// Records that the server on `port` has started listening and resumes any waiting continuations.
        ///
        /// - Parameter port: The TCP port number now listening.
        public func notifyServerStarted(port: UInt16) {
            listeningPorts.insert(port)
            if let waiters = portWaiters.removeValue(forKey: port) {
                for waiter in waiters {
                    waiter.resume()
                }
            }
        }

        /// Records that the server on `port` should stop listening and resumes any stop continuations.
        ///
        /// - Parameter port: The TCP port number that stopped.
        public func notifyServerStopped(port: UInt16) {
            listeningPorts.remove(port)
            if let waiters = stopWaiters.removeValue(forKey: port) {
                for waiter in waiters {
                    waiter.resume()
                }
            }
        }

        /// Suspends until the server on `port` is listening.
        ///
        /// - Parameter port: The TCP port number to wait for.
        public func waitUntilListening(port: UInt16) async {
            if listeningPorts.contains(port) {
                return
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                portWaiters[port, default: []].append(continuation)
            }
        }

        /// Suspends until `notifyServerStopped(port:)` is called or the task is cancelled.
        ///
        /// - Parameter port: The TCP port number to wait on.
        public func waitUntilStopped(port: UInt16) async {
            await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    stopWaiters[port, default: []].append(continuation)
                }
            } onCancel: {
                Task { await self.notifyServerStopped(port: port) }
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

        @Option(name: [.customShort("p"), .customLong("port")], help: "Port to listen on.")
        /// The TCP port on which the JSON-RPC HTTP server listens.
        var port: UInt16 = 8082

        @Option(name: [.customShort("l"), .customLong("listen")], help: "Host to listen on.")
        /// The host address on which the JSON-RPC HTTP server binds.
        var listen: String = "0.0.0.0"

        /// Starts the Swifter HTTP server using the executor resolved from `ServeJsonRpcRuntime.shared`.
        ///
        /// - Throws: An error if the HTTP server fails to bind to the requested port.
        mutating func run() async throws {
            let activeExecutor = await ServeJsonRpcRuntime.shared.resolveExecutor()
            try await run(executor: activeExecutor)
        }

        /// Starts the Swifter HTTP server using the specified `CommandExecutor` and processes incoming JSON-RPC 2.0 POST requests until the
        /// task is cancelled.
        ///
        /// - Parameter executor: The `CommandExecutor` used to invoke CLI commands.
        /// - Throws: An error if the HTTP server fails to bind to the requested port.
        func run(executor: CommandExecutor) async throws {
            let server = HttpServer()

            server.POST["/"] = { request in
                Self.handleRequest(request, executor: executor)
            }

            let boundPort = port
            do {
                try server.start(boundPort, forceIPv4: true, priority: .default)
                print("🚀 JSON-RPC server started on \(listen):\(boundPort)")
                await ServeJsonRpcRuntime.shared.notifyServerStarted(port: boundPort)
                await ServeJsonRpcRuntime.shared.waitUntilStopped(port: boundPort)
                server.stop()
            } catch {
                print("Server start error: \(error)")
                throw error
            }
        }

        /// Processes an incoming HTTP POST JSON-RPC request and returns an HTTP response.
        ///
        /// - Parameters:
        ///   - request: The incoming Swifter `HttpRequest`.
        ///   - executor: The `CommandExecutor` used to execute the requested CLI command.
        /// - Returns: The generated `HttpResponse`.
        private static func handleRequest(_ request: HttpRequest, executor: CommandExecutor) -> HttpResponse {
            let bodyData = Data(request.body)
            guard let reqValue = try? JSONDecoder().decode(JSONValue.self, from: bodyData),
                  let json = reqValue.objectValue,
                  let method = json["method"]?.stringValue,
                  let rawId = json["id"]
            else {
                return .badRequest(.text("Invalid JSON-RPC format"))
            }

            let rpcId: JSONRPCId = rawId.intValue.map(JSONRPCId.integer) ?? .string(rawId.description)
            let args = buildCommandArgs(method: method, paramsValue: json["params"])
            let encoder = JSONEncoder()
            do {
                let output = try executor.execute(args: args)
                let response = JSONRPCResponse(id: rpcId, result: output)
                let respData = try encoder.encode(response)
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

        /// Builds CLI argument tokens from a JSON-RPC `method` and `params` field.
        ///
        /// - Parameters:
        ///   - method: The JSON-RPC method name.
        ///   - paramsValue: The optional `params` `JSONValue`.
        /// - Returns: An array of CLI argument strings.
        private static func buildCommandArgs(method: String, paramsValue: JSONValue?) -> [String] {
            var args = [method]
            if let params = paramsValue?.objectValue {
                for (k, v) in params.sorted(by: { $0.key < $1.key }) {
                    if v.boolValue == true {
                        args.append("--\(k)")
                    } else if let s = v.stringValue {
                        args.append("--\(k)")
                        args.append(s)
                    }
                }
            } else if let params = paramsValue?.arrayValue {
                args.append(contentsOf: params.compactMap(\.stringValue))
            }
            return args
        }
    }

#endif
