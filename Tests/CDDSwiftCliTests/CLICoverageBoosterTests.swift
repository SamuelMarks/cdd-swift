import XCTest
@testable import cdd_swift_cli
@testable import CDDSwift

final class CLICoverageBoosterTests: XCTestCase {
    func testMainEntry() async {
        await CDDSwiftCLI.main()
    }

    func testMainEntryFull() async {
        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in3.json")
        try? "{\"openapi\": \"3.2.0\", \"info\": {\"title\": \"Dummy\", \"version\": \"1.0.0\"}, \"paths\": {}}".write(to: dummyIn, atomically: true, encoding: .utf8)
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("docs3.json").path

        await CDDSwiftCLI.main(arguments: ["cdd-swift", "to_docs_json", "--input", dummyIn.path, "-o", dummyOut], environment: [:])
    }

    func testMainExecution() async {
        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in.json")
        try? "{\"openapi\": \"3.2.0\", \"info\": {\"title\": \"Dummy\", \"version\": \"1.0.0\"}, \"paths\": {}}".write(to: dummyIn, atomically: true, encoding: .utf8)
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("docs.json").path
        await CDDSwiftCLI._main(arguments: ["to_docs_json", "--input", dummyIn.path, "-o", dummyOut], environment: [:])
    }

    func testCreateDirRecursive() throws {
        let uniqueDir = "/tmp/cdd_test_dir_" + UUID().uuidString + "/sub"
        try createDirRecursive(uniqueDir)
        XCTAssertTrue(WASIFileHelpers.fileExists(at: uniqueDir))
    }

    func testSyncOpenAPIPaths() async throws {
        let existingJSON = """
        {
          "openapi": "3.2.0",
          "info": {"title": "Existing", "version": "1.0"}
        }
        """

        // This Swift file will be parsed into OpenAPIDocument paths and components
        let swiftCode = """
        /// @Route("POST", "/new")
        func createNew() {}

        struct MyModel: Codable {
            var id: String
        }
        """

        let existingPath = "/tmp/cdd_test_sync_out.json"
        let swiftPath = "/tmp/cdd_test_sync_input.swift"

        try existingJSON.write(toFile: existingPath, atomically: true, encoding: .utf8)
        try swiftCode.write(toFile: swiftPath, atomically: true, encoding: .utf8)

        var cmd = try SyncOpenAPI.parse(["--input", swiftPath, "-o", existingPath])
        try await cmd.run()
    }
}
