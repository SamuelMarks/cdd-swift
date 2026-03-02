import Foundation

/// Represents a OpenAPIParser object.
public enum OpenAPIParser {
    public static func parse(json: String) throws -> OpenAPIDocument {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "OpenAPIParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        /// Documentation for decoder
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAPIDocument.self, from: data)
    }
}

import Foundation
import SwiftParser
import SwiftSyntax

/// A utility to parse Swift source code and generate OpenAPI definitions.
public class SwiftASTParser {
    /// Documentation for initializer
    public init() {}

    /// Parses a Swift source file and extracts `Codable` structs into OpenAPI `Schema` objects.
    public func parseModels(from source: String) throws -> [String: Schema] {
        /// Documentation for sourceFile
        let sourceFile = Parser.parse(source: source)
        /// Documentation for visitor
        let visitor = ModelVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.schemas
    }

    /// Parses a Swift source file and extracts everything: models, routes, tests, mocks.
    public func parseDocument(from source: String) throws -> OpenAPIDocument {
        /// Documentation for sourceFile
        let sourceFile = Parser.parse(source: source)

        // Models
        /// Documentation for modelVisitor
        let modelVisitor = ModelVisitor(viewMode: .sourceAccurate)
        modelVisitor.walk(sourceFile)

        // Routes
        /// Documentation for routeVisitor
        let routeVisitor = RouteVisitor(viewMode: .sourceAccurate)
        routeVisitor.walk(sourceFile)

        // Mocks
        /// Documentation for mockVisitor
        let mockVisitor = MockVisitor(viewMode: .sourceAccurate)
        mockVisitor.walk(sourceFile)

        // Tests
        /// Documentation for testVisitor
        let testVisitor = TestVisitor(viewMode: .sourceAccurate)
        testVisitor.walk(sourceFile)

        // Functions (webhooks/callbacks)
        /// Documentation for functionVisitor
        let functionVisitor = FunctionVisitor(viewMode: .sourceAccurate)
        functionVisitor.walk(sourceFile)

        // Combine into one document
        // Merge `mockVisitor.inferredPaths` and `routeVisitor.paths`
        /// Documentation for finalPaths
        var finalPaths = routeVisitor.paths
        for (path, mockItem) in mockVisitor.inferredPaths {
            if let existing = finalPaths[path] {
                // Merge operations
                /// Documentation for merged
                let merged = PathItem(
                    ref: existing.ref ?? mockItem.ref,
                    summary: existing.summary ?? mockItem.summary,
                    description: existing.description ?? mockItem.description,
                    get: existing.get ?? mockItem.get,
                    put: existing.put ?? mockItem.put,
                    post: existing.post ?? mockItem.post,
                    delete: existing.delete ?? mockItem.delete,
                    options: existing.options ?? mockItem.options,
                    head: existing.head ?? mockItem.head,
                    patch: existing.patch ?? mockItem.patch,
                    trace: existing.trace ?? mockItem.trace,
                    query: existing.query ?? mockItem.query,
                    additionalOperations: existing.additionalOperations ?? mockItem.additionalOperations,
                    servers: existing.servers ?? mockItem.servers,
                    parameters: existing.parameters ?? mockItem.parameters
                )
                finalPaths[path] = merged
            } else {
                finalPaths[path] = mockItem
            }
        }

        // Apply callbacks to operations if they match by operationId
        for (pathName, pathItem) in finalPaths {
            /// Documentation for updatedItem
            var updatedItem = pathItem
            if let getOp = updatedItem.get, let cb = functionVisitor.callbacks[getOp.operationId ?? ""] {
                /// Documentation for newOp
                var newOp = getOp
                newOp = Operation(tags: getOp.tags, summary: getOp.summary, description: getOp.description, externalDocs: getOp.externalDocs, operationId: getOp.operationId, parameters: getOp.parameters, requestBody: getOp.requestBody, responses: getOp.responses, callbacks: ["onEvent": cb], deprecated: getOp.deprecated, security: getOp.security, servers: getOp.servers)
                updatedItem.get = newOp
            }
            if let postOp = updatedItem.post, let cb = functionVisitor.callbacks[postOp.operationId ?? ""] {
                /// Documentation for newOp
                var newOp = postOp
                newOp = Operation(tags: postOp.tags, summary: postOp.summary, description: postOp.description, externalDocs: postOp.externalDocs, operationId: postOp.operationId, parameters: postOp.parameters, requestBody: postOp.requestBody, responses: postOp.responses, callbacks: ["onEvent": cb], deprecated: postOp.deprecated, security: postOp.security, servers: postOp.servers)
                updatedItem.post = newOp
            }
            if let putOp = updatedItem.put, let cb = functionVisitor.callbacks[putOp.operationId ?? ""] {
                /// Documentation for newOp
                var newOp = putOp
                newOp = Operation(tags: putOp.tags, summary: putOp.summary, description: putOp.description, externalDocs: putOp.externalDocs, operationId: putOp.operationId, parameters: putOp.parameters, requestBody: putOp.requestBody, responses: putOp.responses, callbacks: ["onEvent": cb], deprecated: putOp.deprecated, security: putOp.security, servers: putOp.servers)
                updatedItem.put = newOp
            }
            if let deleteOp = updatedItem.delete, let cb = functionVisitor.callbacks[deleteOp.operationId ?? ""] {
                /// Documentation for newOp
                var newOp = deleteOp
                newOp = Operation(tags: deleteOp.tags, summary: deleteOp.summary, description: deleteOp.description, externalDocs: deleteOp.externalDocs, operationId: deleteOp.operationId, parameters: deleteOp.parameters, requestBody: deleteOp.requestBody, responses: deleteOp.responses, callbacks: ["onEvent": cb], deprecated: deleteOp.deprecated, security: deleteOp.security, servers: deleteOp.servers)
                updatedItem.delete = newOp
            }
            if let patchOp = updatedItem.patch, let cb = functionVisitor.callbacks[patchOp.operationId ?? ""] {
                /// Documentation for newOp
                var newOp = patchOp
                newOp = Operation(tags: patchOp.tags, summary: patchOp.summary, description: patchOp.description, externalDocs: patchOp.externalDocs, operationId: patchOp.operationId, parameters: patchOp.parameters, requestBody: patchOp.requestBody, responses: patchOp.responses, callbacks: ["onEvent": cb], deprecated: patchOp.deprecated, security: patchOp.security, servers: patchOp.servers)
                updatedItem.patch = newOp
            }
            finalPaths[pathName] = updatedItem
        }

        /// Documentation for components
        /// Documentation for components
        let components = Components(
            schemas: modelVisitor.schemas.isEmpty ? nil : modelVisitor.schemas,
            securitySchemes: routeVisitor.securitySchemes.isEmpty ? nil : routeVisitor.securitySchemes,
            callbacks: functionVisitor.callbacks.isEmpty ? nil : functionVisitor.callbacks
        )
        return OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Parsed API", version: "1.0.0"),
            paths: finalPaths.isEmpty ? nil : finalPaths,
            webhooks: functionVisitor.webhooks.isEmpty ? nil : functionVisitor.webhooks,
            components: components,
            security: routeVisitor.globalSecurity.isEmpty ? nil : routeVisitor.globalSecurity
        )
    }
}
