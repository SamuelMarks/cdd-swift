import XCTest
@testable import CDDSwift

final class FaultyOutputStream: OutputStream {
    override func open() {}
    override func close() {}

    override var streamError: Error? {
        return NSError(domain: "test", code: 42, userInfo: nil)
    }
    
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }
}

final class FaultyInputStream: InputStream {
    override func open() {}
    override func close() {}

    override var hasBytesAvailable: Bool { return true }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }
}

final class MCPStdioTransportTests: XCTestCase {
    func testConvenienceInit() {
        let transport = MCPStdioTransport()
        XCTAssertNotNil(transport)
    }

    func testSend() async throws {
        let outputStream = OutputStream(toMemory: ())
        outputStream.open()
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: outputStream)
        
        let msg = JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test")
        try await transport.send(msg)
        
        let data = outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let string = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(string.contains("\"method\":\"test\""))
        XCTAssertTrue(string.hasSuffix("\n"))
    }
    
    func testSendError() async {
        let transport = MCPStdioTransport(inputStream: InputStream(data: Data()), outputStream: FaultyOutputStream(toMemory: ()))
        do {
            try await transport.send(JSONRPCRequest<AnyCodable>(id: .integer(1), method: "test"))
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testStartAndReceive() async throws {
        let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\"}\n"
        let data = json.data(using: .utf8)!
        let inputStream = InputStream(data: data)
        let transport = MCPStdioTransport(inputStream: inputStream, outputStream: OutputStream(toMemory: ()))
        
        let expectation = XCTestExpectation(description: "Receive message")
        
        Task {
            try await transport.start { receivedData in
                let receivedString = String(data: receivedData, encoding: .utf8)!
                XCTAssertEqual(receivedString, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\"}")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        try await transport.close()
    }

    func testStartReadError() async throws {
        let transport = MCPStdioTransport(inputStream: FaultyInputStream(data: Data()), outputStream: OutputStream(toMemory: ()))
        let task = Task {
            try await transport.start { _ in }
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
    }
}