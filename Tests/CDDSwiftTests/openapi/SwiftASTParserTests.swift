import XCTest
@testable import CDDSwift

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
}
