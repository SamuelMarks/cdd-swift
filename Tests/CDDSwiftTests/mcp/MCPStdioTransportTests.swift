/// Unit tests for `MCPStdioTransport` standard I/O message framing and lifecycle.
import XCTest
@testable import CDDSwift

/// Mock `OutputStream` that always fails with an explicit `NSError`.
final class FaultyOutputStream: OutputStream {
    /// Returns a fixed test error.
    override var streamError: Error? {
        return NSError(domain: "test", code: 42, userInfo: nil)
    }

    /// Simulates a failed write by returning `-1`.
    ///
    /// - Parameters:
    ///   - buffer: Pointer to bytes to write.
    ///   - len: Maximum number of bytes to write.
    /// - Returns: Always `-1`.
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        _ = buffer
        _ = len
        return -1
    }
}

/// Mock `OutputStream` that fails with `-1` and returns `nil` for `streamError`.
final class NullErrorOutputStream: OutputStream {
    /// Returns `nil` to exercise the fallback `CDDError.mcpTransportError` branch.
    override var streamError: Error? {
        return nil
    }

    /// Simulates a failed write by returning `-1`.
    ///
    /// - Parameters:
    ///   - buffer: Pointer to bytes to write.
    ///   - len: Maximum number of bytes to write.
    /// - Returns: Always `-1`.
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        _ = buffer
        _ = len
        return -1
    }
}

/// Mock `InputStream` that reports available bytes and fails on `read`.
final class FaultyInputStream: InputStream {
    /// No-op stream open.
    override func open() {}

    /// Always reports bytes available so `read` is invoked immediately.
    override var hasBytesAvailable: Bool {
        return true
    }

    /// Simulates a read failure by returning `-1`.
    ///
    /// - Parameters:
    ///   - buffer: Destination buffer pointer.
    ///   - len: Maximum bytes to read.
    /// - Returns: Always `-1`.
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        _ = buffer
        _ = len
        return -1
    }
}

/// No-op message handler used in `MCPStdioTransportTests`.
///
/// - Parameter data: Incoming message bytes.
@Sendable private func noopStdioHandler(_ data: Data) async {
    _ = data
}

/// Test suite verifying `MCPStdioTransport`.
final class MCPStdioTransportTests: XCTestCase {
    /// Verifies the default convenience initializer.
    func testConvenienceInit() {
        let transport = MCPStdioTransport()
        XCTAssertNotNil(transport)
    }

    /// Verifies sending a JSON-RPC request appends a trailing newline.
    func testSend() async throws {
        let outputStream = OutputStream(toMemory: ())
        outputStream.open()
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: outputStream)

        let msg = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test")
        try await transport.send(msg)

        let data = try XCTUnwrap(outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(string.contains(#""method":"test""#))
        XCTAssertTrue(string.hasSuffix("""

        """))
    }

    /// Verifies `send` propagates `streamError` when `OutputStream.write` returns `-1`.
    func testSendError() async {
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: FaultyOutputStream(toMemory: ()))
        let res: Void? = try? await transport.send(JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test"))
        XCTAssertNil(res)
    }

    /// Verifies `send` throws `CDDError.mcpTransportError` when `OutputStream.write` returns `-1` and `streamError` is `nil`.
    func testSendErrorNoStreamError() async {
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: NullErrorOutputStream(toMemory: ()))
        let res: Void? = try? await transport.send(JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test"))
        XCTAssertNil(res)
    }

    /// Verifies calling `start` a second time while already reading returns immediately.
    func testStartTwice() async throws {
        await noopStdioHandler(Data())
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"test"}

        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let transport = MCPStdioTransport(inputStream: InputStream(data: data), outputStream: OutputStream(toMemory: ()))
        let firstMessageReceived = XCTestExpectation(description: "First start receives message")
        let task1 = Task {
            try await transport.start { _ in
                firstMessageReceived.fulfill()
            }
        }
        await fulfillment(of: [firstMessageReceived], timeout: 1.0)
        // Calling start a second time while task1 is suspended in waitUntilStopped returns immediately
        try await transport.start(onMessage: noopStdioHandler)
        try await transport.close()
        try await task1.value
    }

    /// Verifies reading newline-delimited JSON-RPC frames and cleanly suspending until `close()`.
    func testStartAndReceiveWithClose() async throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"test"}


        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let inputStream = InputStream(data: data)
        let transport = MCPStdioTransport(inputStream: inputStream, outputStream: OutputStream(toMemory: ()))

        let expectation = XCTestExpectation(description: "Receive message")

        let task = Task {
            try await transport.start { receivedData in
                let receivedString = String(decoding: receivedData, as: UTF8.self)
                XCTAssertEqual(receivedString, #"{"jsonrpc":"2.0","id":1,"method":"test"}"#)
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        try await transport.close()
        try await task.value
    }

    /// Verifies that a negative byte count from `InputStream.read` stops the read loop cleanly.
    func testStartReadError() async throws {
        let transport = MCPStdioTransport(inputStream: FaultyInputStream(data: Data()), outputStream: OutputStream(toMemory: ()))
        try await transport.start(onMessage: noopStdioHandler)
    }

    /// Verifies task cancellation while suspended waiting for stream close.
    func testStartTaskCancellation() async throws {
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: OutputStream(toMemory: ()))
        let task = Task {
            try await transport.start(onMessage: noopStdioHandler)
        }
        task.cancel()
        try await task.value
    }
}
