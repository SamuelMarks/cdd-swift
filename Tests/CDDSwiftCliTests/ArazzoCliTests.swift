/// Unit tests for Arazzo 1.1.0 CLI commands (`GenerateArazzo`, `FromArazzo`, `ToArazzo`, `SyncArazzo`).
@testable import cdd_swift_cli
import CDDSwift
import Foundation
import SwiftParser
import XCTest

/// Test suite verifying Arazzo CLI commands and programmatic `CDDCLI` entrypoints.
final class ArazzoCliTests: XCTestCase {
    /// Per-test unique temporary root directory path.
    private var tempDir = ""

    /// Creates a unique per-test temporary directory before each test.
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("cdd_arazzo_cli_" + UUID().uuidString).path
        try WASIFileHelpers.createDirectoryRecursive(at: tempDir)
    }

    /// Removes the per-test temporary directory after each test.
    override func tearDownWithError() throws {
        if !tempDir.isEmpty {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        try super.tearDownWithError()
    }

    /// Verifies `GenerateArazzo`, `FromArazzo`, `ToArazzo`, `SyncArazzo`, and programmatic `CDDCLI` entrypoints.
    func testGenerateFromAndToArazzoCommands() async throws {
        let specPath = tempDir + "/sample_arazzo.json"

        // 1. GenerateArazzo to file and stdout
        var genFileCmd = try GenerateArazzo.parse(["-o", specPath])
        try await genFileCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: specPath))
        let parsedSample = try ArazzoEmitter.parse(json: WASIFileHelpers.readString(at: specPath))
        XCTAssertEqual(parsedSample.arazzo, "1.1.0")
        XCTAssertEqual(parsedSample.workflows.first?.workflowId, "createAndFetchUser")

        var genStdoutCmd = try GenerateArazzo.parse([])
        try await genStdoutCmd.run()

        // 2. FromArazzo -> to_sdk (with and without package scaffolding, default output dir)
        let sdkDir = tempDir + "/sdk_out"
        var toSdkCmd = try ArazzoToSDK.parse(["-i", specPath, "-o", sdkDir])
        try await toSdkCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkDir + "/Package.swift"))
        let sdkClientPath = sdkDir + "/Sources/GeneratedWorkflowsSDK/WorkflowsClient.swift"
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkClientPath))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: sdkClientPath)).hasError)

        let sdkNoPkgDir = tempDir + "/sdk_nopkg"
        var toSdkNoPkgCmd = try ArazzoToSDK.parse(["-i", specPath, "-o", sdkNoPkgDir, "--no-installable-package"])
        try await toSdkNoPkgCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkNoPkgDir + "/WorkflowsClient.swift"))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: sdkNoPkgDir + "/WorkflowsClient.swift")).hasError)

        let optsDefault = try BaseFromArazzoOptions.parse(["-i", specPath])
        XCTAssertEqual(optsDefault.resolveOutputDir(), ".")

        // 3. FromArazzo -> to_sdk_cli (with and without package scaffolding)
        let cliDir = tempDir + "/cli_out"
        var toCliCmd = try ArazzoToSDKCLI.parse(["-i", specPath, "-o", cliDir])
        try await toCliCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliDir + "/Package.swift"))
        let cliPath = cliDir + "/Sources/GeneratedWorkflowsCLI/WorkflowCLI.swift"
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliPath))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: cliPath)).hasError)

        let cliNoPkgDir = tempDir + "/cli_nopkg"
        var toCliNoPkgCmd = try ArazzoToSDKCLI.parse(["-i", specPath, "-o", cliNoPkgDir, "--no-installable-package"])
        try await toCliNoPkgCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliNoPkgDir + "/WorkflowCLI.swift"))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: cliNoPkgDir + "/WorkflowCLI.swift")).hasError)

        // 4. FromArazzo -> to_test
        let testDir = tempDir + "/test_out"
        var toTestCmd = try ArazzoToTest.parse(["-i", specPath, "-o", testDir])
        try await toTestCmd.run()
        let testSuitePath = testDir + "/GeneratedArazzoWorkflowTests.swift"
        XCTAssertTrue(WASIFileHelpers.fileExists(at: testSuitePath))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: testSuitePath)).hasError)

        // 5. FromArazzo -> to_server
        let serverDir = tempDir + "/server_out"
        var toServerCmd = try ArazzoToServer.parse(["-i", specPath, "-o", serverDir])
        try await toServerCmd.run()
        let serverOrchPath = serverDir + "/ServerWorkflowOrchestrator.swift"
        XCTAssertTrue(WASIFileHelpers.fileExists(at: serverOrchPath))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: serverOrchPath)).hasError)
    }

    /// Verifies `ToArazzo`, `SyncArazzo`, and programmatic `CDDCLI` entrypoints.
    func testToArazzoSyncAndEntrypoints() async throws {
        let specPath = tempDir + "/sample_arazzo.json"
        var genFileCmd = try GenerateArazzo.parse(["-o", specPath])
        try await genFileCmd.run()

        let sdkNoPkgDir = tempDir + "/sdk_nopkg"
        var toSdkNoPkgCmd = try ArazzoToSDK.parse(["-i", specPath, "-o", sdkNoPkgDir, "--no-installable-package"])
        try await toSdkNoPkgCmd.run()

        // 6. ToArazzo (JSON and YAML, file and stdout)
        let swiftInput = sdkNoPkgDir + "/WorkflowsClient.swift"
        let extractedJsonPath = tempDir + "/extracted.json"
        var toArazzoJsonCmd = try ToArazzo.parse(["-i", swiftInput, "-o", extractedJsonPath])
        try await toArazzoJsonCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: extractedJsonPath))
        let extractedSpec = try ArazzoEmitter.parse(json: WASIFileHelpers.readString(at: extractedJsonPath))
        XCTAssertEqual(extractedSpec.workflows.first?.workflowId, "createAndFetchUser")

        let extractedYamlPath = tempDir + "/extracted.yaml"
        var toArazzoYamlCmd = try ToArazzo.parse(["-i", swiftInput, "-o", extractedYamlPath, "--format", "yaml"])
        try await toArazzoYamlCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: extractedYamlPath))
        XCTAssertTrue(try WASIFileHelpers.readString(at: extractedYamlPath).contains("arazzo: \"1.1.0\""))

        var toArazzoStdoutCmd = try ToArazzo.parse(["-i", swiftInput])
        try await toArazzoStdoutCmd.run()

        // 7. SyncArazzo (truth=swift and truth=arazzo)
        var syncSwiftTruthCmd = try SyncArazzo.parse(["-i", swiftInput, "-o", specPath, "--truth", "swift"])
        try await syncSwiftTruthCmd.run()

        let extraSwiftPath = tempDir + "/ExtraWorkflows.swift"
        let extraBlock = """

        public class Extra {
            /// @Workflow(id: "brandNewFlow")
            public func brandNewFlow() {}
        }
        """
        let extraSwiftCode = try WASIFileHelpers.readString(at: swiftInput) + extraBlock
        try WASIFileHelpers.writeString(extraSwiftCode, to: extraSwiftPath)
        var syncSwiftNewWfCmd = try SyncArazzo.parse(["-i", extraSwiftPath, "-o", specPath, "--truth", "swift"])
        try await syncSwiftNewWfCmd.run()
        let syncedSpec = try ArazzoEmitter.parse(json: WASIFileHelpers.readString(at: specPath))
        XCTAssertTrue(syncedSpec.workflows.contains(where: { $0.workflowId == "brandNewFlow" }))

        let newSpecOut = tempDir + "/brand_new_arazzo.json"
        var syncNewOutCmd = try SyncArazzo.parse(["-i", swiftInput, "-o", newSpecOut, "--truth", "swift"])
        try await syncNewOutCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: newSpecOut))

        var syncArazzoTruthExisting = try SyncArazzo.parse(["-i", swiftInput, "-o", specPath, "--truth", "arazzo"])
        try await syncArazzoTruthExisting.run()

        let nonExistingSwift = tempDir + "/generated_from_sync.swift"
        var syncArazzoTruthNew = try SyncArazzo.parse(["-i", nonExistingSwift, "-o", specPath, "--truth", "arazzo"])
        try await syncArazzoTruthNew.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: nonExistingSwift))
        XCTAssertFalse(try Parser.parse(source: WASIFileHelpers.readString(at: nonExistingSwift)).hasError)

        // 8. Programmatic entrypoints on CDDCLI
        try await CDDCLI.generateArazzo(["-o", tempDir + "/ep_arazzo.json"])
        try await CDDCLI.generateFromArazzo(subcommand: "to_sdk", ["-i", specPath, "-o", tempDir + "/ep_sdk"])
        try await CDDCLI.generateFromArazzo(["-i", specPath, "-o", tempDir + "/ep_sdk_default"])
        try await CDDCLI.generateToArazzo(["-i", swiftInput, "-o", tempDir + "/ep_to_arazzo.json"])
        try await CDDCLI.syncArazzo(["-i", swiftInput, "-o", tempDir + "/ep_arazzo.json"])
    }
}
