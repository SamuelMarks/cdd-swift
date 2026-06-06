import Foundation

/// A protocol defining an MCP transport.
public protocol MCPTransport: Sendable {
    /// Send a message.
    func send<T: Encodable>(_ message: T) async throws
    /// Start reading messages.
    func start(onMessage: @escaping (Data) async -> Void) async throws
    /// Stop reading messages.
    func close() async throws
}

/// A standard I/O transport for MCP.
/// Reads newline-delimited JSON messages from stdin, and writes to stdout.
public class MCPStdioTransport: MCPTransport, @unchecked Sendable {
    private let inputStream: InputStream
    private let outputStream: OutputStream
    private var isReading = false
    private let encoder = JSONEncoder()

    public init(inputStream: InputStream, outputStream: OutputStream) {
        self.inputStream = inputStream
        self.outputStream = outputStream
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// Convenience initializer using standard input/output.
    public convenience init() {
        self.init(
            inputStream: InputStream(fileAtPath: "/dev/stdin") ?? InputStream(data: Data()),
            outputStream: OutputStream(toFileAtPath: "/dev/stdout", append: true) ?? OutputStream(toMemory: ())
        )
    }

    public func send<T: Encodable>(_ message: T) async throws {
        var data = try encoder.encode(message)
        data.append(contentsOf: [0x0A]) // Newline

        try data.withUnsafeBytes { buffer in
            guard let pointer = buffer.bindMemory(to: UInt8.self).baseAddress else {
                throw NSError(domain: "MCPStdioTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to bind memory"])
            }
            var totalWritten = 0
            while totalWritten < data.count {
                let written = outputStream.write(pointer + totalWritten, maxLength: data.count - totalWritten)
                if written < 0 {
                    throw outputStream.streamError ?? NSError(domain: "MCPStdioTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Write error"])
                }
                totalWritten += written
            }
        }
    }

    public func start(onMessage: @escaping (Data) async -> Void) async throws {
        guard !isReading else { return }
        isReading = true
        inputStream.open()
        outputStream.open()

        let bufferSize = 1024 * 8
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var messageData = Data()

        while isReading {
            if inputStream.hasBytesAvailable {
                let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    let readData = Data(bytes: buffer, count: bytesRead)
                    messageData.append(readData)

                    // Process newline separated messages
                    while let newlineRange = messageData.firstRange(of: Data([0x0A])) {
                        let message = messageData.subdata(in: 0 ..< newlineRange.lowerBound)
                        if !message.isEmpty {
                            await onMessage(message)
                        }
                        messageData.removeSubrange(0 ..< newlineRange.upperBound)
                    }
                } else if bytesRead < 0 {
                    // Error
                    isReading = false
                    break
                }
            } else {
                // Small sleep to avoid spinning CPU entirely
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    public func close() async throws {
        isReading = false
        inputStream.close()
        outputStream.close()
    }
}
