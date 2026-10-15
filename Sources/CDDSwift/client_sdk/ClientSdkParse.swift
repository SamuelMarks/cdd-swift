import Foundation
import SwiftParser
import SwiftSyntax

/// Parses OpenAPI JSON strings into strongly-typed `OpenAPIDocument` instances.
public enum OpenAPIParser {
    /// Parses a JSON string into an `OpenAPIDocument`.
    ///
    /// - Parameter json: The raw OpenAPI or Swagger 2.0 JSON string.
    /// - Returns: The decoded `OpenAPIDocument`.
    /// - Throws: `DecodingError` if the JSON payload is invalid or does not conform to the OpenAPI schema.
    public static func parse(json: String) throws -> OpenAPIDocument {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAPIDocument.self, from: data)
    }
}

/// Parses Swift source code using `SwiftSyntax` to extract models, routes, CLI commands, server routes, mocks, and webhooks into an `OpenAPIDocument`.
public class SwiftASTParser {
    /// Initializes a `SwiftASTParser`.
    public init() {}

    /// Parses Swift source code to extract `Codable` structs and enums as OpenAPI `Schema` definitions.
    ///
    /// - Parameter source: The Swift source code string.
    /// - Returns: A dictionary mapping model names to their inferred `Schema` definitions.
    /// - Throws: `CDDError` if syntax parsing fails.
    public func parseModels(from source: String) throws -> [String: Schema] {
        let sourceFile = Parser.parse(source: source)
        let visitor = ModelVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.schemas
    }

    /// Parses Swift source code to construct a complete `OpenAPIDocument` across models, routes, server handlers, CLI commands, mocks, and webhooks.
    ///
    /// - Parameter source: The Swift source code string.
    /// - Returns: The reconstructed `OpenAPIDocument`.
    /// - Throws: `CDDError` if syntax parsing fails.
    public func parseDocument(from source: String) throws -> OpenAPIDocument {
        let sourceFile = Parser.parse(source: source)

        let modelVisitor = ModelVisitor(viewMode: .sourceAccurate)
        modelVisitor.walk(sourceFile)

        let routeVisitor = RouteVisitor(viewMode: .sourceAccurate)
        routeVisitor.walk(sourceFile)

        let mockVisitor = MockVisitor(viewMode: .sourceAccurate)
        mockVisitor.walk(sourceFile)

        let testVisitor = TestVisitor(viewMode: .sourceAccurate)
        testVisitor.walk(sourceFile)

        let functionVisitor = FunctionVisitor(viewMode: .sourceAccurate)
        functionVisitor.walk(sourceFile)

        let cliVisitor = CliVisitor(viewMode: .sourceAccurate)
        cliVisitor.walk(sourceFile)

        let serverVisitor = ServerVisitor(viewMode: .sourceAccurate)
        serverVisitor.walk(sourceFile)

        var finalPaths = routeVisitor.paths
        for (path, cliItem) in cliVisitor.paths {
            finalPaths[path] = cliItem
        }
        for (path, serverItem) in serverVisitor.paths where finalPaths[path] == nil {
            finalPaths[path] = serverItem
        }
        for (path, mockItem) in mockVisitor.inferredPaths {
            if let existing = finalPaths[path] {
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

        for (pathName, pathItem) in finalPaths {
            var updatedItem = pathItem
            if let getOp = updatedItem.get, let opId = getOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.get = Operation(tags: getOp.tags, summary: getOp.summary, description: getOp.description, externalDocs: getOp.externalDocs, operationId: getOp.operationId, parameters: getOp.parameters, requestBody: getOp.requestBody, responses: getOp.responses, callbacks: ["onEvent": cb], deprecated: getOp.deprecated, security: getOp.security, servers: getOp.servers)
            }
            if let postOp = updatedItem.post, let opId = postOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.post = Operation(tags: postOp.tags, summary: postOp.summary, description: postOp.description, externalDocs: postOp.externalDocs, operationId: postOp.operationId, parameters: postOp.parameters, requestBody: postOp.requestBody, responses: postOp.responses, callbacks: ["onEvent": cb], deprecated: postOp.deprecated, security: postOp.security, servers: postOp.servers)
            }
            if let putOp = updatedItem.put, let opId = putOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.put = Operation(tags: putOp.tags, summary: putOp.summary, description: putOp.description, externalDocs: putOp.externalDocs, operationId: putOp.operationId, parameters: putOp.parameters, requestBody: putOp.requestBody, responses: putOp.responses, callbacks: ["onEvent": cb], deprecated: putOp.deprecated, security: putOp.security, servers: putOp.servers)
            }
            if let deleteOp = updatedItem.delete, let opId = deleteOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.delete = Operation(tags: deleteOp.tags, summary: deleteOp.summary, description: deleteOp.description, externalDocs: deleteOp.externalDocs, operationId: deleteOp.operationId, parameters: deleteOp.parameters, requestBody: deleteOp.requestBody, responses: deleteOp.responses, callbacks: ["onEvent": cb], deprecated: deleteOp.deprecated, security: deleteOp.security, servers: deleteOp.servers)
            }
            if let patchOp = updatedItem.patch, let opId = patchOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.patch = Operation(tags: patchOp.tags, summary: patchOp.summary, description: patchOp.description, externalDocs: patchOp.externalDocs, operationId: patchOp.operationId, parameters: patchOp.parameters, requestBody: patchOp.requestBody, responses: patchOp.responses, callbacks: ["onEvent": cb], deprecated: patchOp.deprecated, security: patchOp.security, servers: patchOp.servers)
            }
            finalPaths[pathName] = updatedItem
        }

        let schemas = modelVisitor.schemas.isEmpty ? nil : modelVisitor.schemas
        let securitySchemes = routeVisitor.securitySchemes.isEmpty ? nil : routeVisitor.securitySchemes
        let callbacks = functionVisitor.callbacks.isEmpty ? nil : functionVisitor.callbacks

        var components: Components?
        if schemas != nil || securitySchemes != nil || callbacks != nil {
            components = Components(schemas: schemas, securitySchemes: securitySchemes, callbacks: callbacks)
        }

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
