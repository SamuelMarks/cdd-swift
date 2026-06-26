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

    @Flag(name: .customLong("tests"), help: "Generate composable tests and mocks.")
    /// Documentation for testsMocks
    var testsMocks: Bool = false

    @Flag(name: .customLong("mcp"), help: "Generate Model Context Protocol (MCP) server and adapter.")
    var mcp: Bool = false

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
            let json = String(decoding: data, as: UTF8.self)
            /// Documentation for document
            let document = try OpenAPIParser.parse(json: json)
            /// Documentation for name
            let name = url.deletingPathExtension().lastPathComponent
            results.append((name, document))
        } else if let inputDir = inputDir {
            /// Documentation for files
            let files = try WASIFileHelpers.listDirectory(at: inputDir)
            for filePath in files where filePath.hasSuffix(".json") {
                let data = try WASIFileHelpers.readFile(at: filePath)
                let json = String(decoding: data, as: UTF8.self)
                if let doc = try? OpenAPIParser.parse(json: json) {
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
            // swift-tools-version: 6.0
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

/// Documentation for ToSDK
struct ToSDK: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "to_sdk", abstract: "Generate a Client SDK from an OpenAPI specification.")

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
    static let configuration = CommandConfiguration(commandName: "to_sdk_cli", abstract: "Generate a Client SDK CLI from an OpenAPI specification.")

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
    static let configuration = CommandConfiguration(commandName: "to_server", abstract: "Generate a Server stub from an OpenAPI specification.")

    @OptionGroup var options: BaseFromOpenAPIOptions

    mutating func run() async throws {
        /// Documentation for outDir
        let outDir = options.resolveOutputDir()
        print("✅ Generating Server into \(outDir)")
        try createDirRecursive(outDir)

        if !options.noInstallablePackage {
            let vaporDeps = ".package(url: \"https://github.com/vapor/vapor.git\", from: \"4.113.2\")"
            let dbDeps = options.testsMocks ? ",\n                    .package(url: \"https://github.com/vapor/fluent.git\", from: \"4.8.0\"),\n                    .package(url: \"https://github.com/vapor/fluent-sqlite-driver.git\", from: \"4.1.0\"),\n                    .package(url: \"https://github.com/vadymmarkov/Fakery.git\", from: \"5.0.0\")" : ""

            let vaporTargetDeps = ".product(name: \"Vapor\", package: \"vapor\")"
            let dbTargetDeps = options.testsMocks ? ",\n                            .product(name: \"Fluent\", package: \"fluent\"),\n                            .product(name: \"FluentSQLiteDriver\", package: \"fluent-sqlite-driver\"),\n                            .product(name: \"Fakery\", package: \"Fakery\")" : ""

            let testsTarget = options.testsMocks ? ",\n                    .testTarget(\n                        name: \"GeneratedServerTests\",\n                        dependencies: [\n                            .target(name: \"GeneratedServer\"),\n                            .product(name: \"XCTVapor\", package: \"vapor\")\n                        ]\n                    )" : ""

            /// Documentation for packageSwift
            let packageSwift = """
            // swift-tools-version: 6.0
            import PackageDescription

            /// Documentation for package
            let package = Package(
                name: "GeneratedServer",
                platforms: [
                   .macOS(.v13)
                ],
                dependencies: [
                    \(vaporDeps)\(dbDeps)
                ],
                targets: [
                    .executableTarget(
                        name: "GeneratedServer",
                        dependencies: [
                            \(vaporTargetDeps)\(dbTargetDeps)
                        ]
                    )\(testsTarget)
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
                    swift-version: "6.0.3"
                - name: Build
                  run: swift build
                - name: Run tests
                  run: swift test
            """
            try WASIFileHelpers.writeString(workflow, to: workflowUrl.path)
        }

        if !options.noInstallablePackage {
            let testsDir = URL(fileURLWithPath: outDir).appendingPathComponent("Tests").appendingPathComponent("GeneratedServerTests")
            try createDirRecursive(testsDir.path)

            let sortedSchemas = (try? options.getDocuments().first?.document.components?.schemas?.keys.sorted()) ?? []

            var stubModeCode = """
            import XCTVapor
            @testable import GeneratedServer

            /// Tests for the stub mode.
            final class StubModeTests: XCTestCase {
                /// Tests the stub mode of the server.
                func testStubMode() async throws {
                    let app = try await Application.make(.testing)
                    defer { Task { try? await app.asyncShutdown() } }
                    try routes(app)
            """
            if let firstSchema = sortedSchemas.first {
                stubModeCode += """

                        try app.test(.GET, "\(firstSchema.lowercased())s") { req in
                            XCTAssertEqual(req.status, .notImplemented)
                        }
                """
            }
            stubModeCode += """

                }
            }
            """
            try WASIFileHelpers.writeString(stubModeCode, to: testsDir.appendingPathComponent("StubModeTests.swift").path)

            var ephemeralModeCode = """
            import XCTVapor
            @testable import GeneratedServer

            /// Tests for the ephemeral mode.
            final class EphemeralModeTests: XCTestCase {
                /// Tests the ephemeral mode
                func testEphemeralMode() async throws {
                    let app = try await Application.make(.testing)
                    defer { Task { try? await app.asyncShutdown() } }
                    app.databases.use(.sqlite(.memory), as: .sqlite)
            """
            for schema in sortedSchemas {
                ephemeralModeCode += "\n        app.migrations.add(Create\(schema)())"
            }
            ephemeralModeCode += """

                    try await app.autoMigrate()
                    try routes(app)
            """
            if let firstSchema = sortedSchemas.first {
                ephemeralModeCode += """

                        try app.test(.GET, "\(firstSchema.lowercased())s") { req in
                            // Without seeder, should be empty array instead of 501
                            XCTAssertEqual(req.status, .ok)
                            let body = req.body.string
                            XCTAssertEqual(body, "[]")
                        }
                """
            }
            ephemeralModeCode += """

                }
            }
            """
            try WASIFileHelpers.writeString(ephemeralModeCode, to: testsDir.appendingPathComponent("EphemeralModeTests.swift").path)

            var seededModeCode = """
            import XCTVapor
            @testable import GeneratedServer

            /// Tests for the seeded mode.
            final class SeededModeTests: XCTestCase {
                /// Tests the seeded mode
                func testSeededMode() async throws {
                    let app = try await Application.make(.testing)
                    defer { Task { try? await app.asyncShutdown() } }
                    app.databases.use(.sqlite(.memory), as: .sqlite)
            """
            for schema in sortedSchemas {
                seededModeCode += "\n        app.migrations.add(Create\(schema)())"
            }
            seededModeCode += """

                    try await app.autoMigrate()
                    try await DatabaseSeeder.seed(on: app.db)
                    try routes(app)
            """
            if let firstSchema = sortedSchemas.first {
                seededModeCode += """

                        try app.test(.GET, "\(firstSchema.lowercased())s") { req in
                            XCTAssertEqual(req.status, .ok)
                            let body = req.body.string
                            XCTAssertTrue(body.count > 2) // Should contain json elements
                        }
                """
            }
            seededModeCode += """

                }
            }
            """
            try WASIFileHelpers.writeString(seededModeCode, to: testsDir.appendingPathComponent("SeededModeTests.swift").path)

            let authMiddlewareCode = """
            import XCTVapor
            @testable import GeneratedServer

            /// Tests for the auth middleware.
            final class AuthMiddlewareTests: XCTestCase {
                /// Tests the auth middleware mock
                func testAuthMiddlewareMock() async throws {
                    let app = try await Application.make(.testing)
                    defer { Task { try? await app.asyncShutdown() } }

                    try routes(app)

                    try app.test(.GET, "_mock/trigger-webhook/test") { req in
                        XCTAssertEqual(req.status, .ok)
                    }
                }
            }
            """
            try WASIFileHelpers.writeString(authMiddlewareCode, to: testsDir.appendingPathComponent("AuthMiddlewareTests.swift").path)
        }

        /// Documentation for docs
        let docs = try options.getDocuments()
        /// Documentation for srcDir
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir).appendingPathComponent("Sources").appendingPathComponent("GeneratedServer")
        try createDirRecursive(srcDir.path)

        for (_, doc) in docs {
            let files = emitServerFiles(document: doc, testsMocks: options.testsMocks)

            for (relativePath, fileContent) in files {
                let fileUrl = srcDir.appendingPathComponent(relativePath)
                let parentDir = fileUrl.deletingLastPathComponent().path
                try createDirRecursive(parentDir)
                try WASIFileHelpers.writeString(fileContent, to: fileUrl.path)
            }

            if let schemas = doc.components?.schemas ?? doc.definitions {
                let modelsDir = srcDir.appendingPathComponent("Models").path
                try createDirRecursive(modelsDir)
                for (schemaName, schema) in schemas.sorted(by: { $0.key < $1.key }) {
                    var modelCode = "import Foundation\n\n"
                    modelCode += emitModel(name: schemaName, schema: schema)
                    modelCode += "\n"
                    let modelUrl = srcDir.appendingPathComponent("Models").appendingPathComponent("\(schemaName).swift")
                    try WASIFileHelpers.writeString(modelCode, to: modelUrl.path)
                }
            }
        }
    }
}
