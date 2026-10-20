/// Unit tests for Client SDK emission, CLI visitor parsing, and `SwiftASTParser` document merging.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `OpenAPIToSwiftGenerator`, `OpenAPIDocumentBuilder`, `CliVisitor`, and `SwiftASTParser`.
final class ClientSdkEmitTests: XCTestCase {
    /// Verifies emitting a Swift SDK from a minimal `OpenAPIDocument`.
    func testSdkEmit() {
        let doc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))])
        let code = OpenAPIToSwiftGenerator.generate(from: doc)
        XCTAssertTrue(code.contains("func getUsers("))

        let emptyDoc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: [:])
        XCTAssertNotNil(OpenAPIToSwiftGenerator.generateFiles(from: emptyDoc)["client.swift"])

        let opWithCallbacks = Operation(operationId: nil, callbacks: ["onEvent": [:]])
        let docWithCallbacks = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/test": PathItem(get: opWithCallbacks)])
        XCTAssertNotNil(OpenAPIToSwiftGenerator.generateFiles(from: docWithCallbacks, tests: true)["client.swift"])

        let traceItem = PathItem(additionalOperations: ["trace": Operation(operationId: "traceOp")])
        let traceDoc = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "API", version: "1.0"), paths: ["/trace": traceItem], security: [["auth": []]])
        XCTAssertNotNil(OpenAPIToSwiftGenerator.generateFiles(from: traceDoc, tests: true)["client.swift"])

        XCTAssertTrue(emitSDKCLI(document: OpenAPIDocument(openapi: "3.2.0", info: Info(title: "x", version: "1"))).contains("struct APIClientCLI"))
    }

    /// Verifies `OpenAPIDocumentBuilder` construction and JSON serialization.
    func testOpenAPIDocumentBuilder() throws {
        let builder = OpenAPIDocumentBuilder(title: "Test API", version: "2.0")
            .addPath("/test", item: PathItem(get: Operation(operationId: "getTest")))
            .addWebhook("hook", item: PathItem(post: Operation(operationId: "postHook")))
            .addSchema("MyModel", schema: Schema(type: "object"))
            .addSecurityScheme("BearerAuth", scheme: SecurityScheme(type: "http", scheme: "bearer"))

        let doc = builder.build()
        XCTAssertEqual(doc.info.title, "Test API")
        XCTAssertEqual(doc.info.version, "2.0")
        XCTAssertNotNil(doc.paths?["/test"])
        XCTAssertNotNil(doc.webhooks?["hook"])
        XCTAssertNotNil(doc.components?.schemas?["MyModel"])
        XCTAssertNotNil(doc.components?.securitySchemes?["BearerAuth"])

        let json = try builder.serialize()
        XCTAssertTrue(json.contains("Test API"))

        let emptyBuilt = OpenAPIDocumentBuilder(title: "Empty", version: "1.0").build()
        XCTAssertNil(emptyBuilt.paths)
    }

    /// Verifies `CliVisitor` extraction of CLI subcommands and options into OpenAPI paths.
    func testClientSdkCliParse() {
        let code = """
        struct GetUsersCommand: AsyncParsableCommand {
            @Option var id: Int
            @Option var name: String?
        }
        struct PostItemsCommand: AsyncParsableCommand {
            @Option var body: String
            @Option var formData: String
            @Option var multipartData: String
        }
        struct PutItemsCommand: AsyncParsableCommand {}
        struct DeleteItemsCommand: AsyncParsableCommand {}
        struct PatchItemsCommand: AsyncParsableCommand {}
        """
        let syntax = Parser.parse(source: code)
        let visitor = CliVisitor(viewMode: .all)
        visitor.walk(syntax)
        XCTAssertNotNil(visitor.paths["/getUsers"])
        XCTAssertNotNil(visitor.paths["/postItems"])
        XCTAssertNotNil(visitor.paths["/putItems"])
        XCTAssertNotNil(visitor.paths["/deleteItems"])
        XCTAssertNotNil(visitor.paths["/patchItems"])
    }

    /// Verifies `OpenAPIParser` error handling and `SwiftASTParser.parseDocument` merging of routes, mocks, servers, and callbacks.
    func testClientSdkParseAndMerge() throws {
        XCTAssertThrowsError(try OpenAPIParser.parse(json: "{ invalid json"))

        let code = """
        func getEvent() {}
        func postEvent() {}
        func putEvent() {}
        func deleteEvent() {}
        func patchEvent() {}

        func putfoo() {}
        func mockputfoo() {}
        func getbar() {}
        func mockgetbar() {}
        func deleteItem() {}
        func mockGetItem() {}
        func mockPutItem() {}
        func mockPostItem() {}

        app.get("server-only") { req in return "ok" }

        protocol GetEventCallbacks { func onEvent() }
        protocol PostEventCallbacks { func onEvent() }
        protocol PutEventCallbacks { func onEvent() }
        protocol DeleteEventCallbacks { func onEvent() }
        protocol PatchEventCallbacks { func onEvent() }
        """
        let doc = try SwiftASTParser().parseDocument(from: code)
        XCTAssertNotNil(doc.paths?["/putfoo"]?.put)
        XCTAssertNotNil(doc.paths?["/putfoo"]?.get)
        XCTAssertNotNil(doc.paths?["/getbar"]?.get)
        XCTAssertNotNil(doc.paths?["/server-only"]?.get)
        XCTAssertEqual(doc.components?.callbacks?.count, 5)
    }
}
