/// Standard I/O newline-delimited JSON-RPC transport for the Model Context Protocol (MCP).

#if os(WASI)
    /// Minimal in-memory input stream used on WASI when compiling against `FoundationEssentials`.
    public final class InputStream: @unchecked Sendable {
        /// Underlying buffer of unread bytes.
        private let storage: [UInt8]
        /// Current read cursor index within `storage`.
        private var offset: Int = 0

        /// Initializes an `InputStream` reading from the given `Data` buffer.
        ///
        /// - Parameter data: The `Data` payload to read from.
        public init(data: Data) {
            storage = Array(data)
        }

        /// Opens the stream for reading.
        public func open() {}

        /// Closes the stream.
        public func close() {}

        /// Indicates whether unread bytes remain in the stream buffer.
        public var hasBytesAvailable: Bool {
            offset < storage.count
        }

        /// Reads up to `len` bytes into `buffer`.
        ///
        /// - Parameters:
        ///   - buffer: Destination byte buffer pointer.
        ///   - len: Maximum number of bytes to read.
        /// - Returns: Number of bytes actually read, or `0` at end of stream.
        public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
            let available = storage.count - offset
            guard available > 0, len > 0 else { return 0 }
            let count = min(available, len)
            for idx in 0 ..< count {
                buffer[idx] = storage[offset + idx]
            }
            offset += count
            return count
        }
    }

    /// Minimal in-memory output stream used on WASI when compiling against `FoundationEssentials`.
    public final class OutputStream: @unchecked Sendable {
        /// Optional error recorded by the output stream.
        public var streamError: Error?

        /// Initializes an in-memory `OutputStream`.
        public init() {}

        /// Creates and returns an in-memory `OutputStream`.
        ///
        /// - Returns: A new in-memory `OutputStream` instance.
        public static func toMemory() -> OutputStream {
            OutputStream()
        }

        /// Opens the stream for writing.
        public func open() {}

        /// Closes the stream.
        public func close() {}

        /// Writes up to `len` bytes from `buffer` into the stream.
        ///
        /// - Parameters:
        ///   - buffer: Source byte buffer pointer.
        ///   - len: Number of bytes to write.
        /// - Returns: Number of bytes written.
        public func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
            _ = buffer
            return len
        }
    }
#endif

/// A protocol defining an asynchronous bidirectional transport for Model Context Protocol (MCP) JSON-RPC messages.
public protocol MCPTransport: Sendable {
    /// Encodes and sends a JSON-RPC message over the transport.
    ///
    /// - Parameter message: The `Encodable & Sendable` message payload to transmit.
    /// - Throws: `CDDError.mcpTransportError` or an encoding error if transmission fails.
    func send(_ message: some Encodable & Sendable) async throws
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
    /// Continuation resumed when `close()` is called after EOF.
    private var closeContinuation: CheckedContinuation<Void, Never>?

    /// Atomically transitions `isReading` from `false` to `true`.
    ///
    /// - Returns: `true` if the transition succeeded, `false` if already reading.
    func beginReading() -> Bool {
        guard !isReading else { return false }
        isReading = true
        return true
    }

    /// Marks `isReading` as `false` and resumes any pending close continuation.
    func stopReading() {
        isReading = false
        closeContinuation?.resume()
        closeContinuation = nil
    }

    /// Returns whether the transport is currently in the reading state.
    ///
    /// - Returns: `true` if reading is active, `false` otherwise.
    func checkIsReading() -> Bool {
        isReading
    }

    /// Suspends until `stopReading()` is called or the task is cancelled.
    func waitUntilStopped() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                closeContinuation = continuation
            }
        } onCancel: {
            Task { await self.stopReading() }
        }
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
    /// - Parameter message: The `Encodable & Sendable` message to send.
    /// - Throws: `CDDError.mcpTransportError` if writing to the output stream fails.
    public func send(_ message: some Encodable & Sendable) async throws {
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

    /// Opens the underlying streams and reads newline-delimited JSON-RPC messages until closed or error.
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
                } else {
                    await state.stopReading()
                    break
                }
            } else {
                await state.waitUntilStopped()
                break
            }
        }
    }

    /// Stops the read loop and closes both input and output streams.
    ///
    /// - Throws: An error if closing the underlying streams fails.
    public func close() async throws {
        await state.stopReading()
        inputStream.close()
        outputStream.close()
    }
}
