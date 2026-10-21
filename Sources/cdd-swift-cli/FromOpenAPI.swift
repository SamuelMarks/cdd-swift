/// CLI command group for generating Swift SDKs, CLI clients, and Vapor servers from OpenAPI specifications.
import ArgumentParser
import CDDSwift
import Foundation

/// Creates a directory and all intermediate parent directories recursively using `WASIFileHelpers`.
///
/// - Parameter path: The directory path to create.
/// - Throws: `CDDError.fileIOError` if creation fails.
func createDirRecursive(_ path: String) throws {
    try WASIFileHelpers.createDirectoryRecursive(at: path)
}

/// Command group to generate Swift code from an OpenAPI document.
struct FromOpenAPI: AsyncParsableCommand {
    /// Command configuration for `from_openapi`.
    static let configuration = CommandConfiguration(
        commandName: "from_openapi",
        abstract: "Generate Swift code from an OpenAPI document.",
        subcommands: [ToSDK.self, ToSDKCLI.self, ToServer.self],
        defaultSubcommand: ToSDK.self
    )
}

/// Shared CLI options for generating Swift packages from OpenAPI specifications.
struct BaseFromOpenAPIOptions: ParsableArguments {
    /// Path to a single input OpenAPI JSON file.
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input OpenAPI JSON file.")
    var inputPath: String?

    /// Path to a directory containing one or more OpenAPI JSON files.
    @Option(name: .customLong("input-dir"), help: "Path to a directory containing OpenAPI specifications.")
    var inputDir: String?

    /// Path to the target output directory (defaults to `"."`).
    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output directory. Defaults to current working directory.")
    var outputPath: String?

    /// Flag disabling `.github/workflows/swift.yml` generation.
    @Flag(name: .customLong("no-github-actions"), help: "Do not generate GitHub Actions workflow.")
    var noGithubActions: Bool = false

    /// Flag disabling `Package.swift` scaffolding generation.
    @Flag(name: .customLong("no-installable-package"), help: "Do not generate installable package scaffolding.")
    var noInstallablePackage: Bool = false

    /// Flag enabling generation of composable mocks, tests, and Fluent database seeders.
    @Flag(name: .customLong("tests"), help: "Generate composable tests and mocks.")
    var testsMocks: Bool = false

    /// Flag enabling generation of a Model Context Protocol (MCP) server adapter.
    @Flag(name: .customLong("mcp"), help: "Generate Model Context Protocol (MCP) server and adapter.")
    var mcp: Bool = false

    /// Validates that either `--input` or `--input-dir` was supplied.
    ///
    /// - Throws: `ValidationError` if both `inputPath` and `inputDir` are `nil`.
    mutating func validate() throws {
        if inputPath == nil, inputDir == nil {
            throw ValidationError("Please provide either --input or --input-dir.")
        }
    }

    /// Loads and parses all OpenAPI documents specified by `inputPath` or `inputDir`.
    ///
    /// - Returns: Array of tuples pairing the document base filename with its parsed `OpenAPIDocument`.
    /// - Throws: `CDDError` if reading or parsing an input file fails.
    func getDocuments() throws -> [(name: String, document: OpenAPIDocument)] {
        var results: [(String, OpenAPIDocument)] = []
        if let inputPath = inputPath {
            let url = URL(fileURLWithPath: inputPath)
            let data = try WASIFileHelpers.readFile(at: inputPath)
            let json = String(decoding: data, as: UTF8.self)
            let document = try OpenAPIParser.parse(json: json)
            let name = url.deletingPathExtension().lastPathComponent
            results.append((name, document))
        } else if let inputDir = inputDir {
            let files = try WASIFileHelpers.listDirectory(at: inputDir)
            for filePath in files where filePath.hasSuffix(".json") {
                let data = try WASIFileHelpers.readFile(at: filePath)
                let json = String(decoding: data, as: UTF8.self)
                let doc = try OpenAPIParser.parse(json: json)
                let name = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
                results.append((name, doc))
            }
        }
        return results
    }

    /// Resolves the output directory path, defaulting to `"."` when `outputPath` is `nil`.
    ///
    /// - Returns: The resolved output directory path string.
    func resolveOutputDir() -> String {
        return outputPath ?? "."
    }

    /// Generates `Package.swift` and `.github/workflows/swift.yml` scaffolding in `outDir`.
    ///
    /// - Parameters:
    ///   - outDir: Target root directory for the generated package.
    ///   - packageName: Swift Package Manager package and target name.
    ///   - isExecutable: Whether the primary target is an executable (`true`) or library (`false`).
    /// - Throws: `CDDError` if directory creation or file writing fails.
    func generateScaffolding(in outDir: String, packageName: String, isExecutable: Bool = false) throws {
        let q = String(UnicodeScalar(34))
        let nl = String(UnicodeScalar(10))
        if !noInstallablePackage {
            var productStr = "        " +
                (isExecutable ? ".executable(name: \(q)\(packageName)\(q), targets: [\(q)\(packageName)\(q)])" :
                    ".library(name: \(q)\(packageName)\(q), targets: [\(q)\(packageName)\(q)])")
            var targetStr = "        " +
                (isExecutable ? ".executableTarget(name: \(q)\(packageName)\(q), dependencies: [\(q)ArgumentParser\(q)])" :
                    ".target(name: \(q)\(packageName)\(q))")

            if testsMocks && !isExecutable {
                productStr += "," + nl + "        .library(name: \(q)\(packageName)Mocks\(q), targets: [\(q)\(packageName)Mocks\(q)])"
                // Test targets are not exported as products
                targetStr += "," + nl + "        .target(name: \(q)\(packageName)Mocks\(q), dependencies: [\(q)\(packageName)\(q)])"
                targetStr += "," + nl + "        .testTarget(name: \(q)\(packageName)Tests\(q), dependencies: [\(q)\(packageName)\(q), \(q)\(packageName)Mocks\(q)])"
            }

            let depStr = isExecutable ? ".package(url: \(q)https://github.com/apple/swift-argument-parser.git\(q), from: \(q)1.2.0\(q))" : ""
            let packageSwift = """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "\(packageName)",
                products: [
            \(productStr)
                ],
                dependencies: [
                    \(depStr)
                ],
                targets: [
            \(targetStr)
                ]
            )
            """
            try createDirRecursive(outDir)
            let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
            try WASIFileHelpers.writeString(packageSwift, to: pkgUrl.path)
        }

        if !noGithubActions {
            let workflowDir = URL(fileURLWithPath: outDir).appendingPathComponent(".github/workflows")
            try createDirRecursive(workflowDir.path)
            let workflowUrl = workflowDir.appendingPathComponent("swift.yml")
            let workflow = """
            name: Swift
            on: [push, pull_request]
            jobs:
              build:
                runs-on: ubuntu-latest
                steps:
                - uses: actions/checkout@v6
                - name: Set up Swift
                  uses: swift-actions/setup-swift@v2
                  with:
                    swift-version: "6.0.3"
                - name: Build
                  run: swift build
                - name: Run tests
                  run: swift test
            """
            try WASIFileHelpers.writeString(workflow, to: workflowUrl.path)
        }
    }
}

/// CLI subcommand that generates a Swift Client SDK package from an OpenAPI specification.
struct ToSDK: AsyncParsableCommand {
    /// Command configuration for `to_sdk`.
    static let configuration = CommandConfiguration(commandName: "to_sdk", abstract: "Generate a Client SDK from an OpenAPI specification.")

    /// Shared OpenAPI generation options.
    @OptionGroup var options: BaseFromOpenAPIOptions

    /// Generates the Swift Client SDK files and optional package/test scaffolding.
    ///
    /// - Throws: `CDDError` if reading specifications or writing generated files fails.
    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDK")

        let docs = try options.getDocuments()
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir)
            .appendingPathComponent("Sources").appendingPathComponent("GeneratedSDK")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            let files = OpenAPIToSwiftGenerator.generateFiles(from: doc, tests: options.testsMocks)
            let docDir = docs.count > 1 ? srcDir.appendingPathComponent(name) : srcDir
            if docs.count > 1 {
                try createDirRecursive(docDir.path)
            }
            for (filename, code) in files {
                var targetDir = docDir
                if options.testsMocks, !options.noInstallablePackage {
                    if filename == "mocks.swift" {
                        targetDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources")
                            .appendingPathComponent("GeneratedSDKMocks")
                        if docs.count > 1 {
                            targetDir = targetDir.appendingPathComponent(name)
                        }
                        try createDirRecursive(targetDir.path)
                    } else if filename == "tests.swift" {
                        targetDir = URL(fileURLWithPath: outDir).appendingPathComponent("Tests").appendingPathComponent("GeneratedSDKTests")
                        if docs.count > 1 {
                            targetDir = targetDir.appendingPathComponent(name)
                        }
                        try createDirRecursive(targetDir.path)
                    }
                }

                let fileUrl = targetDir.appendingPathComponent(filename)
                try WASIFileHelpers.writeString(code, to: fileUrl.path)
            }
        }
    }
}

/// CLI subcommand that generates an executable `ArgumentParser` CLI client from an OpenAPI specification.
struct ToSDKCLI: AsyncParsableCommand {
    /// Command configuration for `to_sdk_cli`.
    static let configuration = CommandConfiguration(
        commandName: "to_sdk_cli",
        abstract: "Generate a Client SDK CLI from an OpenAPI specification."
    )

    /// Shared OpenAPI generation options.
    @OptionGroup var options: BaseFromOpenAPIOptions

    /// Generates the Swift CLI client files and package scaffolding.
    ///
    /// - Throws: `CDDError` if reading specifications or writing generated files fails.
    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK CLI into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDKCLI", isExecutable: true)

        let docs = try options.getDocuments()
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir)
            .appendingPathComponent("Sources").appendingPathComponent("GeneratedSDKCLI")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            if !options.noInstallablePackage {
                let sdkFiles = OpenAPIToSwiftGenerator.generateFiles(from: doc, tests: false)
                for (sdkFile, sdkCode) in sdkFiles {
                    let prefix = docs.count > 1 ? "\(name)_" : ""
                    let sdkUrl = srcDir.appendingPathComponent("\(prefix)\(sdkFile)")
                    try WASIFileHelpers.writeString(sdkCode, to: sdkUrl.path)
                }
            }
            let code = emitSDKCLI(document: doc)
            let fileUrl = srcDir.appendingPathComponent("\(name).swift") // using name instead of main if multiple
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}
