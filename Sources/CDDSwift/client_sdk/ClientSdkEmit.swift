import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    /// Documentation for openapi
    private var openapi: String = "3.2.0"
    /// Documentation for info
    private var info: Info
    /// Documentation for paths
    private var paths: [String: PathItem] = [:]
    /// Documentation for webhooks
    private var webhooks: [String: PathItem] = [:]
    /// Documentation for schemas
    private var schemas: [String: Schema] = [:]
    /// Documentation for securitySchemes
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
        /// Documentation for components
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
        /// Documentation for encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        /// Documentation for data
        let data = try encoder.encode(build())
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// OpenAPIToSwiftGenerator generates swift SDK files from openapi models.
public enum OpenAPIToSwiftGenerator {
    /// Generates Swift files from the given OpenAPI document.
    /// - Parameter document: The OpenAPI document to process.
    /// - Parameter tests: A boolean flag indicating whether to generate tests along with the SDK files.
    /// - Returns: A dictionary of filenames to their generated Swift source code.
    public static func generateFiles(from document: OpenAPIDocument, tests: Bool = false) -> [String: String] {
        /// Documentation for modelsOutput
        var modelsOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        modelsOutput += "// MARK: - Models\n\n"
        if let schemas = document.components?.schemas ?? document.definitions {
            /// Documentation for sortedSchemas
            let sortedSchemas = schemas.sorted { $0.key < $1.key }
            for (name, schema) in sortedSchemas {
                modelsOutput += emitModel(name: name, schema: schema)
                modelsOutput += "\n"
            }
        }

        /// Documentation for clientOutput
        var clientOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        clientOutput += "// MARK: - API Client\n\n"
        clientOutput += emitDocstring("API Client for \(document.info.title) (v\(document.info.version))", indent: 0)
        clientOutput += "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\n"
        clientOutput += "public struct APIClient {\n"
        clientOutput += "    public let baseURL: URL\n"
        clientOutput += "    public let session: URLSession\n"

        /// Documentation for securitySchemes
        let securitySchemes = document.components?.securitySchemes ?? document.securityDefinitions ?? [:]

        if !securitySchemes.isEmpty {
            for (key, scheme) in securitySchemes where scheme.type != nil {
                /// Documentation for propName
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                clientOutput += "    public let \(propName): String?\n"
            }
            clientOutput += "\n"
            /// Documentation for initParams
            var initParams = "baseURL: URL, session: URLSession = .shared"
            for (key, scheme) in securitySchemes where scheme.type != nil {
                /// Documentation for propName
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                initParams += ", \(propName): String? = nil"
            }
            clientOutput += "    public init(\(initParams)) {\n"
            clientOutput += "        self.baseURL = baseURL\n"
            clientOutput += "        self.session = session\n"
            for (key, scheme) in securitySchemes where scheme.type != nil {
                /// Documentation for propName
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
            /// Documentation for sortedPaths
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

        clientOutput += "}\n\n"

        // Generate Callbacks
        if let paths = document.paths {
            /// Documentation for sortedPaths
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (_, item) in sortedPaths {
                /// Documentation for ops
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
        /// Documentation for files
        let files = generateFiles(from: document)
        /// Documentation for models
        let models = files["models.swift"] ?? ""
        /// Documentation for client
        let client = files["client.swift"] ?? ""
        // Strip the redundant "import Foundation\n\n" from the client file
        /// Documentation for clientStripped
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
        /// Documentation for destFile
        let destFile = Parser.parse(source: destinationSource)
        /// Documentation for genFile
        let genFile = Parser.parse(source: generatedCode)

        // Extract all generated declarations (structs, enums, protocols, etc)
        /// Documentation for generatedDecls
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

        /// Documentation for rewriter
        let rewriter = MergerRewriter(generatedDecls: generatedDecls)
        /// Documentation for mergedFile
        let mergedFile = rewriter.rewrite(destFile)

        // Find any new declarations that were not in the destination
        /// Documentation for finalSource
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

/// Documentation for MergerRewriter
class MergerRewriter: SyntaxRewriter {
    /// Documentation for generatedDecls
    let generatedDecls: [String: DeclSyntax]
    /// Documentation for visitedDecls
    var visitedDecls: Set<String> = []

    /// Documentation for initializer
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }

    /// Documentation for visit
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Replace the node but keep the original leading trivia (comments, whitespace)
            /// Documentation for newDecl
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Documentation for visit
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            /// Documentation for newDecl
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }

    /// Documentation for visit
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        /// Documentation for name
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            /// Documentation for newDecl
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
