import XCTest
@testable import CDDSwift

final class JSONRPCTests: XCTestCase {
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

    func testJSONRPCIdInvalid() {
        let data = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(JSONRPCId.self, from: data))
    }

    func testJSONRPCRequest() throws {
        let req = JSONRPCRequest(id: .integer(1), method: "test", params: AnyCodable("param"))
        XCTAssertEqual(req.jsonrpc, "2.0")
        XCTAssertEqual(req.id, .integer(1))
        XCTAssertEqual(req.method, "test")
        XCTAssertEqual(req.params?.value as? String, "param")

        let encoder = JSONEncoder()
        let data = try encoder.encode(req)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCRequest<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.method, "test")
    }

    func testJSONRPCNotification() throws {
        let notif = JSONRPCNotification(method: "test", params: AnyCodable(123))
        XCTAssertEqual(notif.jsonrpc, "2.0")
        XCTAssertEqual(notif.method, "test")
        XCTAssertEqual(notif.params?.value as? Int, 123)

        let encoder = JSONEncoder()
        let data = try encoder.encode(notif)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCNotification<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.method, "test")
    }

    func testJSONRPCResponse() throws {
        let resp = JSONRPCResponse(id: .string("abc"), result: AnyCodable("ok"))
        XCTAssertEqual(resp.jsonrpc, "2.0")
        XCTAssertEqual(resp.id, .string("abc"))
        XCTAssertEqual(resp.result?.value as? String, "ok")

        let encoder = JSONEncoder()
        let data = try encoder.encode(resp)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data)
        XCTAssertEqual(decoded.id, .string("abc"))
    }

    func testJSONRPCError() throws {
        let errDetail = JSONRPCErrorDetail(code: -32600, message: "Invalid Request", data: AnyCodable("details"))
        let err = JSONRPCError(id: .integer(1), error: errDetail)
        XCTAssertEqual(err.jsonrpc, "2.0")
        XCTAssertEqual(err.id, .integer(1))
        XCTAssertEqual(err.error.code, -32600)
        XCTAssertEqual(err.error.message, "Invalid Request")
        XCTAssertEqual(err.error.data?.value as? String, "details")

        let encoder = JSONEncoder()
        let data = try encoder.encode(err)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONRPCError.self, from: data)
        XCTAssertEqual(decoded.error.code, -32600)
    }
}
