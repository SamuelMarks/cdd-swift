/// Unit tests for `GenerateOpenAPI`, `MergeSwift`, `ToOpenAPI`, `SyncOpenAPI`, and `WASIFileHelpers`.
import ArgumentParser
@testable import CDDSwift
@testable import cdd_swift_cli
import Foundation
import SwiftParser
import XCTest

extension CDDSwiftCliTests {
    /// Verifies `GenerateOpenAPI` command execution to file and stdout.
    func testGenerateOpenAPI() async throws {
        let outJson = tempPath("cdd-test-out.json")
        var cmd = try GenerateOpenAPI.parse(["-o", outJson])
        try await cmd.run()
        let doc = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: outJson))
        XCTAssertEqual(doc.info.title, "Sample CDD API")
        XCTAssertNotNil(doc.paths?["/users"]?.get)
        XCTAssertNotNil(doc.components?.schemas?["User"])

        var cmdStdout = try GenerateOpenAPI.parse([])
        try await cmdStdout.run()
    }

    /// Verifies `MergeSwift` command execution and missing destination error handling.
    func testMergeSwift() async throws {
        let emptyJson = tempPath("cdd_test_empty.json")
        let dummySwift = tempPath("cdd_test_dummy.swift")
        var cmd = try MergeSwift.parse(["-i", emptyJson, "-o", dummySwift])
        try await cmd.run()
        let merged = try WASIFileHelpers.readString(at: dummySwift)
        XCTAssertFalse(Parser.parse(source: merged).hasError)

        var cmdMissing = try MergeSwift.parse(["-i", emptyJson, "-o", tempPath("cdd_test_dummy_missing.swift")])
        let missingRes: Void? = try? await cmdMissing.run()
        XCTAssertNil(missingRes)
    }

    /// Verifies `ToOpenAPI` command execution across files, directories, and stdout.
    func testToOpenAPI() async throws {
        let dummySwift = tempPath("cdd_test_dummy.swift")
        let out1 = tempPath("out.json")
        let out2 = tempPath("out2.json")
        var cmd = try ToOpenAPI.parse(["--input", dummySwift, "-o", out1])
        try await cmd.run()
        let doc1 = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: out1))
        XCTAssertNotNil(doc1.components?.schemas?["Dummy"])

        var cmdDir = try ToOpenAPI.parse(["--input", tempPath("cdd_test_dir/non_existent.swift"), "-o", out2])
        try await cmdDir.run()
        let doc2 = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: out2))
        XCTAssertNotNil(doc2.components?.schemas?["Dummy2"])

        var cmdStdout = try ToOpenAPI.parse(["--input", dummySwift])
        try await cmdStdout.run()

        var cmdMissing = try ToOpenAPI.parse(["--input", tempPath("non_existent_dir_123_456/non_existent_file.swift")])
        let missingRes: Void? = try? await cmdMissing.run()
        XCTAssertNil(missingRes)
    }

    /// Verifies `SyncOpenAPI` merging of existing paths and schemas with Swift AST paths and schemas.
    func testSyncOpenAPIMergeAndPaths() async throws {
        let existingJSON = """
        {
          "openapi": "3.1.0",
          "info": { "title": "Test API", "version": "1.0.0" },
          "paths": { "/existing": { "get": { "operationId": "getExisting", "responses": { "200": { "description": "OK" } } } } },
          "components": { "schemas": { "ExistingSchema": { "type": "string" } } }
        }
        """
        let syncMergePath = tempPath("sync_merge.json")
        let syncSwiftPath = tempPath("sync_swift.swift")
        try WASIFileHelpers.writeString(existingJSON, to: syncMergePath)
        let swiftCode = """
        struct NewSchema: Codable {
            let id: String
        }
        """
        try WASIFileHelpers.writeString(swiftCode, to: syncSwiftPath)
        var cmd = try SyncOpenAPI.parse(["--truth", "class", "--input", syncSwiftPath, "-o", syncMergePath])
        try await cmd.run()

        let merged = try WASIFileHelpers.readString(at: syncMergePath)
        let mergedDoc = try OpenAPIParser.parse(json: merged)
        XCTAssertNotNil(mergedDoc.components?.schemas?["NewSchema"])
        XCTAssertNotNil(mergedDoc.components?.schemas?["ExistingSchema"])
        XCTAssertNotNil(mergedDoc.paths?["/existing"]?.get)

        let existingJSONNoPaths = """
        {
          "openapi": "3.2.0",
          "info": {"title": "Existing", "version": "1.0"}
        }
        """
        let swiftCodeWithRoute = """
        /// @Route("POST", "/new")
        func createNew() {}

        struct MyModel: Codable {
            var id: String
        }
        """
        let existingPath = tempPath("cdd_test_sync_out.json")
        let swiftPath = tempPath("cdd_test_sync_input.swift")
        try existingJSONNoPaths.write(toFile: existingPath, atomically: true, encoding: .utf8)
        try swiftCodeWithRoute.write(toFile: swiftPath, atomically: true, encoding: .utf8)

        var cmdPaths = try SyncOpenAPI.parse(["--input", swiftPath, "-o", existingPath])
        try await cmdPaths.run()

        let syncedJson = try WASIFileHelpers.readString(at: existingPath)
        let syncedDoc = try OpenAPIParser.parse(json: syncedJson)
        XCTAssertNotNil(syncedDoc.paths?["/new"]?.post)
        XCTAssertNotNil(syncedDoc.components?.schemas?["MyModel"])
    }

    /// Verifies `SyncOpenAPI` directory fallback and error handling.
    func testSyncOpenAPI() async throws {
        let dummySwift = tempPath("cdd_test_dummy.swift")
        let syncOut = tempPath("sync_out.json")
        let syncOut2 = tempPath("sync_out2.json")
        let syncOut3 = tempPath("sync_out3.json")

        var cmd = try SyncOpenAPI.parse(["--truth", "class", "--input", dummySwift, "-o", syncOut])
        try await cmd.run()

        var cmdWithExisting = try SyncOpenAPI.parse(["--truth", "class", "--input", dummySwift, "-o", syncOut])
        try await cmdWithExisting.run()

        let emptySwift = tempPath("cdd_empty_no_schemas.swift")
        try WASIFileHelpers.writeString("struct PlainNonCodable {}", to: emptySwift)
        var cmdEmptySchemas = try SyncOpenAPI.parse(["--truth", "class", "--input", emptySwift, "-o", syncOut])
        try await cmdEmptySchemas.run()

        var cmdDir = try SyncOpenAPI.parse(["--input", tempPath("cdd_test_dir/non_existent.swift"), "-o", syncOut2])
        try await cmdDir.run()
        let dirDoc = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: syncOut2))
        XCTAssertNotNil(dirDoc.components?.schemas?["Dummy2"])

        var cmdMissing = try SyncOpenAPI.parse(["--input", tempPath("non_existent_dir_123_456/non_existent_file.swift"), "-o", syncOut3])
        let missingRes: Void? = try? await cmdMissing.run()
        XCTAssertNil(missingRes)
    }

    /// Verifies `WASIFileHelpers` and `createDirRecursive` operations and error cases.
    func testWASIFileHelpers() throws {
        let uniqueBase = tempPath("cdd_test_dir_" + UUID().uuidString)
        let uniqueDir = uniqueBase + "/sub"
        try createDirRecursive(uniqueDir)
        XCTAssertTrue(WASIFileHelpers.fileExists(at: uniqueDir))
        let relDir = ".build/cdd_rel_test_" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: relDir) }
        try createDirRecursive(relDir)
        XCTAssertTrue(WASIFileHelpers.fileExists(at: relDir))
        try WASIFileHelpers.writeString("hello", to: uniqueDir + "/nested.txt")
        let listed = try WASIFileHelpers.listDirectory(at: uniqueBase + "/")
        XCTAssertTrue(listed.contains(uniqueDir + "/nested.txt"))
        let listedMissing = try WASIFileHelpers.listDirectory(at: tempPath("non_existent_dir_xyz_999"))
        XCTAssertTrue(listedMissing.isEmpty)

        XCTAssertThrowsError(try WASIFileHelpers.readFile(at: tempPath("non_existent_file_xyz.txt")))
        let testDir = tempPath("cdd-wasi-test-dir2")
        try WASIFileHelpers.createDirectory(at: testDir)
        XCTAssertThrowsError(try WASIFileHelpers.writeFile(data: Data(), to: "/invalid_path/file.txt"))
        XCTAssertThrowsError(try WASIFileHelpers.createDirectory(at: "/invalid_path/dir"))

        let invalidTxt = tempPath("cdd_test_invalid.txt")
        try WASIFileHelpers.writeFile(data: Data([0xFF, 0xFE]), to: invalidTxt)
        XCTAssertThrowsError(try WASIFileHelpers.readString(at: invalidTxt))

        let emptyTxt = tempPath("cdd_test_empty_data.txt")
        try WASIFileHelpers.writeFile(data: Data(), to: emptyTxt)
        XCTAssertEqual(try WASIFileHelpers.readFile(at: emptyTxt).count, 0)

        let largeTxt = tempPath("cdd_test_large.txt")
        let largeData = Data(repeating: 0x41, count: 10000)
        try WASIFileHelpers.writeFile(data: largeData, to: largeTxt)
        let readData = try WASIFileHelpers.readFile(at: largeTxt)
        XCTAssertEqual(readData.count, 10000)
    }
}
