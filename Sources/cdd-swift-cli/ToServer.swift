/// CLI subcommand that generates a Vapor server stub, Fluent models/DAOs, and XCTVapor test suites from an OpenAPI specification.
import ArgumentParser
import CDDSwift
import Foundation

/// CLI subcommand that generates a Vapor server stub, Fluent models/DAOs, and XCTVapor test suites from an OpenAPI specification.
struct ToServer: AsyncParsableCommand {
    /// Command configuration for `to_server`.
    static let configuration = CommandConfiguration(
        commandName: "to_server",
        abstract: "Generate a Server stub from an OpenAPI specification."
    )

    /// Shared OpenAPI generation options.
    @OptionGroup var options: BaseFromOpenAPIOptions

    /// Generates the Vapor server package, routes, models, DAOs, migrations, and test suites.
    ///
    /// - Throws: `CDDError` if reading specifications or writing generated files fails.
    mutating func run() async throws {
        let outDir = options.resolveOutputDir()
        print("✅ Generating Server into \(outDir)")
        try createDirRecursive(outDir)

        if !options.noInstallablePackage {
            try Self.writePackageSwift(outDir: outDir, testsMocks: options.testsMocks)
        }

        if !options.noGithubActions {
            try Self.writeGithubWorkflow(outDir: outDir)
        }

        let docs = try options.getDocuments()

        if !options.noInstallablePackage {
            try Self.writeServerTests(outDir: outDir, firstDoc: docs.first?.document)
        }

        try Self.writeServerSources(outDir: outDir, docs: docs, options: options)
    }
}

extension ToServer {
    /// Writes `Package.swift` for the generated Vapor server project.
    ///
    /// - Parameters:
    ///   - outDir: The root output directory path.
    ///   - testsMocks: Whether Fluent, SQLite, Fakery, and XCTVapor test targets should be included.
    /// - Throws: `CDDError` if writing `Package.swift` fails.
    private static func writePackageSwift(outDir: String, testsMocks: Bool) throws {
        let q = String(UnicodeScalar(34))
        let nl = String(UnicodeScalar(10))
        let vaporDeps = ".package(url: \(q)https://github.com/vapor/vapor.git\(q), from: \(q)4.113.2\(q))"
        let dbDeps = testsMocks
            ? "," + nl + "                    .package(url: \(q)https://github.com/vapor/fluent.git\(q), from: \(q)4.8.0\(q)),"
            + nl + "                    .package(url: \(q)https://github.com/vapor/fluent-sqlite-driver.git\(q), from: \(q)4.1.0\(q)),"
            + nl + "                    .package(url: \(q)https://github.com/vadymmarkov/Fakery.git\(q), from: \(q)5.0.0\(q))"
            : ""

        let vaporTargetDeps = ".product(name: \(q)Vapor\(q), package: \(q)vapor\(q))"
        let dbTargetDeps = testsMocks
            ? "," + nl + "                            .product(name: \(q)Fluent\(q), package: \(q)fluent\(q)),"
            + nl + "                            .product(name: \(q)FluentSQLiteDriver\(q), package: \(q)fluent-sqlite-driver\(q)),"
            + nl + "                            .product(name: \(q)Fakery\(q), package: \(q)Fakery\(q))"
            : ""

        let testsTarget = testsMocks
            ? "," + nl + "                    .testTarget("
            + nl + "                        name: \(q)GeneratedServerTests\(q),"
            + nl + "                        dependencies: ["
            + nl + "                            .target(name: \(q)GeneratedServer\(q)),"
            + nl + "                            .product(name: \(q)XCTVapor\(q), package: \(q)vapor\(q))"
            + nl + "                        ]"
            + nl + "                    )"
            : ""

        let packageSwift = """
        // swift-tools-version: 6.0
        import PackageDescription

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
        let pkgUrl = URL(fileURLWithPath: outDir).appendingPathComponent("Package.swift")
        try WASIFileHelpers.writeString(packageSwift, to: pkgUrl.path)
    }

    /// Writes the GitHub Actions workflow `.github/workflows/swift.yml` for the generated server.
    ///
    /// - Parameter outDir: The root output directory path.
    /// - Throws: `CDDError` if creating directories or writing the workflow file fails.
    private static func writeGithubWorkflow(outDir: String) throws {
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

    /// Writes XCTVapor test files (`StubModeTests`, `EphemeralModeTests`, `SeededModeTests`, `AuthMiddlewareTests`).
    ///
    /// - Parameters:
    ///   - outDir: The root output directory path.
    ///   - firstDoc: The first parsed `OpenAPIDocument`, if available.
    /// - Throws: `CDDError` if creating directories or writing test files fails.
    private static func writeServerTests(outDir: String, firstDoc: OpenAPIDocument?) throws {
        let testsDir = URL(fileURLWithPath: outDir).appendingPathComponent("Tests").appendingPathComponent("GeneratedServerTests")
        try createDirRecursive(testsDir.path)

        let sortedSchemas = ((firstDoc?.components?.schemas ?? firstDoc?.definitions)?.keys.sorted()) ?? []
        let firstSchema = sortedSchemas.first

        try WASIFileHelpers.writeString(
            buildStubModeTest(firstSchema: firstSchema),
            to: testsDir.appendingPathComponent("StubModeTests.swift").path
        )
        try WASIFileHelpers.writeString(
            buildEphemeralModeTest(sortedSchemas: sortedSchemas, firstSchema: firstSchema),
            to: testsDir.appendingPathComponent("EphemeralModeTests.swift").path
        )
        try WASIFileHelpers.writeString(
            buildSeededModeTest(sortedSchemas: sortedSchemas, firstSchema: firstSchema),
            to: testsDir.appendingPathComponent("SeededModeTests.swift").path
        )
        try WASIFileHelpers.writeString(
            buildAuthMiddlewareTest(),
            to: testsDir.appendingPathComponent("AuthMiddlewareTests.swift").path
        )
    }

    /// Builds the `StubModeTests.swift` source code.
    ///
    /// - Parameter firstSchema: The optional name of the first schema for generating a sample GET assertion.
    /// - Returns: The Swift source string for `StubModeTests.swift`.
    private static func buildStubModeTest(firstSchema: String?) -> String {
        let nl = String(UnicodeScalar(10))
        var code = """
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
        if let firstSchema = firstSchema {
            code += """

                    try await app.test(.GET, "\(firstSchema.lowercased())s") { req async in
                        XCTAssertEqual(req.status, .notImplemented)
                    }
            """
        }
        code += nl + "    }" + nl + "}"
        return code
    }

    /// Builds the `EphemeralModeTests.swift` source code.
    ///
    /// - Parameters:
    ///   - sortedSchemas: Sorted schema names for registering migrations.
    ///   - firstSchema: The optional name of the first schema for generating a sample GET assertion.
    /// - Returns: The Swift source string for `EphemeralModeTests.swift`.
    private static func buildEphemeralModeTest(sortedSchemas: [String], firstSchema: String?) -> String {
        let nl = String(UnicodeScalar(10))
        var code = """
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
            code += nl + "        app.migrations.add(Create\(schema)())"
        }
        code += nl + "        try await app.autoMigrate()" + nl + "        try routes(app)"
        if let firstSchema = firstSchema {
            code += """

                    try await app.test(.GET, "\(firstSchema.lowercased())s") { req async in
                        // Without seeder, should be empty array instead of 501
                        XCTAssertEqual(req.status, .ok)
                        let body = req.body.string
                        XCTAssertEqual(body, "[]")
                    }
            """
        }
        code += nl + "    }" + nl + "}"
        return code
    }

    /// Builds the `SeededModeTests.swift` source code.
    ///
    /// - Parameters:
    ///   - sortedSchemas: Sorted schema names for registering migrations.
    ///   - firstSchema: The optional name of the first schema for generating a sample GET assertion.
    /// - Returns: The Swift source string for `SeededModeTests.swift`.
    private static func buildSeededModeTest(sortedSchemas: [String], firstSchema: String?) -> String {
        let nl = String(UnicodeScalar(10))
        var code = """
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
            code += nl + "        app.migrations.add(Create\(schema)())"
        }
        code += nl + "        try await app.autoMigrate()"
            + nl + "        try await DatabaseSeeder.seed(on: app.db)"
            + nl + "        try routes(app)"
        if let firstSchema = firstSchema {
            code += """

                    try await app.test(.GET, "\(firstSchema.lowercased())s") { req async in
                        XCTAssertEqual(req.status, .ok)
                        let body = req.body.string
                        XCTAssertTrue(body.count > 2) // Should contain json elements
                    }
            """
        }
        code += nl + "    }" + nl + "}"
        return code
    }

    /// Builds the `AuthMiddlewareTests.swift` source code.
    ///
    /// - Returns: The Swift source string for `AuthMiddlewareTests.swift`.
    private static func buildAuthMiddlewareTest() -> String {
        return """
        import XCTVapor
        @testable import GeneratedServer

        /// Tests for the auth middleware.
        final class AuthMiddlewareTests: XCTestCase {
            /// Tests the auth middleware mock
            func testAuthMiddlewareMock() async throws {
                let app = try await Application.make(.testing)
                defer { Task { try? await app.asyncShutdown() } }

                try routes(app)

                try await app.test(.POST, "_mock/trigger-webhook/test") { req async in
                    XCTAssertEqual(req.status, .ok)
                }
            }
        }
        """
    }

    /// Writes generated server source files and model files for each OpenAPI document.
    ///
    /// - Parameters:
    ///   - outDir: The root output directory path.
    ///   - docs: The array of named `OpenAPIDocument` pairs.
    ///   - options: The CLI `BaseFromOpenAPIOptions`.
    /// - Throws: `CDDError` if creating directories or writing generated source files fails.
    private static func writeServerSources(
        outDir: String,
        docs: [(name: String, document: OpenAPIDocument)],
        options: BaseFromOpenAPIOptions
    ) throws {
        let nl = String(UnicodeScalar(10))
        let srcDir = options.noInstallablePackage ? URL(fileURLWithPath: outDir) : URL(fileURLWithPath: outDir)
            .appendingPathComponent("Sources").appendingPathComponent("GeneratedServer")
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
                    var modelCode = "import Foundation" + nl + nl
                    modelCode += emitModel(name: schemaName, schema: schema)
                    modelCode += nl
                    let modelUrl = srcDir.appendingPathComponent("Models").appendingPathComponent("\(schemaName).swift")
                    try WASIFileHelpers.writeString(modelCode, to: modelUrl.path)
                }
            }
        }
    }
}
