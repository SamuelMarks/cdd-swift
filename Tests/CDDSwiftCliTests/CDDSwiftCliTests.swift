import XCTest
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import cdd_swift_cli
import ArgumentParser
#if !os(WASI)
    import Swifter
#endif

final class CDDSwiftCliTests: XCTestCase {
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

    func testCDDSwiftCLI() throws {
        let cli = try CDDSwiftCLI.parse([])
        XCTAssertNotNil(cli)

        do {
            _ = try CDDSwiftCLI.parse(["--help"])
            XCTFail("Should throw CleanExit")
        } catch {
            // expected
        }
    }

    func testMain() {
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
    }

    func testCDDCLIEntryPoints() async throws {
        do { try await CDDCLI.generateFromOpenApi(["to_sdk", "--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-1"]) } catch {}
        do { try await CDDCLI.generateToOpenApi(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-ep-2.json"]) } catch {}
        do { try await CDDCLI.generateDocsJson(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-ep-3.json"]) } catch {}
        do { try await CDDCLI.syncOpenApi(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-ep-4.json"]) } catch {}
        #if !os(WASI)
            let task = Task { try? await CDDCLI.serveJsonRpc(["--port", "12354"]) }
            try await Task.sleep(nanoseconds: 10_000_000)
            task.cancel()
        #endif
    }

    func testFromOpenAPI_ToSDK() async throws {
        var cmd = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-output"])
        try await cmd.run()

        // Error path (invalid JSON)
        var cmdErr = try ToSDK.parse(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/cdd-test-output"])
        do {
            try await cmdErr.run()
            XCTFail("Should throw error")
        } catch {}

        // ToSDK relative path
        var cmdRelative = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "cdd-test-relative-dir"])
        try await cmdRelative.run()

        // ToSDK input directory instead of file
        try? WASIFileHelpers.createDirectory(at: "/tmp/cdd_input_dir_tests")
        try? WASIFileHelpers.writeString("{\"openapi\":\"3.0\"}", to: "/tmp/cdd_input_dir_tests/doc1.json")
        try? WASIFileHelpers.writeString("{\"openapi\":\"3.0\"}", to: "/tmp/cdd_input_dir_tests/doc2.json")
        var cmdInputDir = try ToSDK.parse(["--input-dir", "/tmp/cdd_input_dir_tests", "-o", "/tmp/cdd-test-dir-output"])
        try await cmdInputDir.run()

        // Missing input completely
        do {
            var cmdMissing = try ToSDK.parse(["-o", "/tmp/cdd-test-dir-output"])
            try await cmdMissing.run()
            XCTFail("Expected error")
        } catch {}

        // ToSDKCLI
        var cmdCli = try ToSDKCLI.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-cli-output"])
        try await cmdCli.run()

        var cmdCliNoPkg = try ToSDKCLI.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-cli-nopkg", "--no-installable-package"])
        try await cmdCliNoPkg.run()

        // ToSDK default output dir
        let originalCwd = FileManager.default.currentDirectoryPath
        try? WASIFileHelpers.createDirectory(at: "/tmp/cdd-test-cwd")
        FileManager.default.changeCurrentDirectoryPath("/tmp/cdd-test-cwd")
        var cmdDefaultOut = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json"])
        try await cmdDefaultOut.run()
        FileManager.default.changeCurrentDirectoryPath(originalCwd)

        // ToSDK with --no-installable-package
        var cmdNoInstallable = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-no-pkg", "--no-installable-package"])
        try await cmdNoInstallable.run()

        // ToSDK with --tests
        var cmdTests = try ToSDK.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-tests", "--tests"])
        try await cmdTests.run()

        let validOpenAPIWithPaths = """
        {
          "openapi": "3.1.0",
          "info": { "title": "Test API", "version": "1.0.0" },
          "paths": { "/test": { "get": { "operationId": "getTest", "responses": { "200": { "description": "OK" } } } } }
        }
        """
        // ToSDK with tests and multiple docs (to cover docs.count > 1 branches)
        try? WASIFileHelpers.writeString(validOpenAPIWithPaths, to: "/tmp/cdd_input_dir_tests/doc1.json")
        try? WASIFileHelpers.writeString(validOpenAPIWithPaths, to: "/tmp/cdd_input_dir_tests/doc2.json")
        try? WASIFileHelpers.writeString("{", to: "/tmp/cdd_input_dir_tests/doc3.json")
        var cmdTestsMulti = try ToSDK.parse(["--input-dir", "/tmp/cdd_input_dir_tests", "-o", "/tmp/cdd-test-tests-multi", "--tests"])
        try await cmdTestsMulti.run()

        // ToServer
        var cmdServer = try ToServer.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-server-output"])
        try await cmdServer.run()

        var cmdServerNoPkg = try ToServer.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-server-nopkg", "--no-installable-package"])
        try await cmdServerNoPkg.run()
    }

    func testServeJsonRpc() async throws {
        var cmd = try ServeJsonRpc.parse(["--port", "12353"])
        XCTAssertEqual(cmd.port, 12353)

        let task = Task {
            try await cmd.run()
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 500_000_000)

        // Make a request
        var request = try URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:12353/")))
        request.httpMethod = "POST"
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": {"help": true},
            "id": 1
        }
        """.data(using: .utf8)!

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            print("RPC Response:", String(data: data, encoding: .utf8) ?? "")
        } catch {
            print("RPC Error:", error)
        }

        // Test array params
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": ["--help"],
            "id": 2
        }
        """.data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)

        // Test bool and string map params
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": {"help": true, "input": "test"},
            "id": 3
        }
        """.data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)

        // Test invalid JSON
        request.httpBody = "invalid".data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)

        // Test missing id or method
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json"
        }
        """.data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)

        // Process error test
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "invalid_command_that_fails",
            "params": [],
            "id": 4
        }
        """.data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)

        // Process run error test
        setenv("CDD_MOCK_PROCESS_THROW", "1", 1)
        request.httpBody = """
        {
            "jsonrpc": "2.0",
            "method": "to_docs_json",
            "params": [],
            "id": 5
        }
        """.data(using: .utf8)!
        _ = try? await URLSession.shared.data(for: request)
        unsetenv("CDD_MOCK_PROCESS_THROW")

        task.cancel()

        // Test server start error (port already in use)
        // We know port 12353 was used, but wait, the previous server might be shut down due to task.cancel().
        // Let's create a dummy server to bind the port.
        let server = Swifter.HttpServer()
        try? server.start(12346, forceIPv4: true)
        var cmdErr = try ServeJsonRpc.parse(["--port", "12346"])
        do {
            try await cmdErr.run()
            XCTFail("Should throw error")
        } catch {
            server.stop()
        }
    }

    func testToDocsJson() async throws {
        // Output to file
        var cmd = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-out.json"])
        try await cmd.run()

        // Output to stdout
        var cmdStdout = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json"])
        try await cmdStdout.run()

        // Invalid URL
        var cmdInvalidURL = try ToDocsJson.parse(["--input", "http://inv alid"])
        do {
            try await cmdInvalidURL.run()
            XCTFail("Should throw ExitCode")
        } catch {}

        // HTTP Download using Swifter
        #if !os(WASI)
            let server = Swifter.HttpServer()
            let validJSON = """
            {"openapi": "3.1.0", "info": {"title": "Test API", "version": "1.0.0"}, "paths": {}}
            """
            server["/test.json"] = { _ in .ok(.text(validJSON)) }
            do {
                try server.start(12368, forceIPv4: true)
            } catch {
                print("Swifter start error: \\(error)")
            }
            var cmdHttp = try ToDocsJson.parse(["--input", "http://127.0.0.1:12368/test.json"])
            try await cmdHttp.run()
            server.stop()
        #endif

        // Invalid JSON to cover catch
        var cmdInvalidJSON = try ToDocsJson.parse(["--input", "/tmp/cdd_test_dummy.swift"])
        do {
            try await cmdInvalidJSON.run()
            XCTFail("Should throw error")
        } catch {}
    }

    func testGenerateOpenAPI() async throws {
        // Output to file
        var cmd = try GenerateOpenAPI.parse(["-o", "/tmp/cdd-test-out.json"])
        try await cmd.run()

        // Output to stdout
        var cmdStdout = try GenerateOpenAPI.parse([])
        try await cmdStdout.run()
    }

    func testMergeSwift() async throws {
        var cmd = try MergeSwift.parse(["/tmp/cdd_test_empty.json", "/tmp/cdd_test_dummy.swift"])
        try await cmd.run()

        // Missing dest
        var cmdMissing = try MergeSwift.parse(["/tmp/cdd_test_empty.json", "/tmp/cdd_test_dummy_missing.swift"])
        do {
            try await cmdMissing.run()
            XCTFail("Should throw error")
        } catch {}
    }

    func testToOpenAPI() async throws {
        var cmd = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/out.json"])
        try await cmd.run()

        // Fallback test: file does not exist, checks parent directory
        var cmdDir = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dir/non_existent.swift", "-o", "/tmp/out2.json"])
        try await cmdDir.run()

        // Output to stdout
        var cmdStdout = try ToOpenAPI.parse(["--input", "/tmp/cdd_test_dummy.swift"])
        try await cmdStdout.run()

        // Missing input path
        var cmdMissing = try ToOpenAPI.parse(["--input", "/tmp/non_existent_dir_123_456/non_existent_file.swift"])
        do {
            try await cmdMissing.run()
            XCTFail("Should throw error")
        } catch {}
    }

    func testSyncOpenAPIMerge() async throws {
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
    }

    func testSyncOpenAPI() async throws {
        var cmd = try SyncOpenAPI.parse(["--truth", "class", "--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/sync_out.json"])
        try await cmd.run()

        // Sync with existing to keep it valid
        var cmdWithExisting = try SyncOpenAPI.parse(["--truth", "class", "--input", "/tmp/cdd_test_dummy.swift", "-o", "/tmp/sync_out.json"])
        try await cmdWithExisting.run()

        // Missing dir fallback
        var cmdDir = try SyncOpenAPI.parse(["--input", "/tmp/cdd_test_dir/non_existent.swift", "-o", "/tmp/sync_out2.json"])
        try await cmdDir.run()

        // Missing input path
        var cmdMissing = try SyncOpenAPI.parse(["--input", "/tmp/non_existent_dir_123_456/non_existent_file.swift", "-o", "/tmp/sync_out3.json"])
        do {
            try await cmdMissing.run()
            XCTFail("Should throw error")
        } catch {}
    }

    func testWASIFileHelpers() throws {
        XCTAssertThrowsError(try WASIFileHelpers.readFile(at: "/tmp/non_existent_file_xyz.txt"))
        let testDir = "/tmp/cdd-wasi-test-dir2"
        try? WASIFileHelpers.createDirectory(at: testDir) // should succeed
        XCTAssertThrowsError(try WASIFileHelpers.writeFile(data: Data(), to: "/invalid_path/file.txt"))
        XCTAssertThrowsError(try WASIFileHelpers.createDirectory(at: "/invalid_path/dir"))

        // Test non-utf8 read
        try? WASIFileHelpers.writeFile(data: Data([0xFF, 0xFE]), to: "/tmp/cdd_test_invalid.txt")
        XCTAssertThrowsError(try WASIFileHelpers.readString(at: "/tmp/cdd_test_invalid.txt"))

        // Test empty write
        try? WASIFileHelpers.writeFile(data: Data(), to: "/tmp/cdd_test_empty_data.txt")
        XCTAssertEqual(try WASIFileHelpers.readFile(at: "/tmp/cdd_test_empty_data.txt").count, 0)

        // Test large write (> 8192 bytes)
        let largeData = Data(repeating: 0x41, count: 10000)
        try? WASIFileHelpers.writeFile(data: largeData, to: "/tmp/cdd_test_large.txt")
        let readData = try WASIFileHelpers.readFile(at: "/tmp/cdd_test_large.txt")
        XCTAssertEqual(readData.count, 10000)
    }
}
