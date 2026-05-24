import XCTest
import SwiftParser
@testable import CDDSwift

final class ClientSdkParseBoosterTests: XCTestCase {
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OpenAPIParser.parse(json: "invalid json"))
    }

    func testMergeMockDocumentMissingMethods() throws {
        let swiftCode = """
        // Route for /putfoo
        func putfoo() {}
        // Mock for /putfoo
        func mockputfoo() {}

        // Route for /getbar
        func getbar() {}
        // Mock for /getbar
        func mockgetbar() {}

        // We also need operationId fallback for callbacks
        // RouteVisitor sets operationId = name. So operationId = "putfoo".
        // FunctionVisitor needs callbacks[""] to be present to inject into something without operationId.
        // Wait, RouteVisitor ALWAYS sets operationId = name. So it's never nil!
        // CliVisitor sets operationId = opId. Never nil!
        // MockVisitor sets operationId = name. Never nil!
        // How can an operation in finalPaths have operationId == nil?!
        // Only if we parse it from a generic OpenAPI document, but parseDocument only parses from Swift code!
        // Wait! In parseDocument:
        // if let getOp = updatedItem.get, let cb = functionVisitor.callbacks[getOp.operationId ?? ""]
        // getOp is created by our visitors. They ALWAYS set operationId.
        // So `getOp.operationId ?? ""` is dead code because operationId is never nil when generated from Swift code!
        // But what if we just test OpenAPIParser? We can't inject callbacks into OpenAPIParser output because injectCallbacks is local to SwiftASTParser and it's inline in parseDocument!
        """

        let parser = SwiftASTParser()
        let doc = try parser.parseDocument(from: swiftCode)

        XCTAssertNotNil(doc.paths?["/putfoo"]?.put)
        XCTAssertNotNil(doc.paths?["/putfoo"]?.get)

        XCTAssertNotNil(doc.paths?["/getbar"]?.get)
    }
}
