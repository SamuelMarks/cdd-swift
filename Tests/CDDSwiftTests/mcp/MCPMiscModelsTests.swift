import XCTest
@testable import CDDSwift

final class MCPMiscModelsTests: XCTestCase {
    func testAnnotated() throws {
        let annotated = Annotated(annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(annotated.annotations?["a"]?.value as? String, "b")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(annotated)
        let decoded = try decoder.decode(Annotated.self, from: data)
        XCTAssertEqual(decoded, annotated)
    }

    func testCancelledNotificationParams() throws {
        let params = CancelledNotificationParams(requestId: .string("1"), reason: "Timeout")
        XCTAssertEqual(params.requestId, .string("1"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(CancelledNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testProgressNotificationParams() throws {
        let params = ProgressNotificationParams(progressToken: .integer(1), progress: 0.5, total: 1.0)
        XCTAssertEqual(params.progress, 0.5)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ProgressNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testPaginatedRequestParams() throws {
        let params = PaginatedRequestParams(cursor: "c")
        XCTAssertEqual(params.cursor, "c")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(PaginatedRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testPaginatedResult() throws {
        let result = PaginatedResult(_meta: Meta(progressToken: .string("p")), nextCursor: "n")
        XCTAssertEqual(result.nextCursor, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(PaginatedResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testPingRequestParams() throws {
        let params = PingRequestParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(PingRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testTextContent() throws {
        let text = TextContent(text: "Hello", annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(text.text, "Hello")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(text)
        let decoded = try decoder.decode(TextContent.self, from: data)
        XCTAssertEqual(decoded, text)
    }

    func testImageContent() throws {
        let img = ImageContent(data: "base64", mimeType: "image/png", annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(img.data, "base64")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(img)
        let decoded = try decoder.decode(ImageContent.self, from: data)
        XCTAssertEqual(decoded, img)
    }

    func testEmbeddedResource() throws {
        let resource = EmbeddedResource(resource: .text(TextResourceContents(uri: "u", mimeType: "m", text: "t")), annotations: ["a": AnyCodable("b")])
        XCTAssertEqual(resource.type, "resource")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(resource)
        let decoded = try decoder.decode(EmbeddedResource.self, from: data)
        XCTAssertEqual(decoded, resource)
    }

    func testSetLevelRequestParams() throws {
        let params = SetLevelRequestParams(level: .debug)
        XCTAssertEqual(params.level, .debug)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(SetLevelRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testLoggingMessageNotificationParams() throws {
        let params = LoggingMessageNotificationParams(level: .info, logger: "main", data: AnyCodable("msg"))
        XCTAssertEqual(params.level, .info)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(LoggingMessageNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testPromptArgument() throws {
        let arg = PromptArgument(name: "n", description: "d", required: true)
        XCTAssertEqual(arg.name, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(arg)
        let decoded = try decoder.decode(PromptArgument.self, from: data)
        XCTAssertEqual(decoded, arg)
    }

    func testPrompt() throws {
        let prompt = Prompt(name: "p", description: "d", arguments: [PromptArgument(name: "n")])
        XCTAssertEqual(prompt.name, "p")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(prompt)
        let decoded = try decoder.decode(Prompt.self, from: data)
        XCTAssertEqual(decoded, prompt)
    }

    func testPromptMessage() throws {
        let textContent = TextContent(text: "hello")
        let msg = PromptMessage(role: .user, content: .text(textContent))
        XCTAssertEqual(msg.role, .user)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(PromptMessage.self, from: data)
        XCTAssertEqual(decoded, msg)

        let imgContent = ImageContent(data: "d", mimeType: "m")
        let msg2 = PromptMessage(role: .assistant, content: .image(imgContent))
        let data2 = try encoder.encode(msg2)
        let decoded2 = try decoder.decode(PromptMessage.self, from: data2)
        XCTAssertEqual(decoded2, msg2)

        let resContent = EmbeddedResource(resource: .text(TextResourceContents(uri: "u", text: "t")))
        let msg3 = PromptMessage(role: .assistant, content: .resource(resContent))
        let data3 = try encoder.encode(msg3)
        let decoded3 = try decoder.decode(PromptMessage.self, from: data3)
        XCTAssertEqual(decoded3, msg3)
    }

    func testPromptMessageContentInvalid() {
        let data = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(PromptMessageContent.self, from: data))
    }

    func testPromptReference() throws {
        let ref = PromptReference(name: "p")
        XCTAssertEqual(ref.name, "p")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(ref)
        let decoded = try decoder.decode(PromptReference.self, from: data)
        XCTAssertEqual(decoded, ref)
    }

    func testGetPromptRequestParams() throws {
        let params = GetPromptRequestParams(name: "n", arguments: ["a": "b"])
        XCTAssertEqual(params.name, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(GetPromptRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testGetPromptResult() throws {
        let result = GetPromptResult(_meta: Meta(progressToken: .string("p")), description: "d", messages: [PromptMessage(role: .user, content: .text(TextContent(text: "t")))])
        XCTAssertEqual(result.description, "d")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(GetPromptResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testListPromptsRequestParams() throws {
        let params = ListPromptsRequestParams(cursor: "c")
        XCTAssertEqual(params.cursor, "c")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ListPromptsRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testListPromptsResult() throws {
        let result = ListPromptsResult(_meta: Meta(progressToken: .string("p")), nextCursor: "n", prompts: [Prompt(name: "p")])
        XCTAssertEqual(result.nextCursor, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(ListPromptsResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testPromptListChangedNotificationParams() throws {
        let params = PromptListChangedNotificationParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(PromptListChangedNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testRoot() throws {
        let root = Root(uri: "u", name: "n")
        XCTAssertEqual(root.uri, "u")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(root)
        let decoded = try decoder.decode(Root.self, from: data)
        XCTAssertEqual(decoded, root)
    }

    func testListRootsRequestParams() throws {
        let params = ListRootsRequestParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(ListRootsRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testListRootsResult() throws {
        let result = ListRootsResult(_meta: Meta(progressToken: .string("p")), roots: [Root(uri: "u")])
        XCTAssertEqual(result.roots.count, 1)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(ListRootsResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testRootsListChangedNotificationParams() throws {
        let params = RootsListChangedNotificationParams(_meta: Meta(progressToken: .string("p")))
        XCTAssertEqual(params._meta?.progressToken, .string("p"))
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(RootsListChangedNotificationParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testCompleteRequestParams() throws {
        let ref = CompleteReference.prompt(PromptReference(name: "p"))
        let arg = CompleteRequestParams.CompleteArgument(name: "n", value: "v")
        let params = CompleteRequestParams(ref: ref, argument: arg)
        XCTAssertEqual(params.argument.name, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(CompleteRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)

        let ref2 = CompleteReference.resource(ResourceReference(uri: "u"))
        let params2 = CompleteRequestParams(ref: ref2, argument: arg)
        let data2 = try encoder.encode(params2)
        let decoded2 = try decoder.decode(CompleteRequestParams.self, from: data2)
        XCTAssertEqual(decoded2, params2)
    }

    func testCompleteReferenceInvalid() {
        let data = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(CompleteReference.self, from: data))
    }

    func testResourceReference() throws {
        let ref = ResourceReference(uri: "u")
        XCTAssertEqual(ref.uri, "u")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(ref)
        let decoded = try decoder.decode(ResourceReference.self, from: data)
        XCTAssertEqual(decoded, ref)
    }

    func testCompleteResult() throws {
        let completion = CompleteResult.Completion(values: ["v1", "v2"], total: 2, hasMore: false)
        let result = CompleteResult(_meta: Meta(progressToken: .string("p")), completion: completion)
        XCTAssertEqual(result.completion.values, ["v1", "v2"])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(CompleteResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testSamplingMessage() throws {
        let msg = SamplingMessage(role: .assistant, content: .text(TextContent(text: "t")))
        XCTAssertEqual(msg.role, .assistant)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(SamplingMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func testModelHint() throws {
        let hint = ModelHint(name: "n")
        XCTAssertEqual(hint.name, "n")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(hint)
        let decoded = try decoder.decode(ModelHint.self, from: data)
        XCTAssertEqual(decoded, hint)
    }

    func testModelPreferences() throws {
        let prefs = ModelPreferences(hints: [ModelHint(name: "n")], costPriority: 1.0, speedPriority: 0.5, intelligencePriority: 0.8)
        XCTAssertEqual(prefs.costPriority, 1.0)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(prefs)
        let decoded = try decoder.decode(ModelPreferences.self, from: data)
        XCTAssertEqual(decoded, prefs)
    }

    func testCreateMessageRequestParams() throws {
        let msg = SamplingMessage(role: .user, content: .text(TextContent(text: "t")))
        let prefs = ModelPreferences(hints: [ModelHint(name: "n")])
        let params = CreateMessageRequestParams(messages: [msg], modelPreferences: prefs, systemPrompt: "s", includeContext: "i", temperature: 0.7, maxTokens: 100, stopSequences: ["stop"], metadata: ["a": AnyCodable("b")])
        XCTAssertEqual(params.maxTokens, 100)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(params)
        let decoded = try decoder.decode(CreateMessageRequestParams.self, from: data)
        XCTAssertEqual(decoded, params)
    }

    func testCreateMessageResult() throws {
        let result = CreateMessageResult(_meta: Meta(progressToken: .string("p")), role: .assistant, content: .text(TextContent(text: "t")), model: "m", stopReason: "stop")
        XCTAssertEqual(result.model, "m")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(CreateMessageResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
