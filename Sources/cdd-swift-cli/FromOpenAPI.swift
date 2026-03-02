import ArgumentParser
import CDDSwift
import Foundation

/// Command group to generate Swift code from an OpenAPI document.
struct FromOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "from_openapi",
        abstract: "Generate Swift code from an OpenAPI document.",
        subcommands: [ToSDK.self, ToSDKCLI.self, ToServer.self]
    )
}

/// Base options for generating outputs from OpenAPI
struct BaseFromOpenAPIOptions: ParsableArguments {
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input OpenAPI JSON file.")
    /// Path to the input OpenAPI JSON file.
    var inputPath: String?

    @Option(name: .customLong("input-dir"), help: "Path to a directory containing OpenAPI specifications.")
    /// Path to a directory containing OpenAPI specifications.
    var inputDir: String?

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output directory. Defaults to current working directory.")
    /// Path to the output directory.
    var outputPath: String?

    @Flag(name: .customLong("no-github-actions"), help: "Do not generate GitHub Actions workflow.")
    /// Do not generate GitHub Actions workflow.
    var noGithubActions: Bool = false

    @Flag(name: .customLong("no-installable-package"), help: "Do not generate installable package scaffolding.")
    /// Do not generate installable package scaffolding.
    var noInstallablePackage: Bool = false

    mutating func validate() throws {
        if inputPath == nil && inputDir == nil {
            throw ValidationError("Please provide either --input or --input-dir.")
        }
    }

    /// Resolves the output directory to be used.
    func resolveOutputDir() -> String {
        return outputPath ?? FileManager.default.currentDirectoryPath
    }

    /// Generate scaffolding
    func generateScaffolding(in outDir: String, packageName: String, isExecutable: Bool = false) throws {
        /// file manager
        let fm = FileManager.default
        if !noInstallablePackage {
            /// Documentation for productStr
            let productStr = isExecutable ? ".executable(name: \"\(packageName)\", targets: [\"\(packageName)\"])" : ".library(name: \"\(packageName)\", targets: [\"\(packageName)\"])"
            /// Documentation for targetStr
            let targetStr = isExecutable ? ".executableTarget(name: \"\(packageName)\", dependencies: [\"ArgumentParser\"])" : ".target(name: \"\(packageName)\")"
            /// Documentation for depStr
            let depStr = isExecutable ? ".package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.2.0\")" : ""
            /// package Swift string
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            /// package definition
            let package = Package(
                name: "\(packageName)",
                products: [
                    \(productStr),
                ],
                dependencies: [
                    \(depStr)
                ],
                targets: [
                    \(targetStr),
                ]
            )
            """
            try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            /// package URL
            let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
            try packageSwift.write(to: pkgUrl, atomically: true, encoding: .utf8)
        }
        
        if !noGithubActions {
            /// workflow dir
            let workflowDir = URL(fileURLWithPath: outDir).appendingPathComponent(".github/workflows")
            try fm.createDirectory(atPath: workflowDir.path, withIntermediateDirectories: true)
            /// workflow url
            let workflowUrl = workflowDir.appendingPathComponent("swift.yml")
            /// workflow string
            let workflow = """
            name: Swift
            on: [push, pull_request]
            jobs:
              build:
                runs-on: ubuntu-latest
                steps:
                - uses: actions/checkout@v4
                - name: Set up Swift
                  uses: swift-actions/setup-swift@v2
                  with:
                    swift-version: "6.0"
                - name: Build
                  run: swift build
                - name: Run tests
                  run: swift test
            """
            try workflow.write(to: workflowUrl, atomically: true, encoding: .utf8)
        }
    }
}

/// Command to generate a Swift SDK from an OpenAPI document.
struct ToSDK: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk", abstract: "Generate a Swift SDK from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Resolved output directory
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK into \(outDir)")
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDK")
    }
}

/// Command to generate a typed Swift CLI from an OpenAPI document.
struct ToSDKCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk_cli", abstract: "Generate a typed Swift CLI from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Documentation for outDir
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK CLI into \(outDir)")
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDKCLI", isExecutable: true)
        
        // Write the SDK CLI main
        guard let inputPath = options.inputPath else { return }
        /// Documentation for url
        let url = URL(fileURLWithPath: inputPath)
        /// Documentation for data
        let data = try Data(contentsOf: url)
        /// Documentation for json
        let json = String(data: data, encoding: .utf8) ?? ""
        /// Documentation for document
        let document = try OpenAPIParser.parse(json: json)
        
        /// Documentation for srcDir
        let srcDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDKCLI")
        try FileManager.default.createDirectory(atPath: srcDir.path, withIntermediateDirectories: true)
        
        /// Documentation for code
        let code = emitSDKCLI(document: document)
        /// Documentation for fileUrl
        let fileUrl = srcDir.appendingPathComponent("main.swift")
        try code.write(to: fileUrl, atomically: true, encoding: .utf8)
    }
}

/// Command to generate a Swift server stub from an OpenAPI document.
struct ToServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_server", abstract: "Generate a Swift server stub from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Resolved output directory
        let outDir = options.resolveOutputDir()
        print("✅ Generating Server into \(outDir)")
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedServer")
    }
}
