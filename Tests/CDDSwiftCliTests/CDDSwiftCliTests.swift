/// Unit tests for `cdd-swift-cli` subcommands, environment argument parsing, and WASI file helpers.
import XCTest
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import ArgumentParser
@testable import CDDSwift
@testable import cdd_swift_cli
#if !os(WASI)
    import Swifter
#endif

/// Test suite verifying CLI commands (`ToSDK`, `ToSDKCLI`, `ToServer`, `ToOpenAPI`, `SyncOpenAPI`, `ToDocsJson`, `ServeJsonRpc`, `MergeSwift`) and `WASIFileHelpers`.
final class CDDSwiftCliTests: XCTestCase {
    /// Temporary output paths created during tests to be cleaned up on tearDown.
    private static let tempPaths: [String] = [
        "/tmp/cdd-test-ep-1",
        "/tmp/cdd-test-ep-2.json",
        "/tmp/cdd-test-ep-3.json",
        "/tmp/cdd-test-ep-4.json",
        "/tmp/cdd-test-ep-5",
        "/tmp/cdd-test-ep-6",
        "/tmp/cdd-test-ep-7",
        "/tmp/cdd-test-output",
        "/tmp/cdd_input_dir_tests",
        "/tmp/cdd-test-dir-output",
        "/tmp/cdd-test-cli-output",
        "/tmp/cdd-test-cli-nopkg",
        "/tmp/cdd-test-cwd",
        "/tmp/cdd-test-no-pkg",
        "/tmp/cdd-test-tests",
        "/tmp/cdd-test-tests-multi",
        "/tmp/cdd-test-server-output",
        "/tmp/cdd-test-server-nopkg",
        "/tmp/cdd-test-out.json",
        "/tmp/out.json",
        "/tmp/out2.json",
        "/tmp/sync_merge.json",
        "/tmp/sync_swift.swift",
        "/tmp/sync_out.json",
        "/tmp/sync_out2.json",
        "/tmp/sync_out3.json",
        "/tmp/cdd-wasi-test-dir2",
        "/tmp/cdd_test_invalid.txt",
        "/tmp/cdd_test_empty_data.txt",
        "/tmp/cdd_test_large.txt",
        "/tmp/cdd_test_sync_out.json",
        "/tmp/cdd_test_sync_input.swift"
    ]

    /// Prepares fixture files before each test.
    override func setUp() {
        super.setUp()
        let validOpenAPI = """
        {
          "openapi": "3.1.0",
          "info": {
            "title": "Test API",
            "version": "1.0.0"
          },
          "paths": {}
        }
        """
        try? WASIFileHelpers.writeString(validOpenAPI, to: "/tmp/cdd_test_empty.json")
        try? WASIFileHelpers.writeString("struct Dummy {}", to: "/tmp/cdd_test_dummy.swift")
        try? WASIFileHelpers.createDirectory(at: "/tmp/cdd_test_dir")
        try? WASIFileHelpers.writeString("struct Dummy2 {}", to: "/tmp/cdd_test_dir/dummy2.swift")
    }

    /// Cleans up temporary files created in `/tmp/` after each test.
    override func tearDown() {
        for path in Self.tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        super.tearDown()
    }

    /// Verifies `CDDSwiftCLI` command parsing and `--help` behavior.
    func testCDDSwiftCLI() throws {
        let cli = try CDDSwiftCLI.parse([])
        XCTAssertNotNil(cli)
        XCTAssertThrowsError(try CDDSwiftCLI.parse(["--help"]))
    }

    /// Verifies `CDDSwiftCLI.buildArgs` environment variable translation and main entrypoints.
    func testMainAndEntryPoints() async throws {
        let env = [
            "CDD_PORT": "1234",
            "CDD_NO_IMPORTS": "true",
            "CDD_SOME_FLAG": "false",
            "CDD_OTHER_FLAG": "hello",
            "CDD_COMMAND": "skip",
            "CDD_ARGS": "skip"
        ]
        let args = CDDSwiftCLI.buildArgs(from: [], env: env)
        XCTAssertTrue(args.contains("--port"))
        XCTAssertTrue(args.contains("1234"))
        XCTAssertTrue(args.contains("--no-imports"))
        XCTAssertFalse(args.contains("--some-flag"))
        XCTAssertTrue(args.contains("--other-flag"))
        XCTAssertTrue(args.contains("hello"))

        await CDDSwiftCLI.main()

        let dummyIn = FileManager.default.temporaryDirectory.appendingPathComponent("dummy_in3.json")
        let dummyOut = FileManager.default.temporaryDirectory.appendingPathComponent("docs3.json")
        defer {
            try? FileManager.default.removeItem(at: dummyIn)
            try? FileManager.default.removeItem(at: dummyOut)
        }
        try #"{"openapi": "3.2.0", "info": {"title": "Dummy", "version": "1.0.0"}, "paths": {}}"#.write(to: dummyIn, atomically: true, encoding: .utf8)

        await CDDSwiftCLI.main(arguments: ["cdd-swift", "to_docs_json", "--input", dummyIn.path, "-o", dummyOut.path], environment: [:])
        await CDDSwiftCLI._main(arguments: ["to_docs_json", "--input", dummyIn.path, "-o", dummyOut.path], environment: [:])
        XCTAssertTrue(WASIFileHelpers.fileExists(at: dummyOut.path))
    }

    /// Verifies `CDDCLI` programmatic entrypoints.
    func testCDDCLIEntryPoints() async throws {
        try await CDDCLI.generateFromOpenApi(["to_sdk", "--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-1"])
        try await CDDCLI.generateToOpenApi(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-ep-2.json"])
        try await CDDCLI.generateDocsJson(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-3.json"])
        try await CDDCLI.syncOpenApi(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-ep-4.json"])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_sdk", ["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-5"])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_sdk_cli", ["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-6"])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_server", ["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-7"])
        #if !os(WASI)
            let task = Task { try? await CDDCLI.serveJsonRpc(["--port", "12354"]) }
            try await Task.sleep(nanoseconds: 10_000_000)
            task.cancel()
            let mcpTask = Task { try? await CDDCLI.mcp([]) }
            try await Task.sleep(nanoseconds: 10_000_000)
            mcpTask.cancel()
        #endif
    }

    /// Verifies `ToSDK`, `ToSDKCLI`, and `ToServer` commands across single files, directories, and flags.
    func testFromOpenAPI_ToSDKAndServer() async throws {
        var cmd = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-output"])
        try await cmd.run()

        var cmdErr = try ToSDK.parse(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-output"])
        let errRes: Void? = try? await cmdErr.run()
        XCTAssertNil(errRes)

        var cmdRelative = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "cdd-test-relative-dir"])
        defer { try? FileManager.default.removeItem(atPath: "cdd-test-relative-dir") }
        try await cmdRelative.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "cdd-test-relative-dir/Package.swift"))

        try? WASIFileHelpers.createDirectory(at: "/tmp/cdd_input_dir_tests")
        try? WASIFileHelpers.writeString(#"{"openapi":"3.0"}"#, to: "/tmp/cdd_input_dir_tests/doc1.json")
        try? WASIFileHelpers.writeString(#"{"openapi":"3.0"}"#, to: "/tmp/cdd_input_dir_tests/doc2.json")
        var cmdInputDir = try ToSDK.parse(["--input-dir", "/tmp/cdd_input_dir_tests", "-o", "/tmp/cdd-test-dir-output"])
        try await cmdInputDir.run()

        XCTAssertThrowsError(try ToSDK.parse(["-o", "/tmp/cdd-test-dir-output"]))
        var emptyOpts = try BaseFromOpenAPIOptions.parse(["-i", "/tmp/cdd_test_empty.json"])
        emptyOpts.inputPath = nil
        XCTAssertEqual(try emptyOpts.getDocuments().count, 0)

        var cmdCli = try ToSDKCLI.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-cli-output"])
        try await cmdCli.run()

        var cmdCliNoPkg = try ToSDKCLI.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-cli-nopkg", "--no-installable-package"])
        try await cmdCliNoPkg.run()

        let originalCwd = FileManager.default.currentDirectoryPath
        try? WASIFileHelpers.createDirectory(at: "/tmp/cdd-test-cwd")
        _ = FileManager.default.changeCurrentDirectoryPath("/tmp/cdd-test-cwd")
        var cmdDefaultOut = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json"])
        try await cmdDefaultOut.run()
        _ = FileManager.default.changeCurrentDirectoryPath(originalCwd)

        var cmdNoInstallable = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-no-pkg", "--no-installable-package"])
        try await cmdNoInstallable.run()

        var cmdTests = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-tests", "--tests"])
        try await cmdTests.run()

        let validOpenAPIWithPaths = """
        {
          "openapi": "3.1.0",
          "info": { "title": "Test API", "version": "1.0.0" },
          "paths": { "/test": { "get": { "operationId": "getTest", "responses": { "200": { "description": "OK" } } } } }
        }
        """
        try? WASIFileHelpers.writeString(validOpenAPIWithPaths, to: "/tmp/cdd_input_dir_tests/doc1.json")
        try? WASIFileHelpers.writeString(validOpenAPIWithPaths, to: "/tmp/cdd_input_dir_tests/doc2.json")
        try? WASIFileHelpers.writeString("{", to: "/tmp/cdd_input_dir_tests/doc3.json")
        var cmdTestsMulti = try ToSDK.parse(["--input-dir", "/tmp/cdd_input_dir_tests", "-o", "/tmp/cdd-test-tests-multi", "--tests"])
        try await cmdTestsMulti.run()

        var cmdServer = try ToServer.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-server-output"])
        try await cmdServer.run()

        var cmdServerNoPkg = try ToServer.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-server-nopkg", "--no-installable-package"])
        try await cmdServerNoPkg.run()

        let outDir = "/tmp/cdd-test-server-coverage"
        defer { try? FileManager.default.removeItem(atPath: outDir) }
        var cmdServerFull = try ToServer.parse(["--input", "comprehensive-openapi.json", "-o", outDir, "--tests"])
        try await cmdServerFull.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Package.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Entrypoint.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Routes/Routes.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Mocks/DatabaseSeeder.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/StubModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/EphemeralModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/SeededModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/AuthMiddlewareTests.swift"))
    }

    /// Verifies `ServeJsonRpc` HTTP server handling of valid, array-parameter, invalid, and failing requests.
    func testServeJsonRpc() async throws {
        var cmd = try ServeJsonRpc.parse(["--port", "12353"])
        XCTAssertEqual(cmd.port, 12353)

        let task = Task {
            try await cmd.run()
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        var request = try URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:12353/")))
        request.httpMethod = "POST"
        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": {"help": true},
            "id": 1
        }
        """.utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(data.isEmpty)

        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": ["--help"],
            "id": 2
        }
        """.utf8)
        let (arrData, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(arrData.isEmpty)

        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": {"help": true, "input": "test"},
            "id": "str-3"
        }
        """.utf8)
        let (strIdData, _) = try await URLSession.shared.data(for: request)
        XCTAssertTrue(String(decoding: strIdData, as: UTF8.self).contains("str-3"))

        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": [],
            "id": true
        }
        """.utf8)
        let (boolIdData, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(boolIdData.isEmpty)

        request.httpBody = Data("invalid".utf8)
        let (_, badResp) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((badResp as? HTTPURLResponse)?.statusCode, 400)

        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json"
        }
        """.utf8)
        let (_, missingResp) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((missingResp as? HTTPURLResponse)?.statusCode, 400)

        ServeJsonRpc.executor = DefaultCommandExecutor(executablePathOverride: "/non_existent_binary_xyz_123")
        request.httpBody = Data("""
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": [],
            "id": 5
        }
        """.utf8)
        let (errData, _) = try await URLSession.shared.data(for: request)
        XCTAssertTrue(String(decoding: errData, as: UTF8.self).contains("-32603"))
        ServeJsonRpc.executor = DefaultCommandExecutor()

        task.cancel()

        let server = Swifter.HttpServer()
        try server.start(12346, forceIPv4: true)
        var cmdErr = try ServeJsonRpc.parse(["--port", "12346"])
        let startErr: Void? = try? await cmdErr.run()
        XCTAssertNil(startErr)
        server.stop()
    }

    /// Verifies `ToDocsJson` command execution from local files and HTTP URLs.
    func testToDocsJson() async throws {
        var cmd = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-out.json"])
        try await cmd.run()

        var cmdStdout = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json"])
        try await cmdStdout.run()

        var cmdInvalidURL = try ToDocsJson.parse(["--input", "http://inv alid"])
        let invalidUrlRes: Void? = try? await cmdInvalidURL.run()
        XCTAssertNil(invalidUrlRes)

        #if !os(WASI)
            let server = Swifter.HttpServer()
            let validJSON = """
            {"openapi": "3.1.0", "info": {"title": "Test API", "version": "1.0.0"}, "paths": {}}
            """
            server["/test.json"] = { _ in .ok(.text(validJSON)) }
            try server.start(12368, forceIPv4: true)
            var cmdHttp = try ToDocsJson.parse(["--input", "http://127.0.0.1:12368/test.json"])
            try await cmdHttp.run()
            server.stop()
        #endif

        var cmdInvalidJSON = try ToDocsJson.parse(["--input", "/tmp/cdd_test_dummy.swift"])
        let invalidJsonRes: Void? = try? await cmdInvalidJSON.run()
        XCTAssertNil(invalidJsonRes)
    }

    /// Verifies `GenerateOpenAPI` command execution to file and stdout.
    func testGenerateOpenAPI() async throws {
        var cmd = try GenerateOpenAPI.parse(["-o", "/tmp/cdd-test-out.json"])
        try await cmd.run()

        var cmdStdout = try GenerateOpenAPI.parse([])
        try await cmdStdout.run()
    }

    /// Verifies `MergeSwift` command execution and missing destination error handling.
    func testMergeSwift() async throws {
        var cmd = try MergeSwift.parse(["-i", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd_test_dummy.swift"])
        try await cmd.run()

        var cmdMissing = try MergeSwift.parse(["-i", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd_test_dummy_missing.swift"])
        let missingRes: Void? = try? await cmdMissing.run()
        XCTAssertNil(missingRes)
    }

    /// Verifies `ToOpenAPI` command execution across files, directories, and stdout.
    func testToOpenAPI() async throws {
        var cmd = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/out.json"])
        try await cmd.run()

        var cmdDir = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dir/non_existent.swift", "-o", "/tmp/out2.json"])
        try await cmdDir.run()

        var cmdStdout = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dummy.swift"])
        try await cmdStdout.run()

        var cmdMissing = try ToOpenAPI.parse(["--input", "/tmp/non_existent_dir_123_456/non_existent_file.swift"])
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
        try? WASIFileHelpers.writeString(existingJSON, to: "/tmp/sync_merge.json")
        let swiftCode = """
        struct NewSchema: Codable {
            let id: String
        }
        """
        try? WASIFileHelpers.writeString(swiftCode, to: "/tmp/sync_swift.swift")
        var cmd = try SyncOpenAPI.parse(["--truth", "class", "--input", "/tmp/sync_swift.swift", "-o", "/tmp/sync_merge.json"])
        try await cmd.run()

        let merged = try WASIFileHelpers.readString(at: "/tmp/sync_merge.json")
        XCTAssertTrue(merged.contains("NewSchema"))
        XCTAssertTrue(merged.contains("ExistingSchema"))
        XCTAssertTrue(merged.contains("/existing"))

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
        let existingPath = "/tmp/cdd_test_sync_out.json"
        let swiftPath = "/tmp/cdd_test_sync_input.swift"
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
        var cmd = try SyncOpenAPI.parse(["--truth", "class", "--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/sync_out.json"])
        try await cmd.run()

        var cmdWithExisting = try SyncOpenAPI.parse(["--truth", "class", "--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/sync_out.json"])
        try await cmdWithExisting.run()

        var cmdDir = try SyncOpenAPI.parse(["--input", "/tmp/cdd_test_dir/non_existent.swift", "-o", "/tmp/sync_out2.json"])
        try await cmdDir.run()

        var cmdMissing = try SyncOpenAPI.parse(["--input", "/tmp/non_existent_dir_123_456/non_existent_file.swift", "-o", "/tmp/sync_out3.json"])
        let missingRes: Void? = try? await cmdMissing.run()
        XCTAssertNil(missingRes)
    }

    /// Verifies `WASIFileHelpers` and `createDirRecursive` operations and error cases.
    func testWASIFileHelpers() throws {
        let uniqueBase = "/tmp/cdd_test_dir_" + UUID().uuidString
        let uniqueDir = uniqueBase + "/sub"
        defer { try? FileManager.default.removeItem(atPath: uniqueBase) }
        try createDirRecursive(uniqueDir)
        XCTAssertTrue(WASIFileHelpers.fileExists(at: uniqueDir))

        XCTAssertThrowsError(try WASIFileHelpers.readFile(at: "/tmp/non_existent_file_xyz.txt"))
        let testDir = "/tmp/cdd-wasi-test-dir2"
        try? WASIFileHelpers.createDirectory(at: testDir)
        XCTAssertThrowsError(try WASIFileHelpers.writeFile(data: Data(), to: "/invalid_path/file.txt"))
        XCTAssertThrowsError(try WASIFileHelpers.createDirectory(at: "/invalid_path/dir"))

        try? WASIFileHelpers.writeFile(data: Data([0xFF, 0xFE]), to: "/tmp/cdd_test_invalid.txt")
        XCTAssertThrowsError(try WASIFileHelpers.readString(at: "/tmp/cdd_test_invalid.txt"))

        try? WASIFileHelpers.writeFile(data: Data(), to: "/tmp/cdd_test_empty_data.txt")
        XCTAssertEqual(try WASIFileHelpers.readFile(at: "/tmp/cdd_test_empty_data.txt").count, 0)

        let largeData = Data(repeating: 0x41, count: 10000)
        try? WASIFileHelpers.writeFile(data: largeData, to: "/tmp/cdd_test_large.txt")
        let readData = try WASIFileHelpers.readFile(at: "/tmp/cdd_test_large.txt")
        XCTAssertEqual(readData.count, 10000)
    }
}
