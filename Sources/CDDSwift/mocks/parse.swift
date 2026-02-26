import SwiftSyntax
import Foundation

/// Extracts mock structures to update OpenAPI.
public class MockVisitor: SyntaxVisitor {
    public var inferredPaths: [String: PathItem] = [:]
    public override init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }
    
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name.hasPrefix("mock") {
            let pathName = "/" + name.replacingOccurrences(of: "mock", with: "").lowercased()
            let op = Operation(summary: "Mock generated operation for \(name)", operationId: name)
            
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
