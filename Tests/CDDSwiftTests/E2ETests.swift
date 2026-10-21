/// End-to-end integration tests verifying OpenAPI and Arazzo round-trips across Swift code generators and AST parsers.
@testable import CDDSwift
import SwiftParser
import SwiftSyntax
import XCTest

/// Test suite verifying end-to-end OpenAPI and Arazzo generation and AST parsing round-trips.
final class E2ETests: XCTestCase {
    /// Verifies generating Swift models and client routes from `example-openapi.json` and parsing them back via `SwiftASTParser`.
    func testE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("example-openapi.json")
        let json = try String(contentsOfFile: fileURL.path, encoding: .utf8)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let syntax = Parser.parse(source: swiftCode)
        XCTAssertFalse(syntax.hasError)
        let schemas = try SwiftASTParser().parseModels(from: swiftCode)
        XCTAssertGreaterThan(schemas.count, 0)
        let expectedSchemas = try XCTUnwrap(document.components?.schemas)
        for schemaName in expectedSchemas.keys {
            XCTAssertNotNil(schemas[schemaName])
        }
    }

    /// Verifies generating SDK, CLI, and server code from `comprehensive-openapi.json` and round-tripping through `SwiftASTParser`.
    func testComprehensiveE2E() throws {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent("comprehensive-openapi.json")
        let json = try String(contentsOfFile: fileURL.path, encoding: .utf8)
        let document = try OpenAPIParser.parse(json: json)
        let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
        let cliCode = emitSDKCLI(document: document)
        let serverCode = emitServer(document: document)

        XCTAssertFalse(Parser.parse(source: swiftCode).hasError)
        XCTAssertFalse(Parser.parse(source: cliCode).hasError)
        XCTAssertFalse(Parser.parse(source: serverCode).hasError)

        // This will test the parsing of all generated code components
        let combinedCode = swiftCode + "\n" + cliCode + "\n" + serverCode
        let parsedDoc = try SwiftASTParser().parseDocument(from: combinedCode)

        let schemas = try XCTUnwrap(parsedDoc.components?.schemas)
        XCTAssertGreaterThan(schemas.count, 0)
        XCTAssertNotNil(parsedDoc.paths)
    }

    /// Verifies `SwiftASTParser.parseDocument(from:)` on combined model, mock, and route functions.
    func testParseDocument() throws {
        let code = """
        struct MyModel: Codable { let id: String }
        func mockGetUsers() {}
        func mockUsers() {}
        func getRoute() {}
        """
        let doc = try SwiftASTParser().parseDocument(from: code)
        XCTAssertNotNil(doc.components?.schemas?["MyModel"])
        XCTAssertNotNil(doc.paths?["/users"])
        XCTAssertNotNil(doc.paths?["/getRoute"])
    }

    /// Verifies that overlapping route and mock functions preserve both operations on `paths`.
    func testOverlapParse() throws {
        let code = """
        func getUsers() {}
        func mockUsers() {}
        """
        let doc = try SwiftASTParser().parseDocument(from: code)
        XCTAssertNotNil(doc.paths?["/users"]?.get)
        XCTAssertNotNil(doc.paths?["/getUsers"]?.get)
    }

    /// Verifies that `OpenAPIParser.parse` throws on an empty JSON object.
    func testEmptyJSONParse() {
        let json = "{}"
        XCTAssertThrowsError(try OpenAPIParser.parse(json: json))
    }

    /// Verifies Arazzo 1.1.0 SDK, CLI, Server, and Test emission syntax validity and AST round-tripping.
    func testArazzoRoundTripAndSyntaxValidity() throws {
        let step1 = ArazzoStep(
            stepId: "loginStep",
            operationId: "loginUser",
            successCriteria: [ArazzoCriterion(context: "$statusCode", condition: "== 200")],
            onFailure: [ArazzoFailureAction(name: "retryOnFailure", type: .retry, retryAfter: 1.0, retryLimit: 2)],
            outputs: ["token": AnyCodable("$response.body#/token")]
        )
        let wf = ArazzoWorkflow(
            workflowId: "authFlow",
            summary: "Authenticate user",
            inputs: Schema(type: "object", properties: ["username": Schema(type: "string")], required: ["username"]),
            steps: [step1],
            outputs: ["sessionToken": AnyCodable("$steps.loginStep.outputs.token")]
        )
        let spec = ArazzoSpecification(
            info: ArazzoInfo(title: "Auth Workflows", version: "1.0.0"),
            sourceDescriptions: [ArazzoSourceDescription(name: "authApi", url: "https://api.example.com/openapi.json", type: .openapi)],
            workflows: [wf]
        )

        let sdkCode = ArazzoSdkEmitter.emitWorkflowClient(from: spec)
        let cliCode = ArazzoCliEmitter.emitWorkflowCLI(from: spec)
        let serverCode = ArazzoServerEmitter.emitServerOrchestrator(from: spec)
        let testCode = ArazzoTestEmitter.emitTestSuite(from: spec)

        XCTAssertFalse(Parser.parse(source: sdkCode).hasError)
        XCTAssertFalse(Parser.parse(source: cliCode).hasError)
        XCTAssertFalse(Parser.parse(source: serverCode).hasError)
        XCTAssertFalse(Parser.parse(source: testCode).hasError)

        let parsedFromSdk = try SwiftASTArazzoParser().parseSpecification(from: sdkCode)
        XCTAssertEqual(parsedFromSdk.workflows.first?.workflowId, "authFlow")
        XCTAssertEqual(parsedFromSdk.workflows.first?.steps.first?.stepId, "loginStep")
        XCTAssertEqual(parsedFromSdk.workflows.first?.steps.first?.operationId, "loginUser")
        XCTAssertEqual(parsedFromSdk.workflows.first?.steps.first?.onFailure?.first?.retryLimit, 2)
    }
}
