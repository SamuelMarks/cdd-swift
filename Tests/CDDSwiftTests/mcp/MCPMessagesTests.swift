import XCTest
@testable import CDDSwift

final class MCPMessagesTests: XCTestCase {
    func testProgressToken() throws {
        let stringToken = ProgressToken.string("abc")
        let intToken = ProgressToken.integer(42)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stringTokenData = try encoder.encode(stringToken)
        let intTokenData = try encoder.encode(intToken)

        let decodedStringToken = try decoder.decode(ProgressToken.self, from: stringTokenData)
        let decodedIntToken = try decoder.decode(ProgressToken.self, from: intTokenData)

        XCTAssertEqual(stringToken, decodedStringToken)
        XCTAssertEqual(intToken, decodedIntToken)
    }

    func testProgressTokenInvalid() {
        let data = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ProgressToken.self, from: data))
    }

    func testMeta() throws {
        let meta = Meta(progressToken: .string("abc"))
        XCTAssertEqual(meta.progressToken, .string("abc"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(Meta.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testRequestParams() {
        let params = RequestParams(_meta: Meta(progressToken: .integer(1)))
        XCTAssertEqual(params._meta?.progressToken, .integer(1))
    }

    func testNotificationParams() {
        let params = NotificationParams(_meta: Meta(progressToken: .integer(1)))
        XCTAssertEqual(params._meta?.progressToken, .integer(1))
    }

    func testResult() {
        let result = Result(_meta: Meta(progressToken: .integer(1)))
        XCTAssertEqual(result._meta?.progressToken, .integer(1))
    }

    func testEmptyResult() {
        let result = EmptyResult(_meta: Meta(progressToken: .integer(1)))
        XCTAssertEqual(result._meta?.progressToken, .integer(1))
    }

    func testImplementation() throws {
        let impl = Implementation(name: "test-client", version: "1.0")
        XCTAssertEqual(impl.name, "test-client")
        XCTAssertEqual(impl.version, "1.0")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(impl)
        let decoded = try decoder.decode(Implementation.self, from: data)
        XCTAssertEqual(decoded, impl)
    }

    func testClientCapabilities() throws {
        let cap = ClientCapabilities(
            experimental: ["foo": AnyCodable("bar")],
            roots: .init(listChanged: true),
            sampling: .init()
        )
        XCTAssertEqual(cap.experimental?["foo"]?.value as? String, "bar")
        XCTAssertEqual(cap.roots?.listChanged, true)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(cap)
        let decoded = try decoder.decode(ClientCapabilities.self, from: data)
        XCTAssertEqual(decoded.roots?.listChanged, true)
    }

    func testServerCapabilities() throws {
        let cap = ServerCapabilities(
            experimental: ["foo": AnyCodable("bar")],
            logging: .init(),
            prompts: .init(listChanged: true),
            resources: .init(listChanged: false, subscribe: true),
            tools: .init(listChanged: true)
        )
        XCTAssertEqual(cap.experimental?["foo"]?.value as? String, "bar")
        XCTAssertEqual(cap.prompts?.listChanged, true)
        XCTAssertEqual(cap.resources?.listChanged, false)
        XCTAssertEqual(cap.resources?.subscribe, true)
        XCTAssertEqual(cap.tools?.listChanged, true)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(cap)
        let decoded = try decoder.decode(ServerCapabilities.self, from: data)
        XCTAssertEqual(decoded.prompts?.listChanged, true)
    }

    func testInitializeRequestParams() throws {
        let clientInfo = Implementation(name: "test", version: "1.0")
        let cap = ClientCapabilities()
        let req = InitializeRequestParams(protocolVersion: "2024-11-05", capabilities: cap, clientInfo: clientInfo)

        XCTAssertEqual(req.protocolVersion, "2024-11-05")
        XCTAssertEqual(req.clientInfo.name, "test")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(InitializeRequestParams.self, from: data)
        XCTAssertEqual(decoded, req)
    }

    func testInitializeResult() throws {
        let serverInfo = Implementation(name: "test-server", version: "1.0")
        let cap = ServerCapabilities()
        let res = InitializeResult(_meta: Meta(progressToken: .string("p")), protocolVersion: "2024-11-05", capabilities: cap, serverInfo: serverInfo, instructions: "Hello")

        XCTAssertEqual(res.protocolVersion, "2024-11-05")
        XCTAssertEqual(res.serverInfo.name, "test-server")
        XCTAssertEqual(res.instructions, "Hello")
        XCTAssertEqual(res._meta?.progressToken, .string("p"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(InitializeResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testInitializedNotificationParams() {
        let params = InitializedNotificationParams(_meta: Meta(progressToken: .integer(1)))
        XCTAssertEqual(params._meta?.progressToken, .integer(1))
    }
}
