/// Unit tests for `cdd-swift-cli` subcommands, environment argument parsing, and WASI file helpers.
import XCTest
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import ArgumentParser
@testable import CDDSwift
@testable import cdd_swift_cli
import SwiftParser
#if !os(WASI)
    import Swifter
#endif

/// Test suite verifying CLI commands (`ToSDK`, `ToSDKCLI`, `ToServer`, `ToOpenAPI`, `SyncOpenAPI`, `ToDocsJson`, `ServeJsonRpc`,
/// `MergeSwift`) and `WASIFileHelpers`.
final class CDDSwiftCliTests: XCTestCase {
    /// Per-test unique temporary root directory.
    private var tempRoot: URL = FileManager.default.temporaryDirectory

    /// Creates a unique per-test temporary directory and fixture files before each test.
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("cdd_cli_test_" + UUID().uuidString)
        try WASIFileHelpers.createDirectoryRecursive(at: tempRoot.path)

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
        try WASIFileHelpers.writeString(validOpenAPI, to: tempPath("cdd_test_empty.json"))
        try WASIFileHelpers.writeString("struct Dummy: Codable {}", to: tempPath("cdd_test_dummy.swift"))
        try WASIFileHelpers.createDirectory(at: tempPath("cdd_test_dir"))
        try WASIFileHelpers.writeString("struct Dummy2: Codable {}", to: tempPath("cdd_test_dir/dummy2.swift"))
    }

    /// Cleans up the per-test temporary directory after each test.
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        try super.tearDownWithError()
    }

    /// Resolves a relative path inside the per-test temporary directory.
    ///
    /// - Parameter relative: Relative file or directory name.
    /// - Returns: Absolute filesystem path inside `tempRoot`.
    func tempPath(_ relative: String) -> String {
        tempRoot.appendingPathComponent(relative).path
    }

    /// Verifies `CDDSwiftCLI` command parsing and `--help` behavior.
    func testCDDSwiftCLI() throws {
        let cli = try CDDSwiftCLI.parse([])
        XCTAssertNotNil(cli)
        XCTAssertEqual(CDDSwiftCLI.configuration.version, CDDVersion.current)
        XCTAssertEqual(CDDVersion.current, "0.0.4")
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

        let dummyIn = tempPath("dummy_in3.json")
        let dummyOut = tempPath("docs3.json")
        try WASIFileHelpers.writeString(#"{"openapi": "3.2.0", "info": {"title": "Dummy", "version": "1.0.0"}, "paths": {}}"#, to: dummyIn)

        await CDDSwiftCLI.main(arguments: ["cdd-swift", "to_docs_json", "--input", dummyIn, "-o", dummyOut], environment: [:])
        await CDDSwiftCLI._main(arguments: ["to_docs_json", "--input", dummyIn, "-o", dummyOut], environment: [:])
        XCTAssertTrue(WASIFileHelpers.fileExists(at: dummyOut))
        let docsJson = try WASIFileHelpers.readString(at: dummyOut)
        XCTAssertTrue(docsJson.contains("operations"))
    }

    /// Verifies `CDDCLI` programmatic entrypoints and validates the generated artifacts.
    func testCDDCLIEntryPoints() async throws {
        let ep1 = tempPath("cdd-test-ep-1")
        let ep2 = tempPath("cdd-test-ep-2.json")
        let ep3 = tempPath("cdd-test-ep-3.json")
        let ep4 = tempPath("cdd-test-ep-4.json")
        let ep5 = tempPath("cdd-test-ep-5")
        let ep6 = tempPath("cdd-test-ep-6")
        let ep7 = tempPath("cdd-test-ep-7")
        let emptyJson = tempPath("cdd_test_empty.json")
        let dummySwift = tempPath("cdd_test_dummy.swift")

        try await CDDCLI.generateFromOpenApi(["to_sdk", "--input", emptyJson, "-o", ep1])
        try await CDDCLI.generateToOpenApi(["--input", dummySwift, "-o", ep2])
        try await CDDCLI.generateDocsJson(["--input", emptyJson, "-o", ep3])
        try await CDDCLI.syncOpenApi(["--input", dummySwift, "-o", ep4])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_sdk", ["--input", emptyJson, "-o", ep5])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_sdk_cli", ["--input", emptyJson, "-o", ep6])
        try await CDDCLI.generateFromOpenApi(subcommand: "to_server", ["--input", emptyJson, "-o", ep7])

        let parsedEp2 = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: ep2))
        XCTAssertEqual(parsedEp2.openapi, "3.2.0")
        let parsedEp4 = try OpenAPIParser.parse(json: WASIFileHelpers.readString(at: ep4))
        XCTAssertEqual(parsedEp4.openapi, "3.2.0")

        #if !os(WASI)
            let rpcPort: UInt16 = 12354
            let task = Task { try? await CDDCLI.serveJsonRpc(["--port", "\(rpcPort)"]) }
            await ServeJsonRpcRuntime.shared.waitUntilListening(port: rpcPort)
            task.cancel()
            _ = await task.value

            let mockTransport = MockMCPTransport()
            await MCPServeRuntime.shared.setTransport(mockTransport)
            let mcpTask = Task { try? await CDDCLI.mcp([]) }
            try await mockTransport.waitUntilStarted()
            try await mockTransport.close()
            _ = await mcpTask.value
            await MCPServeRuntime.shared.setTransport(nil)
        #endif
    }

    /// Verifies `ToSDK` and `ToSDKCLI` commands across single files, directories, and flags.
    func testFromOpenAPIToSDKAndSDKCLI() async throws {
        let emptyJson = tempPath("cdd_test_empty.json")
        let dummySwift = tempPath("cdd_test_dummy.swift")
        let sdkOut = tempPath("cdd-test-output")

        var cmd = try ToSDK.parse(["--input", emptyJson, "-o", sdkOut])
        try await cmd.run()
        let sdkClientCode = try WASIFileHelpers.readString(at: sdkOut + "/Sources/GeneratedSDK/client.swift")
        XCTAssertFalse(Parser.parse(source: sdkClientCode).hasError)

        var cmdErr = try ToSDK.parse(["--input", dummySwift, "-o", sdkOut])
        let errRes: Void? = try? await cmdErr.run()
        XCTAssertNil(errRes)

        let inputDirTests = tempPath("cdd_input_dir_tests")
        let dirOut = tempPath("cdd-test-dir-output")
        try WASIFileHelpers.createDirectory(at: inputDirTests)
        try WASIFileHelpers.writeString(#"{"openapi":"3.0","info":{"title":"T","version":"1"}}"#, to: inputDirTests + "/doc1.json")
        try WASIFileHelpers.writeString(#"{"openapi":"3.0","info":{"title":"T","version":"1"}}"#, to: inputDirTests + "/doc2.json")
        var cmdInputDir = try ToSDK.parse(["--input-dir", inputDirTests, "-o", dirOut])
        try await cmdInputDir.run()
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: dirOut + "/Sources/GeneratedSDK/doc1/client.swift"))
            .hasError)

        XCTAssertThrowsError(try ToSDK.parse(["-o", dirOut]))
        var emptyOpts = try BaseFromOpenAPIOptions.parse(["-i", emptyJson])
        emptyOpts.inputPath = nil
        XCTAssertEqual(try emptyOpts.getDocuments().count, 0)
        XCTAssertEqual(emptyOpts.resolveOutputDir(), ".")

        let cliOut = tempPath("cdd-test-cli-output")
        var cmdCli = try ToSDKCLI.parse(["--input", emptyJson, "-o", cliOut])
        try await cmdCli.run()
        let cliCode = try WASIFileHelpers.readString(at: cliOut + "/Sources/GeneratedSDKCLI/cdd_test_empty.swift")
        XCTAssertFalse(Parser.parse(source: cliCode).hasError)

        let cliMultiOut = tempPath("cdd-test-cli-multi")
        var cmdCliMulti = try ToSDKCLI.parse(["--input-dir", inputDirTests, "-o", cliMultiOut])
        try await cmdCliMulti.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliMultiOut + "/Sources/GeneratedSDKCLI/doc1_client.swift"))

        let cliNoPkgOut = tempPath("cdd-test-cli-nopkg")
        var cmdCliNoPkg = try ToSDKCLI.parse(["--input", emptyJson, "-o", cliNoPkgOut, "--no-installable-package"])
        try await cmdCliNoPkg.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliNoPkgOut + "/cdd_test_empty.swift"))

        let noPkgOut = tempPath("cdd-test-no-pkg")
        var cmdNoInstallable = try ToSDK.parse(["--input", emptyJson, "-o", noPkgOut, "--no-installable-package"])
        try await cmdNoInstallable.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: noPkgOut + "/client.swift"))
    }

    /// Verifies `ToSDK --tests` and `ToServer` commands across single files, directories, and flags.
    func testFromOpenAPIToServerAndTests() async throws {
        let emptyJson = tempPath("cdd_test_empty.json")
        let inputDirTests = tempPath("cdd_input_dir_server_tests")
        try WASIFileHelpers.createDirectory(at: inputDirTests)

        let testsOut = tempPath("cdd-test-tests")
        var cmdTests = try ToSDK.parse(["--input", emptyJson, "-o", testsOut, "--tests"])
        try await cmdTests.run()
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: testsOut + "/Tests/GeneratedSDKTests/tests.swift")).hasError)

        let validOpenAPIWithPaths = """
        {
          "openapi": "3.1.0",
          "info": { "title": "Test API", "version": "1.0.0" },
          "paths": { "/test": { "get": { "operationId": "getTest", "responses": { "200": { "description": "OK" } } } } }
        }
        """
        try WASIFileHelpers.writeString(validOpenAPIWithPaths, to: inputDirTests + "/doc1.json")
        try WASIFileHelpers.writeString(validOpenAPIWithPaths, to: inputDirTests + "/doc2.json")
        let testsMultiOut = tempPath("cdd-test-tests-multi")
        var cmdTestsMulti = try ToSDK.parse(["--input-dir", inputDirTests, "-o", testsMultiOut, "--tests"])
        try await cmdTestsMulti.run()

        try WASIFileHelpers.writeString("{", to: inputDirTests + "/doc3.json")
        let testsMultiBadOut = tempPath("cdd-test-tests-multi-bad")
        var cmdTestsMultiBad = try ToSDK.parse(["--input-dir", inputDirTests, "-o", testsMultiBadOut, "--tests"])
        let badDirRes: Void? = try? await cmdTestsMultiBad.run()
        XCTAssertNil(badDirRes)

        let serverOut = tempPath("cdd-test-server-output")
        var cmdServer = try ToServer.parse(["--input", emptyJson, "-o", serverOut])
        try await cmdServer.run()

        let serverNoPkgOut = tempPath("cdd-test-server-nopkg")
        var cmdServerNoPkg = try ToServer.parse(["--input", emptyJson, "-o", serverNoPkgOut, "--no-installable-package"])
        try await cmdServerNoPkg.run()

        let outDir = tempPath("cdd-test-server-coverage")
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
        let routesSource = try WASIFileHelpers.readString(at: "\(outDir)/Sources/GeneratedServer/Routes/Routes.swift")
        XCTAssertFalse(Parser.parse(source: routesSource).hasError)
    }

    /// Verifies `ServeJsonRpc`, `InProcessCommandExecutor`, and `DefaultCommandExecutor` handling of valid requests.
    func testServeJsonRpc() async throws {
        let procExec = DefaultCommandExecutor(executablePathOverride: "/bin/echo")
        XCTAssertTrue(try procExec.execute(args: ["hello_world"]).contains("hello_world"))
        XCTAssertNil(DefaultCommandExecutor().executablePathOverride)

        let inProcExec = InProcessCommandExecutor()
        XCTAssertTrue(try inProcExec.execute(args: ["generate_openapi"]).contains("generate_openapi"))
        XCTAssertTrue(try inProcExec.execute(args: ["to_docs_json", "--help"]).contains("to_docs_json"))
        XCTAssertThrowsError(try inProcExec.execute(args: ["unknown_subcommand_xyz"]))

        let rpcPort: UInt16 = 12353
        var cmd = try ServeJsonRpc.parse(["--port", "\(rpcPort)"])
        XCTAssertEqual(cmd.port, rpcPort)
        let task = Task { try await cmd.run() }

        await ServeJsonRpcRuntime.shared.waitUntilListening(port: rpcPort)
        await ServeJsonRpcRuntime.shared.waitUntilListening(port: rpcPort)

        var request = try URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:\(rpcPort)/")))
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"jsonrpc":"2.0","method":"to_docs_json","params":{"help":true},"id":1}"#.utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(data.isEmpty)

        request.httpBody = Data(#"{"jsonrpc":"2.0","method":"to_docs_json","params":["--help"],"id":2}"#.utf8)
        let (arrData, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(arrData.isEmpty)

        request.httpBody = Data(#"{"jsonrpc":"2.0","method":"to_docs_json","params":{"help":true,"input":"test"},"id":"str-3"}"#.utf8)
        let (strIdData, _) = try await URLSession.shared.data(for: request)
        XCTAssertTrue(String(decoding: strIdData, as: UTF8.self).contains("str-3"))

        request.httpBody = Data(#"{"jsonrpc":"2.0","method":"generate_openapi","params":[],"id":true}"#.utf8)
        let (boolIdData, _) = try await URLSession.shared.data(for: request)
        XCTAssertFalse(boolIdData.isEmpty)

        request.httpBody = Data("invalid".utf8)
        let (_, badResp) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((badResp as? HTTPURLResponse)?.statusCode, 400)

        request.httpBody = Data(#"{"jsonrpc":"2.0","method":"to_docs_json"}"#.utf8)
        let (_, missingResp) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((missingResp as? HTTPURLResponse)?.statusCode, 400)

        task.cancel()
        _ = try? await task.value
    }

    /// Verifies `ServeJsonRpc` executor error handling and port collision error reporting.
    func testServeJsonRpcErrors() async throws {
        let errPort: UInt16 = 12355
        let errTask = Task {
            let errCmd = try ServeJsonRpc.parse(["--port", "\(errPort)"])
            try await errCmd.run(executor: DefaultCommandExecutor(executablePathOverride: "/non_existent_binary_xyz_123"))
        }
        await ServeJsonRpcRuntime.shared.waitUntilListening(port: errPort)
        var errRequest = try URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:\(errPort)/")))
        errRequest.httpMethod = "POST"
        errRequest.httpBody = Data(#"{"jsonrpc":"2.0","method":"to_docs_json","params":[],"id":5}"#.utf8)
        let (errData, _) = try await URLSession.shared.data(for: errRequest)
        XCTAssertTrue(String(decoding: errData, as: UTF8.self).contains("-32603"))
        errTask.cancel()
        _ = try? await errTask.value
        await ServeJsonRpcRuntime.shared.setExecutor(InProcessCommandExecutor())

        let server = Swifter.HttpServer()
        try server.start(12346, forceIPv4: true)
        var cmdErr = try ServeJsonRpc.parse(["--port", "12346"])
        let startErr: Void? = try? await cmdErr.run()
        XCTAssertNil(startErr)
        server.stop()
    }
}

extension CDDSwiftCliTests {
    /// Verifies `ToDocsJson` command execution from local files, directories, Arazzo specs, and HTTP URLs.
    func testToDocsJson() async throws {
        let emptyJson = tempPath("cdd_test_empty.json")
        let outJson = tempPath("cdd-test-out.json")
        var cmd = try ToDocsJson.parse(["--input", emptyJson, "-o", outJson])
        try await cmd.run()
        let outContent = try WASIFileHelpers.readString(at: outJson)
        XCTAssertTrue(outContent.contains("operations"))

        let outDir = tempPath("cdd_docs_out_dir")
        try WASIFileHelpers.createDirectoryRecursive(at: outDir)
        var cmdDir = try ToDocsJson.parse(["--input", emptyJson, "-o", outDir])
        try await cmdDir.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: outDir + "/docs.json"))

        let outDirSlash = tempPath("cdd_docs_out_dir_slash")
        try WASIFileHelpers.createDirectoryRecursive(at: outDirSlash)
        var cmdDirSlash = try ToDocsJson.parse(["--input", emptyJson, "-o", outDirSlash + "/"])
        try await cmdDirSlash.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: outDirSlash + "/docs.json"))

        let arazzoPath = tempPath("cdd_test_arazzo.json")
        let arazzoJson = """
        {
          "arazzo": "1.1.0",
          "info": { "title": "Flows", "version": "1.0.0" },
          "sourceDescriptions": [{ "name": "api", "url": "https://api.example.com", "type": "openapi" }],
          "workflows": [{ "workflowId": "onboardUser", "steps": [{ "stepId": "step1", "operationId": "createUser" }] }]
        }
        """
        try WASIFileHelpers.writeString(arazzoJson, to: arazzoPath)
        let arazzoOut = tempPath("cdd-arazzo-docs.json")
        var cmdArazzo = try ToDocsJson.parse(["--input", arazzoPath, "-o", arazzoOut])
        try await cmdArazzo.run()
        let arazzoDocsContent = try WASIFileHelpers.readString(at: arazzoOut)
        XCTAssertTrue(arazzoDocsContent.contains("onboardUser"))

        var cmdStdout = try ToDocsJson.parse(["--input", emptyJson])
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

        var cmdInvalidJSON = try ToDocsJson.parse(["--input", tempPath("cdd_test_dummy.swift")])
        let invalidJsonRes: Void? = try? await cmdInvalidJSON.run()
        XCTAssertNil(invalidJsonRes)
    }
}
