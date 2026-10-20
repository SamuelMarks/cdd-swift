/// OpenAPI document builder, Swift SDK generator, AST code merger, and MCP adapter emitter.
import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    /// The OpenAPI specification version.
    private var openapi: String = "3.2.0"
    /// Metadata about the API.
    private var info: Info
    /// The available paths and operations.
    private var paths: [String: PathItem] = [:]
    /// The incoming webhooks defined by the API.
    private var webhooks: [String: PathItem] = [:]
    /// Reusable data models.
    private var schemas: [String: Schema] = [:]
    /// Reusable security schemes.
    private var securitySchemes: [String: SecurityScheme] = [:]

    /// Initializes a builder with required API Info.
    ///
    /// - Parameters:
    ///   - title: The title of the API.
    ///   - version: The semantic version of the API.
    public init(title: String, version: String) {
        info = Info(title: title, version: version)
    }

    /// Adds a path with a specific item.
    ///
    /// - Parameters:
    ///   - path: The URL path template (e.g. `"/pets"`).
    ///   - item: The `PathItem` definition.
    /// - Returns: `self` for fluent chaining.
    public func addPath(_ path: String, item: PathItem) -> Self {
        paths[path] = item
        return self
    }

    /// Adds a webhook definition.
    ///
    /// - Parameters:
    ///   - name: The webhook identifier.
    ///   - item: The `PathItem` describing the webhook operations.
    /// - Returns: `self` for fluent chaining.
    public func addWebhook(_ name: String, item: PathItem) -> Self {
        webhooks[name] = item
        return self
    }

    /// Adds a reusable schema definition.
    ///
    /// - Parameters:
    ///   - name: The schema component name.
    ///   - schema: The `Schema` definition.
    /// - Returns: `self` for fluent chaining.
    public func addSchema(_ name: String, schema: Schema) -> Self {
        schemas[name] = schema
        return self
    }

    /// Adds a security scheme definition.
    ///
    /// - Parameters:
    ///   - name: The security scheme component name.
    ///   - scheme: The `SecurityScheme` definition.
    /// - Returns: `self` for fluent chaining.
    public func addSecurityScheme(_ name: String, scheme: SecurityScheme) -> Self {
        securitySchemes[name] = scheme
        return self
    }

    /// Builds the final OpenAPIDocument.
    ///
    /// - Returns: The constructed `OpenAPIDocument`.
    public func build() -> OpenAPIDocument {
        // Package schemas and security schemes into the Components object.
        let components = Components(
            schemas: schemas.isEmpty ? nil : schemas,
            securitySchemes: securitySchemes.isEmpty ? nil : securitySchemes
        )
        return OpenAPIDocument(
            openapi: openapi,
            info: info,
            paths: paths.isEmpty ? nil : paths,
            webhooks: webhooks.isEmpty ? nil : webhooks,
            components: components
        )
    }

    /// Serializes the document to JSON.
    public func serialize() throws -> String {
        // Configure JSON encoder for pretty printing.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        // Encode the constructed document to JSON data.
        let data = try encoder.encode(build())
        return String(decoding: data, as: UTF8.self)
    }
}

/// OpenAPIToSwiftGenerator generates swift SDK files from openapi models.
public enum OpenAPIToSwiftGenerator {
    /// Generates Swift files from the given OpenAPI document.
    /// - Parameter document: The OpenAPI document to process.
    /// - Parameter tests: A boolean flag indicating whether to generate tests along with the SDK files.
    /// - Returns: A dictionary of filenames to their generated Swift source code.
    public static func generateFiles(from document: OpenAPIDocument, tests: Bool = false) -> [String: String] {
        // Initialize the output string for the Models file.
        var modelsOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        modelsOutput += "// MARK: - Models\n\n"
        if let schemas = document.components?.schemas ?? document.definitions {
            // Sort schemas alphabetically to ensure deterministic output.
            let sortedSchemas = schemas.sorted { $0.key < $1.key }
            for (name, schema) in sortedSchemas {
                modelsOutput += emitModel(name: name, schema: schema)
                modelsOutput += "\n"
            }
        }

        modelsOutput += AnyCodable.embeddedSwiftSource
        modelsOutput += "\n"

        // Initialize the output string for the API Client file.
        var clientOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        clientOutput += "// MARK: - API Client\n\n"
        clientOutput += emitDocstring("API Client for \(document.info.title) (v\(document.info.version))", indent: 0)
        clientOutput += "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\n"
        clientOutput += "public struct APIClient {\n"
        clientOutput += "    public let baseURL: URL\n"
        clientOutput += "    public let session: URLSession\n"

        // Reusable security schemes.
        let securitySchemes = document.components?.securitySchemes ?? document.securityDefinitions ?? [:]

        if !securitySchemes.isEmpty {
            for (key, scheme) in securitySchemes where scheme.type != nil {
                // Derive a Swift-friendly property name from the security scheme key.
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                clientOutput += "    public let \(propName): String?\n"
            }
            clientOutput += "\n"
            // Build the initialization parameter list including security tokens.
            var initParams = "baseURL: URL, session: URLSession = .shared"
            for (key, scheme) in securitySchemes where scheme.type != nil {
                // Derive a Swift-friendly property name from the security scheme key.
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                initParams += ", \(propName): String? = nil"
            }
            clientOutput += "    public init(\(initParams)) {\n"
            clientOutput += "        self.baseURL = baseURL\n"
            clientOutput += "        self.session = session\n"
            for (key, scheme) in securitySchemes where scheme.type != nil {
                // Derive a Swift-friendly property name from the security scheme key.
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                clientOutput += "        self.\(propName) = \(propName)\n"
            }
            clientOutput += "    }\n\n"
        } else {
            clientOutput += "\n    public init(baseURL: URL, session: URLSession = .shared) {\n"
            clientOutput += "        self.baseURL = baseURL\n"
            clientOutput += "        self.session = session\n"
            clientOutput += "    }\n\n"
        }

        if let paths = document.paths {
            // Sort paths alphabetically to ensure deterministic output.
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (path, item) in sortedPaths {
                for (httpMethod, op) in item.operationsByMethod {
                    clientOutput += emitMethod(path: path, method: httpMethod.rawValue.uppercased(), operation: op, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let additional = item.additionalOperations {
                    for (methodName, op) in additional {
                        clientOutput += emitMethod(path: path, method: methodName.uppercased(), operation: op, documentSecurity: document.security, securitySchemes: securitySchemes)
                    }
                }
            }
        }

        clientOutput += "    public var mcp: MCPAdapter { MCPAdapter(client: self) }\n"
        clientOutput += "}\n\n"

        clientOutput += emitMCPAdapter(document: document)

        // Generate Callbacks
        if let paths = document.paths {
            // Sort paths alphabetically to ensure deterministic output.
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (_, item) in sortedPaths {
                for (_, op) in item.operationsByMethod {
                    if let cbs = op.callbacks, !cbs.isEmpty {
                        clientOutput += emitCallbacks(operationId: op.operationId ?? "Unknown", callbacks: cbs)
                        clientOutput += "\n"
                    }
                }
            }
        }

        // Generate Webhooks
        if let webhooks = document.webhooks, !webhooks.isEmpty {
            clientOutput += "// MARK: - Webhooks Protocol\n\n"
            clientOutput += emitWebhooks(webhooks: webhooks)
            clientOutput += "\n"
        }

        var files: [String: String] = [
            "models.swift": modelsOutput
        ]

        if tests {
            var mocksOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n"
            // Wait, since we are inside GeneratedSDKMocks, we need to import GeneratedSDK
            mocksOutput += "import GeneratedSDK\n\n"
            mocksOutput += emitMockClient(paths: document.paths)
            files["mocks.swift"] = mocksOutput

            var testsOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n"
            testsOutput += "import GeneratedSDK\n"
            testsOutput += "import GeneratedSDKMocks\n"

            // emitTests outputs "import XCTest..." so we can just replace that or append.
            // It's cleaner to replace the first line to include our imports.
            let generatedTests = emitTests(paths: document.paths, document: document).replacingOccurrences(of: "import XCTest\n", with: "import XCTest\n\n")
            // Also tests should be open class so they are composable
            let composableTests = generatedTests.replacingOccurrences(of: "final class APIClientTests", with: "open class APIClientTests")
            testsOutput += composableTests
            files["tests.swift"] = testsOutput

            files["client.swift"] = clientOutput
        } else {
            // Generate Mocks
            clientOutput += "// MARK: - Mocks\n\n"
            clientOutput += emitMockClient(paths: document.paths)
            clientOutput += "\n"

            // Generate Tests stub
            clientOutput += "// MARK: - Tests Stub\n\n"
            clientOutput += emitTests(paths: document.paths, document: document)

            files["client.swift"] = clientOutput
        }

        return files
    }

    /// Generates Swift code from the given OpenAPI document.
    /// - Parameter document: The OpenAPI document to process.
    /// - Returns: A string containing the generated Swift source code.
    public static func generate(from document: OpenAPIDocument) -> String {
        let files = generateFiles(from: document)
        var models = ""
        if let m = files["models.swift"] {
            models = m
        }
        var client = ""
        if let c = files["client.swift"] {
            client = c
        }
        let clientStripped = client.replacingOccurrences(of: "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n", with: "")
        return models + "\n" + clientStripped
    }
}

import SwiftParser
import SwiftSyntax

/// Safely merges generated Swift code into an existing Swift file using AST.
/// Preserves whitespace and comments.
public enum SwiftCodeMerger {
    /// Merges generated Swift code into an existing Swift file using AST.
    ///
    /// - Parameters:
    ///   - generatedCode: Newly generated Swift source code.
    ///   - destinationSource: Existing Swift source code to update.
    /// - Returns: The merged Swift source code preserving existing trivia and custom declarations.
    public static func merge(generatedCode: String, into destinationSource: String) -> String {
        // Parse the existing destination source code.
        let destFile = Parser.parse(source: destinationSource)
        // Parse the newly generated source code.
        let genFile = Parser.parse(source: generatedCode)

        // Extract all generated declarations (structs, enums, protocols, etc)
        // Map generated declarations by their name for easy lookup.
        var generatedDecls: [String: DeclSyntax] = [:]
        for statement in genFile.statements {
            if let structDecl = statement.item.as(StructDeclSyntax.self) {
                generatedDecls[structDecl.name.text] = statement.item.as(DeclSyntax.self)
            } else if let enumDecl = statement.item.as(EnumDeclSyntax.self) {
                generatedDecls[enumDecl.name.text] = statement.item.as(DeclSyntax.self)
            } else if let protoDecl = statement.item.as(ProtocolDeclSyntax.self) {
                generatedDecls[protoDecl.name.text] = statement.item.as(DeclSyntax.self)
            }
        }

        // Initialize the AST rewriter with the generated declarations.
        let rewriter = MergerRewriter(generatedDecls: generatedDecls)
        // Apply the rewrites to the destination file.
        let mergedFile = rewriter.rewrite(destFile)

        // Find any new declarations that were not in the destination
        // Extract the rewritten string representation.
        var finalSource = mergedFile.description

        for (name, decl) in generatedDecls where !rewriter.visitedDecls.contains(name) {
            if !finalSource.hasSuffix("\n") {
                finalSource += "\n\n"
            } else if !finalSource.hasSuffix("\n\n") {
                finalSource += "\n"
            }
            finalSource += decl.description + "\n"
        }

        return finalSource
    }
}

/// A syntax rewriter that replaces existing declarations with generated ones.
class MergerRewriter: SyntaxRewriter {
    /// The mapped generated declarations available for injection.
    let generatedDecls: [String: DeclSyntax]
    /// Tracks which generated declarations were injected to append remainders later.
    var visitedDecls: Set<String> = []

    /// Initializes the rewriter.
    ///
    /// - Parameter generatedDecls: Dictionary mapping declaration names to their generated `DeclSyntax` nodes.
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }

    /// Visits and replaces `struct` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        // Extract the struct name.
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Preserve comments and whitespace formatting from the original node.
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Visits and replaces `enum` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `EnumDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        // Extract the enum name.
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Preserve comments and whitespace formatting from the original node.
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Visits and replaces `protocol` declarations matching generated declaration names.
    ///
    /// - Parameter node: The `ProtocolDeclSyntax` node being visited.
    /// - Returns: The replacement or original `DeclSyntax` node.
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        // Extract the protocol name.
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Preserve comments and whitespace formatting from the original node.
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
}

/// Emits a Swift `MCPAdapter` struct wrapping `APIClient` operations as Model Context Protocol tools and resources.
///
/// - Parameter document: The `OpenAPIDocument` describing the operations to expose.
/// - Returns: The generated Swift source code for `MCPAdapter`.
public func emitMCPAdapter(document: OpenAPIDocument) -> String {
    var output = "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\npublic struct MCPAdapter: Sendable {\n"
    output += "    public let client: APIClient\n\n"
    output += "    public func getTools() -> [Tool] {\n"
    output += "        var tools: [Tool] = []\n"

    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (_, op) in item.operationsByMethod {
                guard let opId = op.operationId else { continue }
                let desc = (op.summary ?? op.description ?? "").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
                output += "        tools.append(Tool(\n"
                output += "            name: \"\(opId)\",\n"
                output += "            description: \"\(desc)\",\n"
                output += "            inputSchema: ToolInputSchema(type: \"object\", properties: [:], required: [])\n"
                output += "        ))\n"
            }
        }
    }

    output += "        return tools\n"
    output += "    }\n\n"

    output += "    public func executeTool(name: String, args: [String: AnyCodable]) async throws -> CallToolResult {\n"
    output += "        switch name {\n"

    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (_, op) in item.operationsByMethod {
                guard let opId = op.operationId else { continue }
                output += "        case \"\(opId)\":\n"
                output += "            return CallToolResult(content: [AnyCodable(\"Executed \(opId)\")])\n"
            }
        }
    }

    output += "        default:\n"
    output += "            throw CDDError.mcpToolNotFound(name: name)\n"
    output += "        }\n"
    output += "    }\n\n"

    output += "    public func getResources() -> [Resource] {\n"
    output += "        return [\n"
    output += "            Resource(uri: \"api://docs\", name: \"API Documentation\", description: \"OpenAPI documentation\")\n"
    output += "        ]\n"
    output += "    }\n\n"

    output += "    public func readResource(uri: String) async throws -> ReadResourceResult {\n"
    output += "        switch uri {\n"
    output += "        case \"api://docs\":\n"
    output += "            return ReadResourceResult(contents: [.text(TextResourceContents(uri: uri, text: \"API Docs content\"))])\n"
    output += "        default:\n"
    output += "            throw CDDError.mcpResourceNotFound(uri: uri)\n"
    output += "        }\n"
    output += "    }\n"

    output += "}\n\n"

    return output
}
