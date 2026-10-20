/// Standard I/O newline-delimited JSON-RPC transport for the Model Context Protocol (MCP).
import Foundation

/// A protocol defining an asynchronous bidirectional transport for Model Context Protocol (MCP) JSON-RPC messages.
public protocol MCPTransport: Sendable {
    /// Encodes and sends a JSON-RPC message over the transport.
    ///
    /// - Parameter message: The `Encodable` message payload to transmit.
    /// - Throws: `CDDError.mcpTransportError` or an encoding error if transmission fails.
    func send<T: Encodable>(_ message: T) async throws
    /// Starts reading incoming messages from the transport and invokes the provided handler for each frame.
    ///
    /// - Parameter onMessage: An asynchronous closure invoked with the raw `Data` of each received message.
    /// - Throws: `CDDError.mcpTransportError` if the transport fails to start.
    func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws
    /// Closes the transport and stops reading incoming messages.
    ///
    /// - Throws: `CDDError.mcpTransportError` if closing fails.
    func close() async throws
}

/// Actor-isolated state container for `MCPStdioTransport`.
private actor StdioTransportState {
    /// Boolean flag indicating whether the transport is actively reading.
    private var isReading = false

    /// Atomically transitions `isReading` from `false` to `true`.
    ///
    /// - Returns: `true` if the transition succeeded, `false` if already reading.
    func beginReading() -> Bool {
        guard !isReading else { return false }
        isReading = true
        return true
    }

    /// Marks `isReading` as `false`.
    func stopReading() {
        isReading = false
    }

    /// Returns whether the transport is currently in the reading state.
    ///
    /// - Returns: `true` if reading is active, `false` otherwise.
    func checkIsReading() -> Bool {
        return isReading
    }
}

/// A standard I/O transport for Model Context Protocol (MCP) communication.
/// Reads newline-delimited JSON-RPC messages from an `InputStream` and writes newline-delimited JSON-RPC messages to an `OutputStream`.
public final class MCPStdioTransport: MCPTransport, @unchecked Sendable {
    /// Stream from which incoming JSON-RPC frames are read.
    private let inputStream: InputStream
    /// Stream to which outgoing JSON-RPC frames are written.
    private let outputStream: OutputStream
    /// Actor-isolated state tracking active reading status.
    private let state = StdioTransportState()
    /// JSON encoder configured for single-line message framing.
    private let encoder = JSONEncoder()

    /// Initializes a standard I/O transport with explicit input and output streams.
    ///
    /// - Parameters:
    ///   - inputStream: The stream from which incoming JSON-RPC lines are read.
    ///   - outputStream: The stream to which outgoing JSON-RPC lines are written.
    public init(inputStream: InputStream, outputStream: OutputStream) {
        self.inputStream = inputStream
        self.outputStream = outputStream
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// Convenience initializer binding to in-memory streams when no explicit streams are provided.
    public convenience init() {
        self.init(inputStream: InputStream(data: Data()), outputStream: OutputStream.toMemory())
    }

    /// Encodes and writes a newline-delimited JSON-RPC message to the output stream.
    ///
    /// - Parameter message: The `Encodable` message to send.
    /// - Throws: `CDDError.mcpTransportError` if writing to the output stream fails.
    public func send<T: Encodable>(_ message: T) async throws {
        var data = try encoder.encode(message)
        data.append(contentsOf: [0x0A]) // Newline
        let count = data.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { buffer.deallocate() }
        data.copyBytes(to: buffer, count: count)

        var totalWritten = 0
        while totalWritten < count {
            let written = outputStream.write(buffer + totalWritten, maxLength: count - totalWritten)
            if written < 0 {
                if let streamErr = outputStream.streamError {
                    throw streamErr
                }
                throw CDDError.mcpTransportError("Write error on output stream")
            }
            totalWritten += written
        }
    }

    /// Opens the underlying streams and reads newline-delimited JSON-RPC messages until closed or EOF.
    ///
    /// - Parameter onMessage: Closure invoked with each complete line's `Data`.
    /// - Throws: `CDDError.mcpTransportError` if reading fails.
    public func start(onMessage: @escaping @Sendable (Data) async -> Void) async throws {
        let didStart = await state.beginReading()
        guard didStart else { return }
        inputStream.open()
        outputStream.open()

        let bufferSize = 1024 * 8
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var messageData = Data()

        while await state.checkIsReading() {
            if inputStream.hasBytesAvailable {
                let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    let readData = Data(bytes: buffer, count: bytesRead)
                    messageData.append(readData)

                    while let newlineRange = messageData.firstRange(of: Data([0x0A])) {
                        let message = messageData.subdata(in: 0 ..< newlineRange.lowerBound)
                        if !message.isEmpty {
                            await onMessage(message)
                        }
                        messageData.removeSubrange(0 ..< newlineRange.upperBound)
                    }
                } else if bytesRead < 0 {
                    await state.stopReading()
                    break
                }
            } else {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    /// Stops the read loop and closes both input and output streams.
    public func close() async throws {
        await state.stopReading()
        inputStream.close()
        outputStream.close()
    }
}
