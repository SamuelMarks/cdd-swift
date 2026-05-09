import ArgumentParser
import CDDSwift
import Foundation

func createDirRecursive(_ path: String) throws {
    let components = path.split(separator: "/")
    var currentPath = path.hasPrefix("/") ? "/" : ""
    for component in components {
        if currentPath == "/" {
            currentPath += component
        } else if currentPath == "" {
            currentPath += component
        } else {
            currentPath += "/" + component
        }
        if !WASIFileHelpers.fileExists(at: currentPath) {
            try WASIFileHelpers.createDirectory(at: currentPath)
        }
    }
}

/// Command group to generate Swift code from an OpenAPI document.
struct FromOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "from_openapi",
        abstract: "Generate Swift code from an OpenAPI document.",
        subcommands: [ToSDK.self, ToSDKCLI.self, ToServer.self],
        defaultSubcommand: ToSDK.self
    )
}

/// Base options for generating outputs from OpenAPI
struct BaseFromOpenAPIOptions: ParsableArguments {
    @Option(name: [.customShort("i"), .customLong("input")], help: "Path to the input OpenAPI JSON file.")
    var inputPath: String?

    @Option(name: .customLong("input-dir"), help: "Path to a directory containing OpenAPI specifications.")
    var inputDir: String?

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output directory. Defaults to current working directory.")
    var outputPath: String?

    @Flag(name: .customLong("no-github-actions"), help: "Do not generate GitHub Actions workflow.")
    var noGithubActions: Bool = false

    @Flag(name: .customLong("no-installable-package"), help: "Do not generate installable package scaffolding.")
    var noInstallablePackage: Bool = false

    mutating func validate() throws {
        if inputPath == nil && inputDir == nil {
            throw ValidationError("Please provide either --input or --input-dir.")
        }
    }

    func getDocuments() throws -> [(name: String, document: OpenAPIDocument)] {
        var results: [(String, OpenAPIDocument)] = []
        if let inputPath = inputPath {
            let url = URL(fileURLWithPath: inputPath)
            
            let data = try WASIFileHelpers.readFile(at: inputPath)
            
            let json = String(data: data, encoding: .utf8) ?? ""
            let document = try OpenAPIParser.parse(json: json)
            let name = url.deletingPathExtension().lastPathComponent
            results.append((name, document))
        } else if let inputDir = inputDir {
            let files = try WASIFileHelpers.listDirectory(at: inputDir)
            for filePath in files {
                if filePath.hasSuffix(".json") {
                    guard let data = try? WASIFileHelpers.readFile(at: filePath) else { continue }
                    
                    if let json = String(data: data, encoding: .utf8), let doc = try? OpenAPIParser.parse(json: json) {
                        let name = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
                        results.append((name, doc))
                    }
                }
            }
        }
        return results
    }

    func resolveOutputDir() -> String {
        return outputPath ?? "."
    }

    func generateScaffolding(in outDir: String, packageName: String, isExecutable: Bool = false) throws {
        if !noInstallablePackage {
            let productStr = isExecutable ? ".executable(name: \"\(packageName)\", targets: [\"\(packageName)\"])" : ".library(name: \"\(packageName)\", targets: [\"\(packageName)\"])"
            let targetStr = isExecutable ? ".executableTarget(name: \"\(packageName)\", dependencies: [\"ArgumentParser\"])" : ".target(name: \"\(packageName)\")"
            let depStr = isExecutable ? ".package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.2.0\")" : ""
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

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
            try WASIFileHelpers.writeString(workflow, to: workflowUrl.path)
        }
    }
}

struct ToSDK: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk", abstract: "Generate a Swift SDK from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDK")

        let docs = try options.getDocuments()
        let srcDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDK")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            let code = OpenAPIToSwiftGenerator.generate(from: doc)
            let fileUrl = srcDir.appendingPathComponent("\(name).swift")
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}

struct ToSDKCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk_cli", abstract: "Generate a typed Swift CLI from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK CLI into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDKCLI", isExecutable: true)

        let docs = try options.getDocuments()
        let srcDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDKCLI")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            let code = emitSDKCLI(document: doc)
            let fileUrl = srcDir.appendingPathComponent("\(name).swift") // using name instead of main if multiple
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}

struct ToServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_server", abstract: "Generate a Swift server stub from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating Server into \(outDir)")
        try createDirRecursive(outDir)

        if !options.noInstallablePackage {
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            let package = Package(
                name: "GeneratedServer",
                platforms: [
                   .macOS(.v13)
                ],
                dependencies: [
                    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0")
                ],
                targets: [
                    .executableTarget(
                        name: "GeneratedServer",
                        dependencies: [
                            .product(name: "Vapor", package: "vapor")
                        ]
                    )
                ]
            )
            """
            let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
            try WASIFileHelpers.writeString(packageSwift, to: pkgUrl.path)
        }

        if !options.noGithubActions {
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
            try WASIFileHelpers.writeString(workflow, to: workflowUrl.path)
        }

        let docs = try options.getDocuments()
        let srcDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedServer")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            let code = emitServer(document: doc)
            let fileUrl = srcDir.appendingPathComponent("\(name).swift")
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}
