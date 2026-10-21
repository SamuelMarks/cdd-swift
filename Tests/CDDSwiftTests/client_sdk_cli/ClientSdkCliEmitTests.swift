/// Unit tests for `emitSDKCLI` CLI code generation.
@testable import CDDSwift
import SwiftParser
import XCTest

/// Test suite verifying `emitSDKCLI`.
final class ClientSdkCliEmitTests: XCTestCase {
    /// Verifies that `emitSDKCLI` produces syntactically valid Swift `ArgumentParser` commands.
    func testCliEmit() {
        let doc = OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "API", version: "1.0"),
            paths: ["/users": PathItem(get: Operation(operationId: "getUsers"))]
        )
        let code = emitSDKCLI(document: doc)
        XCTAssertTrue(code.contains("struct GetUsersCommand: AsyncParsableCommand"))
        XCTAssertTrue(code.contains("MCPCommand.self"))
        XCTAssertTrue(code.contains("struct MCPCommand: AsyncParsableCommand"))
        XCTAssertTrue(code.contains("Start the MCP server via stdio"))
        XCTAssertFalse(Parser.parse(source: code).hasError)

        let cliEdgeCaseSource = """
        struct APIClientCLI: AsyncParsableCommand {
            func helper() {}
            static let configuration = CommandConfiguration(commandName: "api", abstract: "Custom CLI", version: "2.0")
        }
        struct EdgeCommand: AsyncParsableCommand {
            @Flag var verbose = false
            @Option var (a, b) = ("1", "2")
            @Option var untypedOpt = "val"
        }
        """
        let visitor = CliVisitor(viewMode: .all)
        visitor.walk(Parser.parse(source: cliEdgeCaseSource))
        XCTAssertEqual(visitor.infoTitle, "Custom")
        XCTAssertEqual(visitor.infoVersion, "2.0")
        XCTAssertEqual(visitor.paths["/edge"]?.post?.parameters?.first?.name, "untypedOpt")
    }
}
