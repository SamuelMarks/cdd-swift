@testable import CDDSwift
import XCTest

final class SwiftASTParserTests: XCTestCase {
    func testParseModels() throws {
        let swiftCode = """
        import Foundation

        struct User: Codable {
            let id: UUID
            let name: String
            let age: Int?
            let tags: [String]
        }

        struct NotAModel {
            let ignoreMe: String
        }
        """

        let parser = SwiftASTParser()
        let schemas = try parser.parseModels(from: swiftCode)

        XCTAssertEqual(schemas.count, 1) // Should ignore NotAModel
        XCTAssertNotNil(schemas["User"])

        let userSchema = schemas["User"]!
        XCTAssertEqual(userSchema.type, "object")
        XCTAssertEqual(userSchema.required?.count, 3)
        XCTAssertTrue(userSchema.required?.contains("id") ?? false)
        XCTAssertTrue(userSchema.required?.contains("name") ?? false)
        XCTAssertTrue(userSchema.required?.contains("tags") ?? false)

        XCTAssertEqual(userSchema.properties?["id"]?.type, "string")
        XCTAssertEqual(userSchema.properties?["id"]?.format, "uuid")
        XCTAssertEqual(userSchema.properties?["name"]?.type, "string")
        XCTAssertEqual(userSchema.properties?["age"]?.type, "integer")
        XCTAssertEqual(userSchema.properties?["tags"]?.type, "array")
        XCTAssertEqual(userSchema.properties?["tags"]?.items?.type, "string")
    }

    func testParseWebhooksAndCallbacks() throws {
        let swiftCode = """
        import Foundation

        public protocol WebhooksDelegate {
            func onOrderPlaced(payload: AnyCodable)
        }

        public protocol OrderCallbacks {
            func onPaymentSuccess(payload: AnyCodable)
        }
        """

        let parser = SwiftASTParser()
        let document = try parser.parseDocument(from: swiftCode)

        XCTAssertNotNil(document.webhooks)
        XCTAssertEqual(document.webhooks?.count, 1)
        XCTAssertNotNil(document.webhooks?["orderplaced"])

        let components = document.components
        XCTAssertNotNil(components?.callbacks)
        XCTAssertEqual(components?.callbacks?.count, 1)
        XCTAssertNotNil(components?.callbacks?["order"])
    }

    func testParseSecurityAndLinks() throws {
        let swiftCode = """
        import Foundation

        struct APIClient {
            var bearerToken: String?
            var apiKeyToken: String?
            var myOAuthToken: String?
        }

        /// Get user profile
        /// @link getUserSettings -> getSettings
        func getProfile() {

        }
        """

        let parser = SwiftASTParser()
        let document = try parser.parseDocument(from: swiftCode)

        XCTAssertNotNil(document.components?.securitySchemes)
        XCTAssertEqual(document.components?.securitySchemes?.count, 3)
        XCTAssertEqual(document.components?.securitySchemes?["bearer"]?.type, "http")
        XCTAssertEqual(document.components?.securitySchemes?["apiKey"]?.type, "apiKey")
        XCTAssertEqual(document.components?.securitySchemes?["myOAuth"]?.type, "oauth2")

        XCTAssertNotNil(document.security)
        XCTAssertEqual(document.security?.count, 3)

        let path = document.paths?["/getProfile"]
        XCTAssertNotNil(path)
        let getOp = path?.get
        XCTAssertNotNil(getOp?.responses?["200"]?.links)
        XCTAssertEqual(getOp?.responses?["200"]?.links?["getUserSettings"]?.operationId, "getSettings")
    }
}
