/// Unit tests for `DocsJsonGenerator` snippet generation and options.
@testable import CDDSwift
import XCTest

/// Test suite verifying `DocsJsonGenerator` across server configurations and wrapping/import flags.
final class DocsJsonGeneratorTests: XCTestCase {
    /// Verifies generating Docs JSON with and without imports, wrappers, and custom servers.
    func testDocsJsonGeneration() throws {
        let builder = OpenAPIDocumentBuilder(title: "Sample API", version: "1.0.0")
            .addPath("/test", item: PathItem(
                get: Operation(operationId: "getTest"),
                post: Operation(operationId: "postTest")
            ))
        let document = builder.build()

        // 1. Full Output
        let fullJsonStr = DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: true)
        let fullData = try XCTUnwrap(fullJsonStr.data(using: .utf8))
        let fullOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: fullData)

        XCTAssertEqual(fullOutputs.count, 1)
        XCTAssertEqual(fullOutputs[0].language, "swift")
        XCTAssertEqual(fullOutputs[0].operations.count, 2)

        let fullCode = fullOutputs[0].operations[0].code
        XCTAssertNotNil(fullCode.imports)
        XCTAssertNotNil(fullCode.wrapper_start)
        XCTAssertNotNil(fullCode.wrapper_end)
        XCTAssertTrue(fullCode.snippet.contains("URLSession"))

        // 2. No Imports
        let noImportsJsonStr = DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: true)
        let noImportsData = try XCTUnwrap(noImportsJsonStr.data(using: .utf8))
        let noImportsOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: noImportsData)

        let noImportsCode = noImportsOutputs[0].operations[0].code
        XCTAssertNil(noImportsCode.imports)
        XCTAssertNotNil(noImportsCode.wrapper_start)
        XCTAssertNotNil(noImportsCode.wrapper_end)

        // 3. No Wrapping
        let noWrappingJsonStr = DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: false)
        let noWrappingData = try XCTUnwrap(noWrappingJsonStr.data(using: .utf8))
        let noWrappingOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: noWrappingData)

        let noWrappingCode = noWrappingOutputs[0].operations[0].code
        XCTAssertNotNil(noWrappingCode.imports)
        XCTAssertNil(noWrappingCode.wrapper_start)
        XCTAssertNil(noWrappingCode.wrapper_end)

        // 4. No Imports & No Wrapping
        let minJsonStr = DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: false)
        let minData = try XCTUnwrap(minJsonStr.data(using: .utf8))
        let minOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: minData)

        let minCode = minOutputs[0].operations[0].code
        XCTAssertNil(minCode.imports)
        XCTAssertNil(minCode.wrapper_start)
        XCTAssertNil(minCode.wrapper_end)
        XCTAssertTrue(minCode.snippet.contains("URLSession"))

        // 5. Default Arguments
        let defaultJsonStr = DocsJsonGenerator.generate(from: document)
        let defaultData = try XCTUnwrap(defaultJsonStr.data(using: .utf8))
        let defaultOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: defaultData)
        XCTAssertEqual(defaultOutputs.count, 1)
        XCTAssertEqual(defaultOutputs[0].operations.count, 2)

        // 6. Mixed Default Arguments
        let mixed1 = DocsJsonGenerator.generate(from: document, includeImports: false)
        let mixed2 = DocsJsonGenerator.generate(from: document, includeWrapping: false)
        XCTAssertNotEqual(mixed1, mixed2)
    }

    /// Verifies generating Docs JSON for custom server URLs, anonymous operations, and empty paths.
    func testDocsJsonCustomServerAndEmptyPaths() throws {
        let docWithServer = OpenAPIDocument(
            openapi: "3",
            info: Info(title: "test", version: "1"),
            servers: [Server(url: "https://custom.url")],
            paths: ["/anon": PathItem(get: Operation(operationId: nil))]
        )
        let serverJsonStr = DocsJsonGenerator.generate(from: docWithServer)
        let serverOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(serverJsonStr.utf8))
        XCTAssertEqual(serverOutputs.count, 1)
        XCTAssertEqual(serverOutputs[0].operations.count, 1)
        XCTAssertNil(serverOutputs[0].operations[0].operationId)
        XCTAssertEqual(serverOutputs[0].operations[0].path, "/anon")
        XCTAssertTrue(serverOutputs[0].operations[0].code.snippet.contains("https://custom.url/anon"))
        XCTAssertTrue(serverOutputs[0].operations[0].code.wrapper_start?.contains("func get_anon()") == true)

        let docNilPaths = OpenAPIDocument(openapi: "3", info: Info(title: "test", version: "1"), paths: nil)
        let nilPathsJsonStr = DocsJsonGenerator.generate(from: docNilPaths)
        let nilPathsOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(nilPathsJsonStr.utf8))
        XCTAssertEqual(nilPathsOutputs.count, 1)
        XCTAssertTrue(nilPathsOutputs[0].operations.isEmpty)
    }
}
