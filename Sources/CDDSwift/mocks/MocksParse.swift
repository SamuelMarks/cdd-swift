import Foundation
import SwiftSyntax

/// Extracts mock structures to update OpenAPI.
public class MockVisitor: SyntaxVisitor {
    /// Dictionary of OpenAPI PathItems inferred from mock functions.
    public var inferredPaths: [String: PathItem] = [:]
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits function declarations to infer mocked operations.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the function name.
        let name = node.name.text
        if name.hasPrefix("mock") {
            // Derive the API path from the mock function name.
            let pathName = "/" + name.replacingOccurrences(of: "mock", with: "").lowercased()
            // Create a stub operation for the mocked endpoint.
            let op = Operation(summary: "Mock generated operation for \(name)", operationId: name)

            // Merge the new mock operation with any existing inferred path item.
            var pathItem = inferredPaths[pathName] ?? PathItem()
            pathItem = PathItem(
                ref: pathItem.ref,
                summary: pathItem.summary,
                description: pathItem.description,
                get: pathItem.get ?? op,
                put: pathItem.put,
                post: pathItem.post,
                delete: pathItem.delete,
                options: pathItem.options,
                head: pathItem.head,
                patch: pathItem.patch,
                trace: pathItem.trace,
                query: pathItem.query,
                additionalOperations: pathItem.additionalOperations,
                servers: pathItem.servers,
                parameters: pathItem.parameters
            )
            inferredPaths[pathName] = pathItem
        }
        return .skipChildren
    }
}
