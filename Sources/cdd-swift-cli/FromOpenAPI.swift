/// CLI command group for generating Swift SDKs, CLI clients, and Vapor servers from OpenAPI specifications.
import ArgumentParser
import CDDSwift

/// Creates a directory and all intermediate parent directories recursively using `WASIFileHelpers`.
///
/// - Parameter path: The directory path to create.
/// - Throws: `CDDError.fileIOError` if creation fails.
func createDirRecursive(_ path: String) throws {
    try WASIFileHelpers.createDirectoryRecursive(at: path)
}

/// Resolves the target repository name from explicit CLI options or GitHub organization naming conventions.
///
/// - Parameters:
///   - repoName: Explicit `--repo-name` option value, if provided.
///   - githubOrg: Optional `--github-org` organization name.
///   - monorepo: Whether monorepo naming (`<org>-sdk`) is enabled instead of polyrepo (`<org>-sdk-swift`).
///   - defaultName: Fallback repository name when neither `repoName` nor `githubOrg` is specified.
/// - Returns: The resolved repository name string.
func resolveRepositoryName(repoName: String?, githubOrg: String?, monorepo: Bool, defaultName: String) -> String {
    if let repoName, !repoName.isEmpty {
        return repoName
    }
    if let githubOrg, !githubOrg.isEmpty {
        return monorepo ? "\(githubOrg)-sdk" : "\(githubOrg)-sdk-swift"
    }
    return defaultName
}

/// Emits a `.spi.yml` configuration file for Swift Package Index automatic DocC documentation hosting.
///
/// - Parameter documentationTargets: Array of Swift Package Manager target names to document.
/// - Returns: Formatted `.spi.yml` YAML string.
func emitSpiYml(documentationTargets: [String]) -> String {
    let targetsList = documentationTargets.joined(separator: ", ")
    return """
    version: 1
    builder:
      configs:
        - documentation_targets: [\(targetsList)]
    """
}

/// Emits a `.github/workflows/ci.yml` workflow with `swift test`, GPG `.asc` release signing, and DocC GitHub Pages deployment.
///
/// - Parameters:
///   - packageName: The primary Swift Package target name.
///   - repoName: The resolved GitHub repository name used for `--hosting-base-path`.
/// - Returns: Formatted GitHub Actions YAML workflow string.
func emitGithubActionsWorkflow(packageName: String, repoName: String) -> String {
    emitGithubActionsBuildAndReleaseJobs(repoName: repoName) + "\n\n" +
        emitGithubActionsDocsJob(packageName: packageName, repoName: repoName)
}

/// Emits the workflow header, `build` job, and `release` job for `.github/workflows/ci.yml`.
///
/// - Parameter repoName: The resolved GitHub repository name used for release archive naming.
/// - Returns: Formatted YAML string for the `build` and `release` jobs.
private func emitGithubActionsBuildAndReleaseJobs(repoName: String) -> String {
    """
    name: CI

    on:
      push:
        branches: [ main, master ]
        tags: [ 'v*' ]
      pull_request:
        branches: [ main, master ]

    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v4
        - name: Build
          run: swift build -v
        - name: Run tests
          run: swift test -v

      release:
        needs: build
        if: startsWith(github.ref, 'refs/tags/v')
        runs-on: ubuntu-latest
        permissions:
          contents: write
        steps:
        - uses: actions/checkout@v4
        - name: Package & Sign Release Artifact
          env:
            GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
            GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
          run: |
            TAG_NAME="${GITHUB_REF#refs/tags/}"
            ARCHIVE="\(repoName)-${TAG_NAME}.tar.gz"
            git archive --format=tar.gz --prefix="\(repoName)-${TAG_NAME}/" -o "${ARCHIVE}" HEAD
            sha256sum "${ARCHIVE}" > "${ARCHIVE}.sha256"
            if [ -n "${GPG_PRIVATE_KEY}" ]; then
              echo "${GPG_PRIVATE_KEY}" | gpg --batch --import
              gpg --batch --yes --pinentry-mode loopback --passphrase "${GPG_PASSPHRASE}" --armor --detach-sign "${ARCHIVE}"
            fi
        - name: Publish GitHub Release
          uses: softprops/action-gh-release@v3
          with:
            files: |
              *.tar.gz
              *.sha256
              *.asc
    """
}

/// Emits the `docs` job for `.github/workflows/ci.yml`.
///
/// - Parameters:
///   - packageName: The primary Swift Package target name.
///   - repoName: The resolved GitHub repository name used for `--hosting-base-path`.
/// - Returns: Formatted YAML string for the `docs` job.
private func emitGithubActionsDocsJob(packageName: String, repoName: String) -> String {
    """
      docs:
        needs: build
        if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master')
        runs-on: ubuntu-latest
        permissions:
          contents: write
        steps:
        - uses: actions/checkout@v4
        - name: Generate DocC Static Site
          run: |
            REPO_NAME="\(repoName)"
            swift package --allow-writing-to-directory ./docs generate-documentation --target \(
                packageName
            ) --disable-indexing --transform-for-static-hosting --hosting-base-path ${REPO_NAME} --output-path ./docs
        - name: Deploy DocC to GitHub Pages
          uses: peaceiris/actions-gh-pages@v4
          with:
            github_token: ${{ secrets.GITHUB_TOKEN }}
            publish_dir: ./docs
    """
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

    /// GitHub organization or user name used for repository and CI metadata.
    @Option(name: .customLong("github-org"), help: "GitHub organization or user name for repository and CI metadata.")
    var githubOrg: String?

    /// Explicit repository name override for CI and DocC hosting base path.
    @Option(
        name: .customLong("repo-name"),
        help: "GitHub repository name (defaults to '<github-org>-sdk-swift' or '<github-org>-sdk' in monorepo mode)."
    )
    var repoName: String?

    /// Uses monorepo naming (`<github-org>-sdk`) instead of polyrepo naming (`<github-org>-sdk-swift`).
    @Flag(
        name: .customLong("monorepo"),
        help: "Use monorepo repository naming convention ('<github-org>-sdk' instead of '<github-org>-sdk-swift')."
    )
    var monorepo: Bool = false

    /// Resolves the target repository name using `--repo-name`, `--github-org`, and `--monorepo`.
    ///
    /// - Parameter defaultName: Fallback repository name.
    /// - Returns: The resolved repository name string.
    func resolvedRepoName(defaultName: String) -> String {
        resolveRepositoryName(repoName: repoName, githubOrg: githubOrg, monorepo: monorepo, defaultName: defaultName)
    }

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
        if let inputPath {
            let url = URL(fileURLWithPath: inputPath)
            let data = try WASIFileHelpers.readFile(at: inputPath)
            let json = String(decoding: data, as: UTF8.self)
            let document = try OpenAPIParser.parse(json: json)
            let name = url.deletingPathExtension().lastPathComponent
            results.append((name, document))
        } else if let inputDir {
            let files = try WASIFileHelpers.listDirectory(at: inputDir)
            for filePath in files.filter({ $0.hasSuffix(".json") }) {
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
        outputPath ?? "."
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
            let docTargets = (testsMocks && !isExecutable) ? [packageName, "\(packageName)Mocks"] : [packageName]
            let spiUrl = URL(fileURLWithPath: outDir).appendingPathComponent(".spi.yml")
            try WASIFileHelpers.writeString(emitSpiYml(documentationTargets: docTargets), to: spiUrl.path)
        }

        if !noGithubActions {
            let workflowDir = URL(fileURLWithPath: outDir).appendingPathComponent(".github/workflows")
            try createDirRecursive(workflowDir.path)
            let workflowUrl = workflowDir.appendingPathComponent("ci.yml")
            let workflow = emitGithubActionsWorkflow(
                packageName: packageName,
                repoName: resolvedRepoName(defaultName: packageName)
            )
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
            if options.mcp {
                let mcpUrl = docDir.appendingPathComponent("MCPServer.swift")
                try WASIFileHelpers.writeString(emitMCPServerFile(document: doc, includeAdapter: false), to: mcpUrl.path)
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
            if options.mcp {
                let mcpUrl = srcDir.appendingPathComponent("\(name)_MCPServer.swift")
                try WASIFileHelpers.writeString(emitMCPServerFile(document: doc, includeAdapter: false), to: mcpUrl.path)
            }
        }
    }
}
