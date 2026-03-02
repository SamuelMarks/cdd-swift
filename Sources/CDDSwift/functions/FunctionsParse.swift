import SwiftSyntax

/// Parses webhooks / callback functions to OpenAPI definitions.
public class FunctionVisitor: SyntaxVisitor {
    /// Dictionary of parsed webhooks where key is the webhook name.
    public var webhooks: [String: PathItem] = [:]

    /// Dictionary of parsed callbacks where key is the operation name.
    public var callbacks: [String: Callback] = [:]

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    override public func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for name
        let name = node.name.text

        if name == "WebhooksDelegate" {
            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    /// Documentation for funcName
                    let funcName = funcDecl.name.text
                    /// Documentation for operation
                    let operation = Operation(operationId: funcName, requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object"))]))

                    /// Documentation for pathItem
                    /// Documentation for pathItem
                    var pathItem = PathItem()
                    pathItem.post = operation

                    /// Documentation for webhookName
                    let webhookName = funcName.replacingOccurrences(of: "on", with: "").lowercased()
                    webhooks[webhookName] = pathItem
                }
            }
        } else if name.hasSuffix("Callbacks") {
            /// Documentation for operationId
            let operationId = name.replacingOccurrences(of: "Callbacks", with: "")
            /// Documentation for callbackKey
            /// Documentation for callbackKey
            let callbackKey = operationId.prefix(1).lowercased() + operationId.dropFirst()
            /// Documentation for callbackItem
            var callbackItem: [String: PathItem] = [:]

            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    /// Documentation for funcName
                    /// Documentation for funcName
                    let funcName = funcDecl.name.text
                    /// Documentation for operation
                    let operation = Operation(operationId: funcName, requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object"))]))

                    /// Documentation for pathItem
                    var pathItem = PathItem()
                    pathItem.post = operation
                    /// Documentation for urlPath
                    /// Documentation for urlPath
                    let urlPath = "{$request.query.callbackUrl}"
                    callbackItem[urlPath] = pathItem
                }
            }
            if !callbackItem.isEmpty {
                callbacks[callbackKey] = callbackItem
            }
        }

        return .skipChildren
    }
}
