import Foundation
import SwiftSyntax

/// Extracts mock structures to update OpenAPI.
public class MockVisitor: SyntaxVisitor {
    /// Documentation for inferredPaths
    public var inferredPaths: [String: PathItem] = [:]
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for name
        let name = node.name.text
        if name.hasPrefix("mock") {
            /// Documentation for pathName
            let pathName = "/" + name.replacingOccurrences(of: "mock", with: "").lowercased()
            /// Documentation for op
            let op = Operation(summary: "Mock generated operation for \(name)", operationId: name)

            /// Documentation for pathItem
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
