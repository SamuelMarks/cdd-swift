import XCTest
@testable import CDDSwift

final class MCPToolModelsTests: XCTestCase {
    func testToolInputSchema() throws {
        let schema = ToolInputSchema(type: "object", properties: ["foo": AnyCodable("bar")], required: ["foo"])
        XCTAssertEqual(schema.type, "object")
        XCTAssertEqual(schema.required, ["foo"])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(schema)
        let decoded = try decoder.decode(ToolInputSchema.self, from: data)
        XCTAssertEqual(decoded, schema)
    }

    func testTool() throws {
        let schema = ToolInputSchema(type: "object")
        let tool = Tool(name: "myTool", description: "Does things", inputSchema: schema)
        XCTAssertEqual(tool.name, "myTool")
        XCTAssertEqual(tool.description, "Does things")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(tool)
        let decoded = try decoder.decode(Tool.self, from: data)
        XCTAssertEqual(decoded, tool)
    }

    func testCallToolRequestParams() throws {
        let params = CallToolRequestParams(_meta: Meta(progressToken: .string("p")), name: "myTool", arguments: ["arg": AnyCodable(1)])
        XCTAssertEqual(params.name, "myTool")
        XCTAssertEqual(params.arguments?["arg"]?.value as? Int, 1)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(CallToolRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testCallToolResult() throws {
        let res = CallToolResult(_meta: Meta(progressToken: .string("p")), content: [AnyCodable("hello")], isError: true)
        XCTAssertEqual(res.isError, true)
        XCTAssertEqual(res.content.first?.value as? String, "hello")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(CallToolResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testListToolsRequestParams() throws {
        let params = ListToolsRequestParams(_meta: Meta(progressToken: .integer(1)), cursor: "next")
        XCTAssertEqual(params.cursor, "next")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ListToolsRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testListToolsResult() throws {
        let tool = Tool(name: "tool1", inputSchema: ToolInputSchema(type: "object"))
        let res = ListToolsResult(_meta: Meta(progressToken: .integer(1)), nextCursor: "n1", tools: [tool])
        XCTAssertEqual(res.nextCursor, "n1")
        XCTAssertEqual(res.tools.count, 1)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(res)
        let decoded = try decoder.decode(ListToolsResult.self, from: data)
        XCTAssertEqual(decoded, res)
    }

    func testToolListChangedNotificationParams() throws {
        let params = ToolListChangedNotificationParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ToolListChangedNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }
}
