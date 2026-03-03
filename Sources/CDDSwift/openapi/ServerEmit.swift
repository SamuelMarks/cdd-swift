import Foundation

/// Emits a Swift server stub (e.g., using Vapor) from an OpenAPI Document.
public func emitServer(document: OpenAPIDocument) -> String {
    var output = "import Vapor\n\n"
    output += "public func routes(_ app: Application) throws {\n"

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            // Convert OpenAPI path parameters like {id} to Vapor's :id
            let vaporPath = path.replacingOccurrences(of: "{", with: ":").replacingOccurrences(of: "}", with: "")
            let vaporPathArgs = vaporPath.split(separator: "/").map { part in "\"\\(part)\"" }.joined(separator: ", ")
            
            let methods = [
                ("get", item.get), ("post", item.post),
                ("put", item.put), ("delete", item.delete),
                ("patch", item.patch)
            ]
            
            for (method, opOptional) in methods {
                guard let op = opOptional else { continue }
                
                let handlerName = op.operationId ?? "\(method)_handler"
                
                output += "    app.\(method)(\(vaporPathArgs)) { req async throws -> Response in\n"
                output += "        // TODO: Implement \(handlerName)\n"
                output += "        return Response(status: .notImplemented)\n"
                output += "    }\n"
            }
        }
    }
    
    output += "}\n"
    return output
}
