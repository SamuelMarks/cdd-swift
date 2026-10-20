/// OpenAPI JSON parser and SwiftSyntax AST document reconstructor.
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
                updatedItem.get = Self.withCallbacks(getOp, callbacks: ["onEvent": cb])
            }
            if let postOp = updatedItem.post, let opId = postOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.post = Self.withCallbacks(postOp, callbacks: ["onEvent": cb])
            }
            if let putOp = updatedItem.put, let opId = putOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.put = Self.withCallbacks(putOp, callbacks: ["onEvent": cb])
            }
            if let deleteOp = updatedItem.delete, let opId = deleteOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.delete = Self.withCallbacks(deleteOp, callbacks: ["onEvent": cb])
            }
            if let patchOp = updatedItem.patch, let opId = patchOp.operationId, let cb = functionVisitor.callbacks[opId] {
                updatedItem.patch = Self.withCallbacks(patchOp, callbacks: ["onEvent": cb])
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

        let testTags: [Tag]? = testVisitor.discoveredTestMethods.isEmpty
            ? nil
            : testVisitor.discoveredTestMethods.map { Tag(name: $0, description: "Discovered XCTest method") }

        return OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Parsed API", version: "1.0.0"),
            paths: finalPaths.isEmpty ? nil : finalPaths,
            webhooks: functionVisitor.webhooks.isEmpty ? nil : functionVisitor.webhooks,
            components: components,
            security: routeVisitor.globalSecurity.isEmpty ? nil : routeVisitor.globalSecurity,
            tags: testTags
        )
    }

    /// Returns a copy of `operation` with the provided `callbacks` attached.
    ///
    /// - Parameters:
    ///   - operation: The source `Operation`.
    ///   - callbacks: The callbacks dictionary to attach.
    /// - Returns: A new `Operation` containing the callbacks.
    private static func withCallbacks(_ operation: Operation, callbacks: [String: Callback]) -> Operation {
        return Operation(
            tags: operation.tags,
            summary: operation.summary,
            description: operation.description,
            externalDocs: operation.externalDocs,
            operationId: operation.operationId,
            parameters: operation.parameters,
            requestBody: operation.requestBody,
            responses: operation.responses,
            callbacks: callbacks,
            deprecated: operation.deprecated,
            security: operation.security,
            servers: operation.servers
        )
    }
}
