/// Unit tests for OpenAPI validation property wrappers (`@Minimum`, `@Maximum`, `@MinLength`, `@MaxLength`, `@Pattern`) and `CDDError`
/// descriptions.
@testable import CDDSwift
import XCTest

/// Test suite verifying validation property wrappers and `CDDError` formatting.
final class ValidationPropertyWrappersTests: XCTestCase {
    /// Sample model exercising all validation property wrappers.
    struct TestModel: Codable, Equatable {
        /// Minimum integer value property.
        @Minimum(10) var minVal: Int = 15
        /// Maximum integer value property.
        @Maximum(100) var maxVal: Int = 50
        /// Minimum string length property.
        @MinLength(5) var minLen: String = "hello"
        /// Maximum string length property.
        @MaxLength(10) var maxLen: String = "world"
        /// Regex pattern constrained property.
        @CDDSwift.Pattern("^[a-z]+$") var pat: String = "abc"
    }

    /// Verifies `Codable` round-tripping and boundary validation of all validation property wrappers.
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

    /// Verifies `description` and `errorDescription` across all `CDDError` cases.
    func testCDDErrorDescriptions() {
        let errors: [(CDDError, String)] = [
            (.invalidJSON("bad token"), "Invalid JSON: bad token"),
            (.utf8DecodingFailed(path: "/a.txt"), "Could not decode file at /a.txt as UTF-8."),
            (
                .fileIOError(path: "/a.txt", operation: "read", errno: 2, message: "missing"),
                "File I/O error during read at /a.txt (errno 2): missing"
            ),
            (.mcpTransportError("closed"), "MCP transport error: closed"),
            (.processExecutionFailed(executable: "/bin/x", message: "missing"), "Process execution failed for /bin/x: missing"),
            (.validationFailed(field: "age", reason: "< 0"), "Validation failed for 'age': < 0"),
            (.arazzoValidationError("missing workflows"), "Arazzo validation error: missing workflows"),
            (
                .arazzoExpressionEvaluationError(expression: "$url", context: "nil"),
                "Arazzo expression evaluation error for '$url' in context 'nil'"
            ),
            (.arazzoStepExecutionFailed(stepId: "step1", reason: "500"), "Arazzo step execution failed for 'step1': 500"),
            (.arazzoWorkflowNotFound("wf1"), "Arazzo workflow not found: 'wf1'"),
            (.arazzoCircularDependency(workflowId: "wf2"), "Arazzo circular dependency detected involving workflow 'wf2'")
        ]
        for (error, expected) in errors {
            XCTAssertEqual(error.description, expected)
            XCTAssertEqual(error.errorDescription, expected)
        }
        XCTAssertEqual(lastPathSegment("#/components/schemas/User"), "User")
        XCTAssertEqual(lastPathSegment("SimpleName"), "SimpleName")
    }
}
