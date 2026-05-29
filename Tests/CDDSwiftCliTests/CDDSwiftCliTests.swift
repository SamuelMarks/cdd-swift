import XCTest
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import cdd_swift_cli
import ArgumentParser

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
        setenv("CDD_PORT", "1234", 1)
        setenv("CDD_NO_IMPORTS", "true", 1)
        setenv("CDD_SOME_FLAG", "false", 1)
        setenv("CDD_OTHER_FLAG", "hello", 1)
        // just to trigger the Env mapping

        _ = Array(CommandLine.arguments.dropFirst())
        // Main is tricky to test since it blocks on parseAsRoot. We'll just test the code structure with unit tests.
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

        // Validation error
        XCTAssertThrowsError(try ToSDK.parse([]))
    }

    func testServeJsonRpc() async throws {
        var cmd = try ServeJsonRpc.parse(["--port", "12345"])
        XCTAssertEqual(cmd.port, 12345)

        let task = Task {
            try await cmd.run()
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 500_000_000)

        // Make a request
        var request = try URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:12345/")))
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

        task.cancel()
    }

    func testToDocsJson() async throws {
        // Output to file
        var cmd = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json", "-o", "/tmp/cdd-test-out.json"])
        try await cmd.run()

        // Output to stdout
        var cmdStdout = try ToDocsJson.parse(["--input", "/tmp/cdd_test_empty.json"])
        try await cmdStdout.run()

        // Invalid URL
        var cmdInvalidURL = try ToDocsJson.parse(["--input", "http://"])
        do {
            try await cmdInvalidURL.run()
            XCTFail("Should throw ExitCode")
        } catch {}

        // HTTP Download (mock by expecting failure to download from bad URL)
        var cmdHttp = try ToDocsJson.parse(["--input", "http://127.0.0.1:1/invalid"])
        do {
            try await cmdHttp.run()
            XCTFail("Should throw URL error")
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
    }

    func testWASIFileHelpers() throws {
        XCTAssertThrowsError(try WASIFileHelpers.readFile(at: "/tmp/non_existent_file_xyz.txt"))
        let testDir = "/tmp/cdd-wasi-test-dir2"
        try? WASIFileHelpers.createDirectory(at: testDir) // should succeed
        XCTAssertThrowsError(try WASIFileHelpers.writeFile(data: Data(), to: "/invalid_path/file.txt"))
        XCTAssertThrowsError(try WASIFileHelpers.createDirectory(at: "/invalid_path/dir"))
    }
}
