import XCTest
@testable import CDDSwift

final class DocsJsonGeneratorTests: XCTestCase {
    
    func testDocsJsonGeneration() throws {
        let builder = OpenAPIDocumentBuilder(title: "Sample API", version: "1.0.0")
            .addPath("/test", item: PathItem(
                get: Operation(operationId: "getTest")
            ))
        let document = builder.build()
        
        // 1. Full Output
        let fullJsonStr = DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: true)
        let fullData = fullJsonStr.data(using: .utf8)!
        let fullOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: fullData)
        
        XCTAssertEqual(fullOutputs.count, 1)
        XCTAssertEqual(fullOutputs[0].language, "swift")
        XCTAssertEqual(fullOutputs[0].operations.count, 1)
        
        let fullCode = fullOutputs[0].operations[0].code
        XCTAssertNotNil(fullCode.imports)
        XCTAssertNotNil(fullCode.wrapper_start)
        XCTAssertNotNil(fullCode.wrapper_end)
        XCTAssertTrue(fullCode.snippet.contains("URLSession"))
        
        // 2. No Imports
        let noImportsJsonStr = DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: true)
        let noImportsData = noImportsJsonStr.data(using: .utf8)!
        let noImportsOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: noImportsData)
        
        let noImportsCode = noImportsOutputs[0].operations[0].code
        XCTAssertNil(noImportsCode.imports)
        XCTAssertNotNil(noImportsCode.wrapper_start)
        XCTAssertNotNil(noImportsCode.wrapper_end)
        
        // 3. No Wrapping
        let noWrappingJsonStr = DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: false)
        let noWrappingData = noWrappingJsonStr.data(using: .utf8)!
        let noWrappingOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: noWrappingData)
        
        let noWrappingCode = noWrappingOutputs[0].operations[0].code
        XCTAssertNotNil(noWrappingCode.imports)
        XCTAssertNil(noWrappingCode.wrapper_start)
        XCTAssertNil(noWrappingCode.wrapper_end)
        
        // 4. No Imports & No Wrapping
        let minJsonStr = DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: false)
        let minData = minJsonStr.data(using: .utf8)!
        let minOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: minData)
        
        let minCode = minOutputs[0].operations[0].code
        XCTAssertNil(minCode.imports)
        XCTAssertNil(minCode.wrapper_start)
        XCTAssertNil(minCode.wrapper_end)
        XCTAssertTrue(minCode.snippet.contains("URLSession"))
    }
}
