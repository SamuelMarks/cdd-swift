@testable import CDDSwift
import XCTest

final class ValidationPropertyWrappersTests: XCTestCase {
    struct TestModel: Codable, Equatable {
        @Minimum(10) var minVal: Int = 15
        @Maximum(100) var maxVal: Int = 50
        @MinLength(5) var minLen: String = "hello"
        @MaxLength(10) var maxLen: String = "world"
        @CDDSwift.Pattern("^[a-z]+$") var pat: String = "abc"
    }

    func testValidationWrappers() throws {
        let model = TestModel()
        XCTAssertEqual(model.minVal, 15)
        XCTAssertEqual(model.maxVal, 50)
        XCTAssertEqual(model.minLen, "hello")
        XCTAssertEqual(model.maxLen, "world")
        XCTAssertEqual(model.pat, "abc")

        let encoder = JSONEncoder()
        let data = try encoder.encode(model)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestModel.self, from: data)

        XCTAssertEqual(decoded, model)
        XCTAssertEqual(decoded.minVal, 15)
        XCTAssertEqual(decoded.maxVal, 50)
        XCTAssertEqual(decoded.minLen, "hello")
        XCTAssertEqual(decoded.maxLen, "world")
        XCTAssertEqual(decoded.pat, "abc")

        // Validate passing boundaries
        try Minimum(wrappedValue: 10, 10).validate()
        try Maximum(wrappedValue: 100, 100).validate()
        try MinLength(wrappedValue: "12345", 5).validate()
        try MaxLength(wrappedValue: "12345", 10).validate()
        try CDDSwift.Pattern(wrappedValue: "abc", "^[a-z]+$").validate()

        // Validate failing boundaries
        XCTAssertThrowsError(try Minimum(wrappedValue: 5, 10).validate()) { err in
            XCTAssertEqual(err as? CDDError, .validationFailed(field: "Minimum", reason: "Value 5 is less than minimum 10"))
        }
        XCTAssertThrowsError(try Maximum(wrappedValue: 150, 100).validate()) { err in
            XCTAssertEqual(err as? CDDError, .validationFailed(field: "Maximum", reason: "Value 150 exceeds maximum 100"))
        }
        XCTAssertThrowsError(try MinLength(wrappedValue: "hi", 5).validate()) { err in
            XCTAssertEqual(err as? CDDError, .validationFailed(field: "MinLength", reason: "String length 2 is less than minimum 5"))
        }
        XCTAssertThrowsError(try MaxLength(wrappedValue: "01234567890", 10).validate()) { err in
            XCTAssertEqual(err as? CDDError, .validationFailed(field: "MaxLength", reason: "String length 11 exceeds maximum 10"))
        }
        XCTAssertThrowsError(try CDDSwift.Pattern(wrappedValue: "123", "^[a-z]+$").validate()) { err in
            XCTAssertEqual(err as? CDDError, .validationFailed(field: "Pattern", reason: "String '123' does not match pattern '^[a-z]+$'"))
        }
    }

    func testCDDErrorDescriptions() {
        let errors: [(CDDError, String)] = [
            (.invalidJSON("bad token"), "Invalid JSON: bad token"),
            (.utf8EncodingFailed, "Failed to encode string as UTF-8 data."),
            (.utf8DecodingFailed(path: "/a.txt"), "Could not decode file at /a.txt as UTF-8."),
            (.fileIOError(path: "/a.txt", operation: "read", errno: 2, message: "missing"), "File I/O error during read at /a.txt (errno 2): missing"),
            (.missingRequiredArgument("--input"), "Missing required argument: --input"),
            (.invalidURL("://bad"), "Invalid URL: ://bad"),
            (.unsupportedSchemaConstruct("custom"), "Unsupported schema construct: custom"),
            (.invalidReference("#/bad"), "Invalid reference: #/bad"),
            (.astParsingFailed("syntax"), "AST parsing failed: syntax"),
            (.codeGenerationFailed("emit"), "Code generation failed: emit"),
            (.mcpTransportError("closed"), "MCP transport error: closed"),
            (.jsonRpcError(code: -32600, message: "invalid"), "JSON-RPC error (-32600): invalid"),
            (.processExecutionFailed(executable: "/bin/x", message: "missing"), "Process execution failed for /bin/x: missing"),
            (.validationFailed(field: "age", reason: "< 0"), "Validation failed for 'age': < 0"),
            (.fileSystemError(operation: "open", path: "/tmp/x", errnoCode: 13), "File system error during open at '/tmp/x' (errno 13)"),
            (.commandExecutionFailed(command: "build", reason: "exit 1"), "Command 'build' failed: exit 1"),
            (.unsupportedSpecificationVersion(spec: "OpenAPI", version: "1.0"), "Unsupported OpenAPI specification version: 1.0"),
            (.mcpToolNotFound(name: "unknownTool"), "Unknown MCP tool: 'unknownTool'"),
            (.mcpResourceNotFound(uri: "api://missing"), "Unknown MCP resource URI: 'api://missing'"),
            (.jsonEncodingFailed(reason: "nan"), "JSON encoding failed: nan"),
            (.jsonDecodingFailed(reason: "eof"), "JSON decoding failed: eof")
        ]
        for (error, expected) in errors {
            XCTAssertEqual(error.description, expected)
            XCTAssertEqual(error.errorDescription, expected)
        }
        XCTAssertEqual(lastPathSegment("#/components/schemas/User"), "User")
        XCTAssertEqual(lastPathSegment("SimpleName"), "SimpleName")
    }
}
