@testable import cdd_swift_cli
import CDDSwift
import Foundation
import XCTest

final class ArazzoCliTests: XCTestCase {
    private let tempDir = "/tmp/cdd_arazzo_cli_tests"

    override func setUp() {
        super.setUp()
        try? WASIFileHelpers.createDirectoryRecursive(at: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    func testGenerateFromAndToArazzoCommands() async throws {
        let specPath = tempDir + "/sample_arazzo.json"

        // 1. GenerateArazzo to file and stdout
        var genFileCmd = try GenerateArazzo.parse(["-o", specPath])
        try await genFileCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: specPath))

        var genStdoutCmd = try GenerateArazzo.parse([])
        try await genStdoutCmd.run()

        // 2. FromArazzo -> to_sdk (with and without package scaffolding, default output dir)
        let sdkDir = tempDir + "/sdk_out"
        var toSdkCmd = try ArazzoToSDK.parse(["-i", specPath, "-o", sdkDir])
        try await toSdkCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkDir + "/Package.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkDir + "/Sources/GeneratedWorkflowsSDK/WorkflowsClient.swift"))

        let sdkNoPkgDir = tempDir + "/sdk_nopkg"
        var toSdkNoPkgCmd = try ArazzoToSDK.parse(["-i", specPath, "-o", sdkNoPkgDir, "--no-installable-package"])
        try await toSdkNoPkgCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: sdkNoPkgDir + "/WorkflowsClient.swift"))

        let optsDefault = try BaseFromArazzoOptions.parse(["-i", specPath])
        XCTAssertEqual(optsDefault.resolveOutputDir(), ".")

        // 3. FromArazzo -> to_sdk_cli (with and without package scaffolding)
        let cliDir = tempDir + "/cli_out"
        var toCliCmd = try ArazzoToSDKCLI.parse(["-i", specPath, "-o", cliDir])
        try await toCliCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliDir + "/Package.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliDir + "/Sources/GeneratedWorkflowsCLI/WorkflowCLI.swift"))

        let cliNoPkgDir = tempDir + "/cli_nopkg"
        var toCliNoPkgCmd = try ArazzoToSDKCLI.parse(["-i", specPath, "-o", cliNoPkgDir, "--no-installable-package"])
        try await toCliNoPkgCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: cliNoPkgDir + "/WorkflowCLI.swift"))

        // 4. FromArazzo -> to_test
        let testDir = tempDir + "/test_out"
        var toTestCmd = try ArazzoToTest.parse(["-i", specPath, "-o", testDir])
        try await toTestCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: testDir + "/GeneratedArazzoWorkflowTests.swift"))

        // 5. FromArazzo -> to_server
        let serverDir = tempDir + "/server_out"
        var toServerCmd = try ArazzoToServer.parse(["-i", specPath, "-o", serverDir])
        try await toServerCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: serverDir + "/ServerWorkflowOrchestrator.swift"))

        // 6. ToArazzo (JSON and YAML, file and stdout)
        let swiftInput = sdkNoPkgDir + "/WorkflowsClient.swift"
        let extractedJsonPath = tempDir + "/extracted.json"
        var toArazzoJsonCmd = try ToArazzo.parse(["-i", swiftInput, "-o", extractedJsonPath])
        try await toArazzoJsonCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: extractedJsonPath))

        let extractedYamlPath = tempDir + "/extracted.yaml"
        var toArazzoYamlCmd = try ToArazzo.parse(["-i", swiftInput, "-o", extractedYamlPath, "--format", "yaml"])
        try await toArazzoYamlCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: extractedYamlPath))

        var toArazzoStdoutCmd = try ToArazzo.parse(["-i", swiftInput])
        try await toArazzoStdoutCmd.run()

        // 7. SyncArazzo (truth=swift and truth=arazzo)
        var syncSwiftTruthCmd = try SyncArazzo.parse(["-i", swiftInput, "-o", specPath, "--truth", "swift"])
        try await syncSwiftTruthCmd.run()

        // SyncArazzo when swift has a new workflow not in existing spec
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

        // SyncArazzo when output spec doesn't exist yet
        let newSpecOut = tempDir + "/brand_new_arazzo.json"
        var syncNewOutCmd = try SyncArazzo.parse(["-i", swiftInput, "-o", newSpecOut, "--truth", "swift"])
        try await syncNewOutCmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: newSpecOut))

        // SyncArazzo with truth=arazzo into existing and non-existing swift file
        var syncArazzoTruthExisting = try SyncArazzo.parse(["-i", swiftInput, "-o", specPath, "--truth", "arazzo"])
        try await syncArazzoTruthExisting.run()

        let nonExistingSwift = tempDir + "/generated_from_sync.swift"
        var syncArazzoTruthNew = try SyncArazzo.parse(["-i", nonExistingSwift, "-o", specPath, "--truth", "arazzo"])
        try await syncArazzoTruthNew.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: nonExistingSwift))

        // 8. Programmatic entrypoints on CDDCLI
        try await CDDCLI.generateArazzo(["-o", tempDir + "/ep_arazzo.json"])
        try await CDDCLI.generateFromArazzo(subcommand: "to_sdk", ["-i", specPath, "-o", tempDir + "/ep_sdk"])
        try await CDDCLI.generateFromArazzo(["-i", specPath, "-o", tempDir + "/ep_sdk_default"])
        try await CDDCLI.generateToArazzo(["-i", swiftInput, "-o", tempDir + "/ep_to_arazzo.json"])
        try await CDDCLI.syncArazzo(["-i", swiftInput, "-o", tempDir + "/ep_arazzo.json"])
    }
}
