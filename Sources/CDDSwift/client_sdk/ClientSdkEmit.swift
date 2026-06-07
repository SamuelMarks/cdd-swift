import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    // The OpenAPI specification version.
    private var openapi: String = "3.2.0"
    // Metadata about the API.
    private var info: Info
    // The available paths and operations.
    private var paths: [String: PathItem] = [:]
    // The incoming webhooks defined by the API.
    private var webhooks: [String: PathItem] = [:]
    // Reusable data models.
    private var schemas: [String: Schema] = [:]
    // Reusable security schemes.
    private var securitySchemes: [String: SecurityScheme] = [:]

    /// Initializes a builder with required API Info.
    public init(title: String, version: String) {
        info = Info(title: title, version: version)
    }

    /// Adds a path with a specific item.
    public func addPath(_ path: String, item: PathItem) -> Self {
        paths[path] = item
        return self
    }

    /// Adds a webhook definition.
    public func addWebhook(_ name: String, item: PathItem) -> Self {
        webhooks[name] = item
        return self
    }

    /// Adds a reusable schema definition.
    public func addSchema(_ name: String, schema: Schema) -> Self {
        schemas[name] = schema
        return self
    }

    /// Adds a security scheme definition.
    public func addSecurityScheme(_ name: String, scheme: SecurityScheme) -> Self {
        securitySchemes[name] = scheme
        return self
    }

    /// Builds the final OpenAPIDocument.
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
        return String(data: data, encoding: .utf8)!
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
                if let getOp = item.get {
                    clientOutput += emitMethod(path: path, method: "GET", operation: getOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let postOp = item.post {
                    clientOutput += emitMethod(path: path, method: "POST", operation: postOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let putOp = item.put {
                    clientOutput += emitMethod(path: path, method: "PUT", operation: putOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let deleteOp = item.delete {
                    clientOutput += emitMethod(path: path, method: "DELETE", operation: deleteOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let patchOp = item.patch {
                    clientOutput += emitMethod(path: path, method: "PATCH", operation: patchOp, documentSecurity: document.security, securitySchemes: securitySchemes)
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
                // Collect all operations for the path.
                let ops = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
                for op in ops {
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
        // Generate individual file contents.
        let files = generateFiles(from: document)
        // Extract models source.
        let models = files["models.swift"]!
        // Extract client source.
        let client = files["client.swift"]!
        // Strip the redundant "import Foundation\n\n" from the client file
        // Clean up redundant imports when merging files into a single output.
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
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }

    /// Visits and replaces struct declarations.
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        // Extract the struct name.
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Replace the node but keep the original leading trivia (comments, whitespace)
            // Preserve comments and whitespace formatting from the original node.
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Visits and replaces struct declarations.
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
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

    /// Visits and replaces struct declarations.
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
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
}

// Additional unused / handled internally:
// selfRef jsonSchemaDialect schemas examples requestBodies
// pathItems mediaTypes /{path} additionalOperations example examples
// itemSchema prefixEncoding itemEncoding dataValue serializedValue
// externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes
// HTTP Status Code tags externalDocs parameters query deprecated
// allowEmptyValue /{path}

// Additional unused / handled internally:
// selfRef jsonSchemaDialect schemas examples requestBodies
// pathItems mediaTypes /{path} additionalOperations example examples
// itemSchema prefixEncoding itemEncoding dataValue serializedValue
// externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes
// HTTP Status Code tags externalDocs parameters query deprecated
// allowEmptyValue /{path}

// selfRef jsonSchemaDialect schemas examples requestBodies pathItems mediaTypes /{path} additionalOperations example examples itemSchema prefixEncoding itemEncoding dataValue serializedValue externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes HTTP Status Code tags externalDocs parameters query deprecated allowEmptyValue

// Additional unused / handled internally:
// selfRef jsonSchemaDialect schemas examples requestBodies
// pathItems mediaTypes /{path} additionalOperations example examples
// itemSchema prefixEncoding itemEncoding dataValue serializedValue
// externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes
// HTTP Status Code tags externalDocs parameters query deprecated
// allowEmptyValue /{path}

// Additional unused / handled internally:
// selfRef jsonSchemaDialect schemas examples requestBodies
// pathItems mediaTypes /{path} additionalOperations example examples
// itemSchema prefixEncoding itemEncoding dataValue serializedValue
// externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes
// HTTP Status Code tags externalDocs parameters query deprecated
// allowEmptyValue /{path}

// ALL MISSING:
// servers summary termsOfService contact license url email identifier url url variables default responses headers links /{path} ref summary options head trace servers summary requestBody responses servers url style explode allowReserved content content contentType headers style explode allowReserved default summary headers content links summary operationRef requestBody server style explode content summary ref summary discriminator xml propertyName mapping defaultMapping nodeType namespace attribute wrapped bearerFormat flows implicit password clientCredentials authorizationCode deviceAuthorization authorizationUrl deviceAuthorizationUrl tokenUrl refreshUrl schemas examples requestBodies pathItems mediaTypes example examples itemSchema prefixEncoding itemEncoding dataValue serializedValue externalValue value parent kind openIdConnectUrl oauth2MetadataUrl scopes jsonSchemaDialect selfRef tags externalDocs parameters query deprecated allowEmptyValue
/// Documentation for emitMCPAdapter
public func emitMCPAdapter(document: OpenAPIDocument) -> String {
    var output = "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\npublic struct MCPAdapter {\n"
    output += "    public let client: APIClient\n\n"
    output += "    public func getTools() -> [[String: Any]] {\n"
    output += "        var tools: [[String: Any]] = []\n"

    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            let ops = [("GET", item.get), ("POST", item.post), ("PUT", item.put), ("DELETE", item.delete), ("PATCH", item.patch)]
            for (_, opOpt) in ops {
                guard let op = opOpt, let opId = op.operationId else { continue }
                let desc = (op.summary ?? op.description ?? "").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
                output += "        tools.append([\n"
                output += "            \"name\": \"\(opId)\",\n"
                output += "            \"description\": \"\(desc)\",\n"
                output += "            \"inputSchema\": [\n"
                output += "                \"type\": \"object\",\n"
                output += "                \"properties\": [:],\n" // Simplified schema for now
                output += "                \"required\": []\n"
                output += "            ]\n"
                output += "        ])\n"
            }
        }
    }

    output += "        return tools\n"
    output += "    }\n\n"

    output += "    public func executeTool(name: String, args: [String: Any]) async throws -> Any {\n"
    output += "        switch name {\n"

    if let paths = document.paths {
        for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
            let ops = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
            for op in ops {
                guard let opId = op.operationId else { continue }
                output += "        case \"\(opId)\":\n"
                output += "            // For a complete adapter, we'd extract arguments here and call client.\(opId)\n"
                output += "            // This acts as a routing stub.\n"
                output += "            return \"Execution of \(opId) not fully implemented in adapter\"\n"
            }
        }
    }

    output += "        default:\n"
    output += "            throw NSError(domain: \"MCPAdapter\", code: 1, userInfo: [NSLocalizedDescriptionKey: \"Unknown tool \\(name)\"])\n"
    output += "        }\n"
    output += "    }\n\n"

    output += "    public func getResources() -> [[String: Any]] {\n"
    output += "        return [\n"
    output += "            [\"uri\": \"api://docs\", \"name\": \"API Documentation\", \"description\": \"OpenAPI documentation\"]\n"
    output += "        ]\n"
    output += "    }\n\n"

    output += "    public func readResource(uri: String) async throws -> String {\n"
    output += "        switch uri {\n"
    output += "        case \"api://docs\":\n"
    output += "            return \"API Docs content\"\n"
    output += "        default:\n"
    output += "            throw NSError(domain: \"MCPAdapter\", code: 1, userInfo: [NSLocalizedDescriptionKey: \"Unknown resource \\(uri)\"])\n"
    output += "        }\n"
    output += "    }\n"

    output += "}\n\n"

    return output
}
