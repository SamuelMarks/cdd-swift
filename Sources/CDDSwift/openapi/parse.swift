import Foundation

/// Represents a OpenAPIParser object.
public struct OpenAPIParser {
    public static func parse(json: String) throws -> OpenAPIDocument {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "OpenAPIParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAPIDocument.self, from: data)
    }
}
import Foundation
import SwiftSyntax
import SwiftParser

/// A utility to parse Swift source code and generate OpenAPI definitions.
public class SwiftASTParser {
    
    public init() {}
    
    /// Parses a Swift source file and extracts `Codable` structs into OpenAPI `Schema` objects.
    public func parseModels(from source: String) throws -> [String: Schema] {
        let sourceFile = Parser.parse(source: source)
        let visitor = ModelVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.schemas
    }
    
    /// Parses a Swift source file and extracts everything: models, routes, tests, mocks.
    public func parseDocument(from source: String) throws -> OpenAPIDocument {
        let sourceFile = Parser.parse(source: source)
        
        // Models
        let modelVisitor = ModelVisitor(viewMode: .sourceAccurate)
        modelVisitor.walk(sourceFile)
        
        // Routes
        let routeVisitor = RouteVisitor(viewMode: .sourceAccurate)
        routeVisitor.walk(sourceFile)
        
        // Mocks
        let mockVisitor = MockVisitor(viewMode: .sourceAccurate)
        mockVisitor.walk(sourceFile)
        
        // Tests
        let testVisitor = TestVisitor(viewMode: .sourceAccurate)
        testVisitor.walk(sourceFile)
        
        // Functions (webhooks/callbacks)
        let functionVisitor = FunctionVisitor(viewMode: .sourceAccurate)
        functionVisitor.walk(sourceFile)
        
        // Combine into one document
        // Merge `mockVisitor.inferredPaths` and `routeVisitor.paths`
        var finalPaths = routeVisitor.paths
        for (path, mockItem) in mockVisitor.inferredPaths {
            if let existing = finalPaths[path] {
                // Merge operations
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

        
        let components = Components(schemas: modelVisitor.schemas.isEmpty ? nil : modelVisitor.schemas)
        return OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Parsed API", version: "1.0.0"),
            paths: finalPaths.isEmpty ? nil : finalPaths,
            webhooks: nil,
            components: components
        )
    }
}
