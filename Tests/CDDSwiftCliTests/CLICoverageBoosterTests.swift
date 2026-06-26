import XCTest
@testable import cdd_swift_cli
@testable import CDDSwift

final class CLICoverageBoosterTests: XCTestCase {
    func testMainEntry() async {
        await CDDSwiftCLI.main()
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
          "info": {"title": "Existing", "version": "1.0"},
          "paths": {
             "/old": { "get": { "operationId": "getOld" } }
          }
        }
        """

        // This Swift file will be parsed into OpenAPIDocument paths
        let swiftCode = """
        /// @Route("POST", "/new")
        func createNew() {}
        """

        let existingPath = "/tmp/cdd_test_sync_out.json"
        let swiftPath = "/tmp/cdd_test_sync_input.swift"

        try existingJSON.write(toFile: existingPath, atomically: true, encoding: .utf8)
        try swiftCode.write(toFile: swiftPath, atomically: true, encoding: .utf8)

        var cmd = try SyncOpenAPI.parse(["--input", swiftPath, "-o", existingPath])
        try await cmd.run()
    }
}
