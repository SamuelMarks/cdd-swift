import ArgumentParser
import CDDSwift
import Foundation

/// Documentation for createDirRecursive
func createDirRecursive(_ path: String) throws {
    /// Documentation for components
    let components = path.split(separator: "/")
    /// Documentation for currentPath
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
    /// Documentation for inputPath
    var inputPath: String?

    @Option(name: .customLong("input-dir"), help: "Path to a directory containing OpenAPI specifications.")
    /// Documentation for inputDir
    var inputDir: String?

    @Option(name: [.customShort("o"), .customLong("output")], help: "Path to the output directory. Defaults to current working directory.")
    /// Documentation for outputPath
    var outputPath: String?

    @Flag(name: .customLong("no-github-actions"), help: "Do not generate GitHub Actions workflow.")
    /// Documentation for noGithubActions
    var noGithubActions: Bool = false

    @Flag(name: .customLong("no-installable-package"), help: "Do not generate installable package scaffolding.")
    /// Documentation for noInstallablePackage
    var noInstallablePackage: Bool = false

    @Flag(name: [.customLong("create-composable-tests-mocks"), .customLong("tests")], help: "Create composable tests & mocks.")
    /// Documentation for testsMocks
    var testsMocks: Bool = false

    mutating func validate() throws {
        if inputPath == nil, inputDir == nil {
            throw ValidationError("Please provide either --input or --input-dir.")
        }
    }

    /// Documentation for getDocuments
    func getDocuments() throws -> [(name: String, document: OpenAPIDocument)] {
        /// Documentation for results
        var results: [(String, OpenAPIDocument)] = []
        if let inputPath = inputPath {
            /// Documentation for url
            let url = URL(fileURLWithPath: inputPath)

            /// Documentation for data
            let data = try WASIFileHelpers.readFile(at: inputPath)

            /// Documentation for json
            let json = String(data: data, encoding: .utf8) ?? ""
            /// Documentation for document
            let document = try OpenAPIParser.parse(json: json)
            /// Documentation for name
            let name = url.deletingPathExtension().lastPathComponent
            results.append((name, document))
        } else if let inputDir = inputDir {
            /// Documentation for files
            let files = try WASIFileHelpers.listDirectory(at: inputDir)
            for filePath in files where filePath.hasSuffix(".json") {
                guard let data = try? WASIFileHelpers.readFile(at: filePath) else { continue }

                if let json = String(data: data, encoding: .utf8), let doc = try? OpenAPIParser.parse(json: json) {
                    /// Documentation for name
                    let name = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
                    results.append((name, doc))
                }
            }
        }
        return results
    }

    /// Documentation for resolveOutputDir
    func resolveOutputDir() -> String {
        return outputPath ?? "."
    }

    /// Documentation for generateScaffolding
    func generateScaffolding(in outDir: String, packageName: String, isExecutable: Bool = false) throws {
        if !noInstallablePackage {
            var productStr = "        " + (isExecutable ? ".executable(name: \"\(packageName)\", targets: [\"\(packageName)\"])" : ".library(name: \"\(packageName)\", targets: [\"\(packageName)\"])")
            var targetStr = "        " + (isExecutable ? ".executableTarget(name: \"\(packageName)\", dependencies: [\"ArgumentParser\"])" : ".target(name: \"\(packageName)\")")

            if testsMocks && !isExecutable {
                productStr += ",\n        .library(name: \"\(packageName)Mocks\", targets: [\"\(packageName)Mocks\"])"
                // Test targets are not exported as products
                targetStr += ",\n        .target(name: \"\(packageName)Mocks\", dependencies: [\"\(packageName)\"])"
                targetStr += ",\n        .testTarget(name: \"\(packageName)Tests\", dependencies: [\"\(packageName)\", \"\(packageName)Mocks\"])"
            }

            /// Documentation for depStr
            let depStr = isExecutable ? ".package(url: \"https://github.com/apple/swift-argument-parser.git\", from: \"1.2.0\")" : ""
            /// Documentation for packageSwift
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            /// Documentation for package
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
            /// Documentation for pkgUrl
            let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
            try WASIFileHelpers.writeString(packageSwift, to: pkgUrl.path)
        }

        if !noGithubActions {
            /// Documentation for workflowDir
            let workflowDir = URL(fileURLWithPath: outDir).appendingPathComponent(".github/workflows")
            try createDirRecursive(workflowDir.path)
            /// Documentation for workflowUrl
            let workflowUrl = workflowDir.appendingPathComponent("swift.yml")
            /// Documentation for workflow
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

/// Documentation for ToSDK
struct ToSDK: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk", abstract: "Generate a Swift SDK from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Documentation for outDir
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDK")

        /// Documentation for docs
        let docs = try options.getDocuments()
        /// Documentation for srcDir
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDK")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            /// Documentation for files
            let files = OpenAPIToSwiftGenerator.generateFiles(from: doc, tests: options.testsMocks)
            /// Documentation for docDir
            let docDir = docs.count > 1 ? srcDir.appendingPathComponent(name) : srcDir
            if docs.count > 1 {
                try createDirRecursive(docDir.path)
            }
            for (filename, code) in files {
                /// Documentation for fileUrl
                var targetDir = docDir
                if options.testsMocks, !options.noInstallablePackage {
                    if filename == "mocks.swift" {
                        targetDir = URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDKMocks")
                        if docs.count > 1 { targetDir = targetDir.appendingPathComponent(name) }
                        try createDirRecursive(targetDir.path)
                    } else if filename == "tests.swift" {
                        targetDir = URL(fileURLWithPath: outDir).appendingPathComponent("Tests").appendingPathComponent("GeneratedSDKTests")
                        if docs.count > 1 { targetDir = targetDir.appendingPathComponent(name) }
                        try createDirRecursive(targetDir.path)
                    }
                }

                let fileUrl = targetDir.appendingPathComponent(filename)
                try WASIFileHelpers.writeString(code, to: fileUrl.path)
            }
        }
    }
}

/// Documentation for ToSDKCLI
struct ToSDKCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk_cli", abstract: "Generate a typed Swift CLI from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Documentation for outDir
        let outDir = options.resolveOutputDir()
        print("✅ Generating SDK CLI into \(outDir)")
        try createDirRecursive(outDir)
        try options.generateScaffolding(in: outDir, packageName: "GeneratedSDKCLI", isExecutable: true)

        /// Documentation for docs
        let docs = try options.getDocuments()
        /// Documentation for srcDir
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedSDKCLI")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            /// Documentation for code
            let code = emitSDKCLI(document: doc)
            /// Documentation for fileUrl
            let fileUrl = srcDir.appendingPathComponent("\(name).swift") // using name instead of main if multiple
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}

/// Documentation for ToServer
struct ToServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_server", abstract: "Generate a Swift server stub from an OpenAPI document.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Documentation for outDir
        let outDir = options.resolveOutputDir()
        print("✅ Generating Server into \(outDir)")
        try createDirRecursive(outDir)

        if !options.noInstallablePackage {
            /// Documentation for packageSwift
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            /// Documentation for package
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
            /// Documentation for pkgUrl
            let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
            try WASIFileHelpers.writeString(packageSwift, to: pkgUrl.path)
        }

        if !options.noGithubActions {
            /// Documentation for workflowDir
            let workflowDir = URL(fileURLWithPath: outDir).appendingPathComponent(".github/workflows")
            try createDirRecursive(workflowDir.path)
            /// Documentation for workflowUrl
            let workflowUrl = workflowDir.appendingPathComponent("swift.yml")
            /// Documentation for workflow
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
                    swift-version: "6.0"
                - name: Build
                  run: swift build
                - name: Run tests
                  run: swift test
            """
            try WASIFileHelpers.writeString(workflow, to: workflowUrl.path)
        }

        /// Documentation for docs
        let docs = try options.getDocuments()
        /// Documentation for srcDir
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedServer")
        try createDirRecursive(srcDir.path)
        for (name, doc) in docs {
            /// Documentation for code
            let code = emitServer(document: doc)
            /// Documentation for fileUrl
            let fileUrl = srcDir.appendingPathComponent("\(name).swift")
            try WASIFileHelpers.writeString(code, to: fileUrl.path)
        }
    }
}
