import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    private var openapi: String = "3.2.0"
    private var info: Info
    private var paths: [String: PathItem] = [:]
    private var webhooks: [String: PathItem] = [:]
    private var schemas: [String: Schema] = [:]
    private var securitySchemes: [String: SecurityScheme] = [:]
    
    /// Initializes a builder with required API Info.
    public init(title: String, version: String) {
        self.info = Info(title: title, version: version)
    }
    
    /// Adds a path with a specific item.
    public func addPath(_ path: String, item: PathItem) -> Self {
        self.paths[path] = item
        return self
    }
    
    /// Adds a webhook definition.
    public func addWebhook(_ name: String, item: PathItem) -> Self {
        self.webhooks[name] = item
        return self
    }
    
    /// Adds a reusable schema definition.
    public func addSchema(_ name: String, schema: Schema) -> Self {
        self.schemas[name] = schema
        return self
    }

    /// Adds a security scheme definition.
    public func addSecurityScheme(_ name: String, scheme: SecurityScheme) -> Self {
        self.securitySchemes[name] = scheme
        return self
    }
    
    /// Builds the final OpenAPIDocument.
    public func build() -> OpenAPIDocument {
        let components = Components(
            schemas: self.schemas.isEmpty ? nil : self.schemas,
            securitySchemes: self.securitySchemes.isEmpty ? nil : self.securitySchemes
        )
        return OpenAPIDocument(
            openapi: self.openapi,
            info: self.info,
            paths: self.paths.isEmpty ? nil : self.paths,
            webhooks: self.webhooks.isEmpty ? nil : self.webhooks,
            components: components
        )
    }
    
    /// Serializes the document to JSON.
    public func serialize() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(build())
        return String(data: data, encoding: .utf8) ?? ""
    }
}
import Foundation

/// A utility to generate Swift code from an OpenAPI Document.
public struct OpenAPIToSwiftGenerator {
    /// Generates Swift code from the given OpenAPI document.
    /// - Parameter document: The OpenAPI document to process.
    /// - Returns: A string containing the generated Swift source code.
    public static func generate(from document: OpenAPIDocument) -> String {
        var output = "import Foundation\n\n"
        
        // Generate Models
        output += "// MARK: - Models\n\n"
        if let schemas = document.components?.schemas {
            let sortedSchemas = schemas.sorted { $0.key < $1.key }
            for (name, schema) in sortedSchemas {
                output += emitModel(name: name, schema: schema)
                output += "\n"
            }
        }
        
        // Generate API Client
        output += "// MARK: - API Client\n\n"
        output += emitDocstring("API Client for \(document.info.title) (v\(document.info.version))", indent: 0)
        output += "public struct APIClient {\n"
        output += "    public let baseURL: URL\n"
        output += "    public let session: URLSession\n"
        
        let securitySchemes = document.components?.securitySchemes ?? [:]
        var hasGlobalAuth = false
        
        if !securitySchemes.isEmpty {
            for (key, scheme) in securitySchemes {
                if let type = scheme.type {
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    output += "    public let \(propName): String?\n"
                }
            }
            output += "\n"
            var initParams = "baseURL: URL, session: URLSession = .shared"
            for (key, scheme) in securitySchemes {
                if let type = scheme.type {
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    initParams += ", \(propName): String? = nil"
                }
            }
            output += "    public init(\(initParams)) {\n"
            output += "        self.baseURL = baseURL\n"
            output += "        self.session = session\n"
            for (key, scheme) in securitySchemes {
                if let type = scheme.type {
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    output += "        self.\(propName) = \(propName)\n"
                }
            }
            output += "    }\n\n"
        } else {
            output += "\n    public init(baseURL: URL, session: URLSession = .shared) {\n"
            output += "        self.baseURL = baseURL\n"
            output += "        self.session = session\n"
            output += "    }\n\n"
        }
        
        if let paths = document.paths {
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (path, item) in sortedPaths {
                if let getOp = item.get {
                    output += emitMethod(path: path, method: "GET", operation: getOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let postOp = item.post {
                    output += emitMethod(path: path, method: "POST", operation: postOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let putOp = item.put {
                    output += emitMethod(path: path, method: "PUT", operation: putOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let deleteOp = item.delete {
                    output += emitMethod(path: path, method: "DELETE", operation: deleteOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let patchOp = item.patch {
                    output += emitMethod(path: path, method: "PATCH", operation: patchOp, documentSecurity: document.security, securitySchemes: securitySchemes)
                }
                if let additional = item.additionalOperations {
                    for (methodName, op) in additional {
                        output += emitMethod(path: path, method: methodName.uppercased(), operation: op, documentSecurity: document.security, securitySchemes: securitySchemes)
                    }
                }
            }
        }
        
        output += "}\n\n"
        
        // Generate Callbacks
        if let paths = document.paths {
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (_, item) in sortedPaths {
                let ops = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
                for op in ops {
                    if let cbs = op.callbacks, !cbs.isEmpty {
                        output += emitCallbacks(operationId: op.operationId ?? "Unknown", callbacks: cbs)
                        output += "\n"
                    }
                }
            }
        }
        
        // Generate Webhooks
        if let webhooks = document.webhooks, !webhooks.isEmpty {
            output += "// MARK: - Webhooks Protocol\n\n"
            output += emitWebhooks(webhooks: webhooks)
            output += "\n"
        }
        
        // Generate Mocks
        output += "// MARK: - Mocks\n\n"
        output += emitMockClient(paths: document.paths)
        output += "\n"
        
        // Generate Tests stub
        output += "// MARK: - Tests Stub\n\n"
        output += emitTests(paths: document.paths)
        
        return output
    }
}
import Foundation
import SwiftSyntax
import SwiftParser

/// Safely merges generated Swift code into an existing Swift file using AST.
/// Preserves whitespace and comments.
public struct SwiftCodeMerger {
    
    public static func merge(generatedCode: String, into destinationSource: String) -> String {
        let destFile = Parser.parse(source: destinationSource)
        let genFile = Parser.parse(source: generatedCode)
        
        // Extract all generated declarations (structs, enums, protocols, etc)
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
        
        let rewriter = MergerRewriter(generatedDecls: generatedDecls)
        let mergedFile = rewriter.rewrite(destFile)
        
        // Find any new declarations that were not in the destination
        var finalSource = mergedFile.description
        
        for (name, decl) in generatedDecls {
            if !rewriter.visitedDecls.contains(name) {
                if !finalSource.hasSuffix("\n") {
                    finalSource += "\n\n"
                } else if !finalSource.hasSuffix("\n\n") {
                    finalSource += "\n"
                }
                finalSource += decl.description + "\n"
            }
        }
        
        return finalSource
    }
}

class MergerRewriter: SyntaxRewriter {
    let generatedDecls: [String: DeclSyntax]
    var visitedDecls: Set<String> = []
    
    init(generatedDecls: [String: DeclSyntax]) {
        self.generatedDecls = generatedDecls
    }
    
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            // Replace the node but keep the original leading trivia (comments, whitespace)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
    
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
    
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        let name = node.name.text
        if let generated = generatedDecls[name] {
            visitedDecls.insert(name)
            var newDecl = generated
            newDecl.leadingTrivia = node.leadingTrivia
            newDecl.trailingTrivia = node.trailingTrivia
            return newDecl
        }
        return super.visit(node)
    }
}
