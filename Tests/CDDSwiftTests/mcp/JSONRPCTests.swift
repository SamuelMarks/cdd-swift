/// Unit tests for JSON-RPC 2.0 request, notification, response, and error envelopes.
import XCTest
@testable import CDDSwift

/// Test suite verifying `JSONRPCId`, `JSONRPCRequest`, `JSONRPCNotification`, `JSONRPCResponse`, and `JSONRPCError`.
final class JSONRPCTests: XCTestCase {
    /// Verifies encoding and decoding of `.string` and `.integer` `JSONRPCId` cases.
    func testJSONRPCId() throws {
        let stringId = JSONRPCId.string("123")
        let intId = JSONRPCId.integer(123)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stringIdData = try encoder.encode(stringId)
        let intIdData = try encoder.encode(intId)

        let decodedStringId = try decoder.decode(JSONRPCId.self, from: stringIdData)
        let decodedIntId = try decoder.decode(JSONRPCId.self, from: intIdData)

        XCTAssertEqual(stringId, decodedStringId)
        XCTAssertEqual(intId, decodedIntId)
    }

    /// Verifies that decoding an invalid boolean token as `JSONRPCId` throws an error.
    func testJSONRPCIdInvalid() {
        let data = Data("true".utf8)
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(JSONRPCId.self, from: data))
    }

    /// Verifies `JSONRPCRequest` initialization, encoding, and decoding.
    func testJSONRPCRequest() throws {
        let req = JSONRPCRequest(id: .integer(1), method: "test", params: AnyCodable("param"))
        XCTAssertEqual(req.jsonrpc, "2.0")
        XCTAssertEqual(req.id, .integer(1))
        XCTAssertEqual(req.method, "test")
        XCTAssertEqual(req.params?.stringValue, "param")

        let encoder = JSONEncoder()
        let data = try encoder.encode(req)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCRequest<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.method, "test")
    }

    /// Verifies `JSONRPCNotification` initialization, encoding, and decoding.
    func testJSONRPCNotification() throws {
        let notif = JSONRPCNotification(method: "test", params: AnyCodable(123))
        XCTAssertEqual(notif.jsonrpc, "2.0")
        XCTAssertEqual(notif.method, "test")
        XCTAssertEqual(notif.params?.intValue, 123)

        let encoder = JSONEncoder()
        let data = try encoder.encode(notif)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCNotification<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.method, "test")
    }

    /// Verifies `JSONRPCResponse` initialization, encoding, and decoding.
    func testJSONRPCResponse() throws {
        let resp = JSONRPCResponse(id: .string("abc"), result: AnyCodable("ok"))
        XCTAssertEqual(resp.jsonrpc, "2.0")
        XCTAssertEqual(resp.id, .string("abc"))
        XCTAssertEqual(resp.result?.stringValue, "ok")

        let encoder = JSONEncoder()
        let data = try encoder.encode(resp)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.id, .string("abc"))
    }

    /// Verifies `JSONRPCError` and `JSONRPCErrorDetail` initialization, encoding, and decoding.
    func testJSONRPCError() throws {
        let errDetail = JSONRPCErrorDetail(code: -32600, message: "Invalid Request", data: AnyCodable("details"))
        let err = JSONRPCError(id: .integer(1), error: errDetail)
        XCTAssertEqual(err.jsonrpc, "2.0")
        XCTAssertEqual(err.id, .integer(1))
        XCTAssertEqual(err.error.code, -32600)
        XCTAssertEqual(err.error.message, "Invalid Request")
        XCTAssertEqual(err.error.data?.stringValue, "details")

        let encoder = JSONEncoder()
        let data = try encoder.encode(err)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCError.self, from: data)
        XCTAssertEqual(decoded.error.code, -32600)
    }
}
