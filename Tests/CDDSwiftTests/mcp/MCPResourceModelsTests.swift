import XCTest
@testable import CDDSwift

final class MCPResourceModelsTests: XCTestCase {
    func testResource() throws {
        let res = Resource(uri: "file://foo", name: "foo", description: "d", mimeType: "text/plain", annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(res.uri, "file://foo")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(Resource.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testResourceTemplate() throws {
        let res = ResourceTemplate(uriTemplate: "file://{foo}", name: "foo", description: "d", mimeType: "text/plain", annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(res.uriTemplate, "file://{foo}")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(ResourceTemplate.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testListResourcesRequestParams() throws {
        let params = ListResourcesRequestParams(_meta: Meta(progressToken: .string("p")), cursor: "c")
        XCTAssertEqual(params.cursor, "c")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ListResourcesRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testListResourcesResult() throws {
        let res = ListResourcesResult(nextCursor: "n", resources: [Resource(uri: "u", name: "n")])
        XCTAssertEqual(res.nextCursor, "n")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(ListResourcesResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testListResourceTemplatesRequestParams() throws {
        let params = ListResourceTemplatesRequestParams(_meta: Meta(progressToken: .string("p")), cursor: "c")
        XCTAssertEqual(params.cursor, "c")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ListResourceTemplatesRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testListResourceTemplatesResult() throws {
        let res = ListResourceTemplatesResult(nextCursor: "n", resourceTemplates: [ResourceTemplate(uriTemplate: "u", name: "n")])
        XCTAssertEqual(res.nextCursor, "n")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(ListResourceTemplatesResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testReadResourceRequestParams() throws {
        let params = ReadResourceRequestParams(_meta: Meta(progressToken: .string("p")), uri: "u")
        XCTAssertEqual(params.uri, "u")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ReadResourceRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testResourceContents() throws {
        let text = TextResourceContents(uri: "u", mimeType: "m", text: "t")
        let blob = BlobResourceContents(uri: "u2", mimeType: "m2", blob: "b")

        let textContent = ResourceContents.text(text)
        let blobContent = ResourceContents.blob(blob)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let textData = try encoder.encode(textContent)
        let decodedText = try decoder.decode(ResourceContents.self, from: textData)
        XCTAssertEqual(decodedText, textContent)

        let blobData = try encoder.encode(blobContent)
        let decodedBlob = try decoder.decode(ResourceContents.self, from: blobData)
        XCTAssertEqual(decodedBlob, blobContent)
    }

    func testResourceContentsInvalid() {
        let data = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ResourceContents.self, from: data))
    }

    func testReadResourceResult() throws {
        let text = TextResourceContents(uri: "u", mimeType: "m", text: "t")
        let res = ReadResourceResult(_meta: Meta(progressToken: .string("p")), contents: [.text(text)])
        XCTAssertEqual(res.contents.count, 1)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(ReadResourceResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testResourceListChangedNotificationParams() throws {
        let params = ResourceListChangedNotificationParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ResourceListChangedNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testResourceUpdatedNotificationParams() throws {
        let params = ResourceUpdatedNotificationParams(_meta: Meta(progressToken: .string("p")), uri: "u")
        XCTAssertEqual(params.uri, "u")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ResourceUpdatedNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testSubscribeRequestParams() throws {
        let params = SubscribeRequestParams(_meta: Meta(progressToken: .string("p")), uri: "u")
        XCTAssertEqual(params.uri, "u")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(SubscribeRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testUnsubscribeRequestParams() throws {
        let params = UnsubscribeRequestParams(_meta: Meta(progressToken: .string("p")), uri: "u")
        XCTAssertEqual(params.uri, "u")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(UnsubscribeRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }
}
