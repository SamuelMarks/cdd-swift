/// CLI command group for generating Swift SDKs, CLIs, tests, and servers from Arazzo 1.1.0 specifications.
import ArgumentParser
import CDDSwift
import Foundation

/// Command group to generate Swift code from an Arazzo 1.1.0 specification.
struct FromArazzo: AsyncParsableCommand {
    /// The CommandConfiguration for `from_arazzo`.
    static let configuration = CommandConfiguration(
        commandName: "from_arazzo",
        abstract: "Generate Swift code from an Arazzo 1.1.0 workflow specification.",
        subcommands: [ArazzoToSDK.self, ArazzoToSDKCLI.self, ArazzoToTest.self, ArazzoToServer.self],
        defaultSubcommand: ArazzoToSDK.self
    )
}

/// Shared CLI arguments for `from_arazzo` subcommands.
struct BaseFromArazzoOptions: ParsableArguments {
    /// Path to the input Arazzo JSON file.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input Arazzo JSON file.")
    var inputPath: String

    /// Path to the output directory or file. Defaults to current working directory.
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output directory.")
    var outputPath: String?

    /// Do not generate installable Swift Package scaffolding.
    @Flag(name: .customLong("no-installable-package"), help: "Do not generate installable package scaffolding.")
    var noInstallablePackage: Bool = false

    /// Parses and returns the `ArazzoSpecification` from `inputPath`.
    ///
    /// - Returns: Decoded `ArazzoSpecification`.
    /// - Throws: `CDDError` if reading or parsing fails.
    func loadSpecification() throws -> ArazzoSpecification {
        let json = try WASIFileHelpers.readString(at: inputPath)
        return try ArazzoEmitter.parse(json: json)
    }

    /// Resolves the target output directory path.
    ///
    /// - Returns: Resolved directory path string.
    func resolveOutputDir() -> String {
        return outputPath ?? "."
    }

    /// Writes `Package.swift` scaffolding if `noInstallablePackage` is false.
    ///
    /// - Parameters:
    ///   - outDir: Target directory path.
    ///   - packageName: Name of the generated Swift package.
    ///   - isExecutable: Whether the package builds a CLI executable.
    /// - Throws: `CDDError.fileIOError` if writing fails.
    func writeScaffoldingIfNeeded(in outDir: String, packageName: String, isExecutable: Bool = false) throws {
        try createDirRecursive(outDir)
        guard !noInstallablePackage else { return }
        let q = String(UnicodeScalar(34))
        let productLine = isExecutable
            ? ".executable(name: " + q + packageName + q + ", targets: [" + q + packageName + q + "])"
            : ".library(name: " + q + packageName + q + ", targets: [" + q + packageName + q + "])"
        let depLine = isExecutable
            ? ".package(url: " + q + "https://github.com/apple/swift-argument-parser.git" + q + ", from: " + q + "1.2.0" + q + ")"
            : ""
        let targetLine = isExecutable
            ? ".executableTarget(name: " + q + packageName + q + ", dependencies: [" + q + "ArgumentParser" + q + "])"
            : ".target(name: " + q + packageName + q + ")"

        let packageSwift = """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(packageName)",
            products: [
                \(productLine)
            ],
            dependencies: [
                \(depLine)
            ],
            targets: [
                \(targetLine)
            ]
        )
        """
        let pkgPath = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift").path
        try WASIFileHelpers.writeString(packageSwift, to: pkgPath)
    }
}

/// Generates a Swift Workflow Client SDK from an Arazzo 1.1.0 specification.
struct ArazzoToSDK: AsyncParsableCommand {
    /// The CommandConfiguration for `to_sdk`.
    static let configuration = CommandConfiguration(
        commandName: "to_sdk",
        abstract: "Generate a Swift Workflow Client SDK from an Arazzo specification."
    )

    /// Shared options for `from_arazzo`.
    @OptionGroup var options: BaseFromArazzoOptions

    /// Executes the `to_sdk` generation command.
    ///
    /// - Throws: `CDDError` if loading the specification or writing output files fails.
    mutating func run() async throws {
        let spec = try options.loadSpecification()
        let outDir = options.resolveOutputDir()
        try options.writeScaffoldingIfNeeded(in: outDir, packageName: "GeneratedWorkflowsSDK")
        let targetDir = options.noInstallablePackage
            ? URL(fileURLWithPath: outDir)
            : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedWorkflowsSDK")
        try createDirRecursive(targetDir.path)
        let code = ArazzoSdkEmitter.emitWorkflowClient(from: spec)
        try WASIFileHelpers.writeString(code, to: targetDir.appendingPathComponent("WorkflowsClient.swift").path)
        print("✅ Generated Arazzo Workflow SDK in \(outDir)")
    }
}

/// Generates a Swift CLI Workflow Runner from an Arazzo 1.1.0 specification.
struct ArazzoToSDKCLI: AsyncParsableCommand {
    /// The CommandConfiguration for `to_sdk_cli`.
    static let configuration = CommandConfiguration(
        commandName: "to_sdk_cli",
        abstract: "Generate a Swift CLI Workflow Runner from an Arazzo specification."
    )

    /// Shared options for `from_arazzo`.
    @OptionGroup var options: BaseFromArazzoOptions

    /// Executes the `to_sdk_cli` generation command.
    ///
    /// - Throws: `CDDError` if loading the specification or writing output files fails.
    mutating func run() async throws {
        let spec = try options.loadSpecification()
        let outDir = options.resolveOutputDir()
        try options.writeScaffoldingIfNeeded(in: outDir, packageName: "GeneratedWorkflowsCLI", isExecutable: true)
        let targetDir = options.noInstallablePackage
            ? URL(fileURLWithPath: outDir)
            : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedWorkflowsCLI")
        try createDirRecursive(targetDir.path)
        let code = ArazzoCliEmitter.emitWorkflowCLI(from: spec)
        try WASIFileHelpers.writeString(code, to: targetDir.appendingPathComponent("WorkflowCLI.swift").path)
        print("✅ Generated Arazzo Workflow CLI in \(outDir)")
    }
}

/// Generates an executable XCTest and Swift Testing integration suite from an Arazzo 1.1.0 specification.
struct ArazzoToTest: AsyncParsableCommand {
    /// The CommandConfiguration for `to_test`.
    static let configuration = CommandConfiguration(
        commandName: "to_test",
        abstract: "Generate Swift XCTest and Swift Testing suites from an Arazzo specification."
    )

    /// Shared options for `from_arazzo`.
    @OptionGroup var options: BaseFromArazzoOptions

    /// Executes the `to_test` generation command.
    ///
    /// - Throws: `CDDError` if loading the specification or writing output files fails.
    mutating func run() async throws {
        let spec = try options.loadSpecification()
        let outDir = options.resolveOutputDir()
        try createDirRecursive(outDir)
        let code = ArazzoTestEmitter.emitTestSuite(from: spec)
        let targetFile = URL(fileURLWithPath: outDir).appendingPathComponent("GeneratedArazzoWorkflowTests.swift").path
        try WASIFileHelpers.writeString(code, to: targetFile)
        print("✅ Generated Arazzo Workflow Tests in \(outDir)")
    }
}

/// Generates a server-side synthetic workflow driver and healthcheck probe orchestrator from an Arazzo 1.1.0 specification.
struct ArazzoToServer: AsyncParsableCommand {
    /// The CommandConfiguration for `to_server`.
    static let configuration = CommandConfiguration(
        commandName: "to_server",
        abstract: "Generate server-side workflow orchestrators and healthcheck probes from an Arazzo specification."
    )

    /// Shared options for `from_arazzo`.
    @OptionGroup var options: BaseFromArazzoOptions

    /// Executes the `to_server` generation command.
    ///
    /// - Throws: `CDDError` if loading the specification or writing output files fails.
    mutating func run() async throws {
        let spec = try options.loadSpecification()
        let outDir = options.resolveOutputDir()
        try createDirRecursive(outDir)
        let code = ArazzoServerEmitter.emitServerOrchestrator(from: spec)
        let targetFile = URL(fileURLWithPath: outDir).appendingPathComponent("ServerWorkflowOrchestrator.swift").path
        try WASIFileHelpers.writeString(code, to: targetFile)
        print("✅ Generated Arazzo Server Orchestrator in \(outDir)")
    }
}
