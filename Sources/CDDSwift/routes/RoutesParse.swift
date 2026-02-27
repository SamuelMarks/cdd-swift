import SwiftSyntax
import SwiftParser
import Foundation

/// Route parser class to extract OpenAPI paths from an API client.
public class RouteVisitor: SyntaxVisitor {
    public var paths: [String: PathItem] = [:]
    
    public override init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }
    
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        
        // Simple heuristic: if it starts with get, post, put, delete, patch
        var method = ""
        let pathName = "/" + name
        if name.lowercased().hasPrefix("get") { method = "get" }
        else if name.lowercased().hasPrefix("post") { method = "post" }
        else if name.lowercased().hasPrefix("put") { method = "put" }
        else if name.lowercased().hasPrefix("delete") { method = "delete" }
        else if name.lowercased().hasPrefix("patch") { method = "patch" }
        else { return .skipChildren } // not an API route
        
        let operationId = name
        let description = parseDocstring(from: Syntax(node))
        
        // Infer URL parameters from arguments
        var parameters: [Parameter] = []
        for param in node.signature.parameterClause.parameters {
            let pName = param.firstName.text
            // In a full implementation, map types correctly and parse the body.
            parameters.append(Parameter(name: pName, in: "query", schema: Schema(type: "string")))
        }
        
        let operation = Operation(summary: description, description: description, operationId: operationId, parameters: parameters.isEmpty ? nil : parameters, responses: [:], security: nil)
        
        var pathItem = paths[pathName] ?? PathItem()
        switch method {
        case "get": pathItem.get = operation
        case "post": pathItem.post = operation
        case "put": pathItem.put = operation
        case "delete": pathItem.delete = operation
        case "patch": pathItem.patch = operation
        default: break
        }
        
        paths[pathName] = pathItem
        
        return .skipChildren
    }
}
