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

/// Parses Swift source code using `SwiftSyntax` to extract models, routes, CLI commands, server routes, mocks, and webhooks into an
/// `OpenAPIDocument`.
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

    /// Parses Swift source code to construct a complete `OpenAPIDocument` across models, routes, server handlers, CLI commands, mocks, and
    /// webhooks.
    ///
    /// - Parameter source: The Swift source code string.
    /// - Returns: The reconstructed `OpenAPIDocument`.
    /// - Throws: `CDDError` if syntax parsing fails.
    public func parseDocument(from source: String) throws -> OpenAPIDocument {
        let sourceFile = Parser.parse(source: source)

        let modelVisitor = ModelVisitor(viewMode: .sourceAccurate)
        let routeVisitor = RouteVisitor(viewMode: .sourceAccurate)
        let mockVisitor = MockVisitor(viewMode: .sourceAccurate)
        let testVisitor = TestVisitor(viewMode: .sourceAccurate)
        let functionVisitor = FunctionVisitor(viewMode: .sourceAccurate)
        let cliVisitor = CliVisitor(viewMode: .sourceAccurate)
        let serverVisitor = ServerVisitor(viewMode: .sourceAccurate)

        for visitor in [
            modelVisitor, routeVisitor, mockVisitor, testVisitor,
            functionVisitor, cliVisitor, serverVisitor
        ] as [SyntaxVisitor] {
            visitor.walk(sourceFile)
        }

        var finalPaths = Self.mergeExtractedPaths(
            routePaths: routeVisitor.paths,
            cliPaths: cliVisitor.paths,
            serverPaths: serverVisitor.paths,
            mockPaths: mockVisitor.inferredPaths
        )
        finalPaths = Self.attachOperationCallbacks(to: finalPaths, callbacks: functionVisitor.callbacks)

        let components = Self.buildComponents(
            schemas: modelVisitor.schemas,
            securitySchemes: routeVisitor.securitySchemes,
            callbacks: functionVisitor.callbacks
        )
        let testTags: [Tag]? = testVisitor.discoveredTestMethods.isEmpty
            ? nil
            : testVisitor.discoveredTestMethods.map { Tag(name: $0, description: "Discovered XCTest method") }

        return OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: cliVisitor.infoTitle ?? "Parsed API", version: cliVisitor.infoVersion ?? "1.0.0"),
            paths: finalPaths.isEmpty ? nil : finalPaths,
            webhooks: functionVisitor.webhooks.isEmpty ? nil : functionVisitor.webhooks,
            components: components,
            security: routeVisitor.globalSecurity.isEmpty ? nil : routeVisitor.globalSecurity,
            tags: testTags
        )
    }

    /// Merges path items discovered from `RouteVisitor`, `CliVisitor`, `ServerVisitor`, and `MockVisitor`.
    ///
    /// - Parameters:
    ///   - routePaths: Paths extracted from `APIClient`.
    ///   - cliPaths: Paths extracted from `ArgumentParser` commands.
    ///   - serverPaths: Paths extracted from Vapor server route registrations.
    ///   - mockPaths: Fallback paths inferred from `MockAPIClient`.
    /// - Returns: The combined dictionary of `PathItem` definitions.
    private static func mergeExtractedPaths(
        routePaths: [String: PathItem],
        cliPaths: [String: PathItem],
        serverPaths: [String: PathItem],
        mockPaths: [String: PathItem]
    ) -> [String: PathItem] {
        var finalPaths = routePaths
        for (path, cliItem) in cliPaths {
            finalPaths[path] = cliItem
        }
        for (path, serverItem) in serverPaths where finalPaths[path] == nil {
            finalPaths[path] = serverItem
        }
        for (path, mockItem) in mockPaths {
            if let existing = finalPaths[path] {
                finalPaths[path] = mergePathItem(existing: existing, fallback: mockItem)
            } else {
                finalPaths[path] = mockItem
            }
        }
        return finalPaths
    }

    /// Merges two `PathItem` values, preferring non-nil properties on `existing` and falling back to `fallback`.
    ///
    /// - Parameters:
    ///   - existing: The primary `PathItem`.
    ///   - fallback: The fallback `PathItem`.
    /// - Returns: A merged `PathItem`.
    private static func mergePathItem(existing: PathItem, fallback: PathItem) -> PathItem {
        PathItem(
            ref: existing.ref ?? fallback.ref,
            summary: existing.summary ?? fallback.summary,
            description: existing.description ?? fallback.description,
            get: existing.get ?? fallback.get,
            put: existing.put ?? fallback.put,
            post: existing.post ?? fallback.post,
            delete: existing.delete ?? fallback.delete,
            options: existing.options ?? fallback.options,
            head: existing.head ?? fallback.head,
            patch: existing.patch ?? fallback.patch,
            trace: existing.trace ?? fallback.trace,
            query: existing.query ?? fallback.query,
            additionalOperations: existing.additionalOperations ?? fallback.additionalOperations,
            servers: existing.servers ?? fallback.servers,
            parameters: existing.parameters ?? fallback.parameters
        )
    }

    /// Attaches discovered callback protocols to matching operations by `operationId`.
    ///
    /// - Parameters:
    ///   - paths: Dictionary of `PathItem` definitions.
    ///   - callbacks: Map of operation IDs to `Callback` definitions.
    /// - Returns: Updated `PathItem` dictionary with callbacks attached.
    private static func attachOperationCallbacks(
        to paths: [String: PathItem],
        callbacks: [String: Callback]
    ) -> [String: PathItem] {
        var finalPaths = paths
        for (pathName, pathItem) in finalPaths {
            var updatedItem = pathItem
            if let getOp = updatedItem.get, let opId = getOp.operationId, let cb = callbacks[opId] {
                updatedItem.get = withCallbacks(getOp, callbacks: ["onEvent": cb])
            }
            if let postOp = updatedItem.post, let opId = postOp.operationId, let cb = callbacks[opId] {
                updatedItem.post = withCallbacks(postOp, callbacks: ["onEvent": cb])
            }
            if let putOp = updatedItem.put, let opId = putOp.operationId, let cb = callbacks[opId] {
                updatedItem.put = withCallbacks(putOp, callbacks: ["onEvent": cb])
            }
            if let deleteOp = updatedItem.delete, let opId = deleteOp.operationId, let cb = callbacks[opId] {
                updatedItem.delete = withCallbacks(deleteOp, callbacks: ["onEvent": cb])
            }
            if let patchOp = updatedItem.patch, let opId = patchOp.operationId, let cb = callbacks[opId] {
                updatedItem.patch = withCallbacks(patchOp, callbacks: ["onEvent": cb])
            }
            finalPaths[pathName] = updatedItem
        }
        return finalPaths
    }

    /// Builds an optional `Components` object when at least one of `schemas`, `securitySchemes`, or `callbacks` is non-empty.
    ///
    /// - Parameters:
    ///   - schemas: Extracted schema dictionary.
    ///   - securitySchemes: Extracted security schemes dictionary.
    ///   - callbacks: Extracted callbacks dictionary.
    /// - Returns: A `Components` value, or `nil` if all dictionaries are empty.
    private static func buildComponents(
        schemas: [String: Schema],
        securitySchemes: [String: SecurityScheme],
        callbacks: [String: Callback]
    ) -> Components? {
        let nonEmptySchemas = schemas.isEmpty ? nil : schemas
        let nonEmptySecurity = securitySchemes.isEmpty ? nil : securitySchemes
        let nonEmptyCallbacks = callbacks.isEmpty ? nil : callbacks
        guard nonEmptySchemas != nil || nonEmptySecurity != nil || nonEmptyCallbacks != nil else {
            return nil
        }
        return Components(schemas: nonEmptySchemas, securitySchemes: nonEmptySecurity, callbacks: nonEmptyCallbacks)
    }

    /// Returns a copy of `operation` with the provided `callbacks` attached.
    ///
    /// - Parameters:
    ///   - operation: The source `Operation`.
    ///   - callbacks: The callbacks dictionary to attach.
    /// - Returns: A new `Operation` containing the callbacks.
    private static func withCallbacks(_ operation: Operation, callbacks: [String: Callback]) -> Operation {
        Operation(
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
