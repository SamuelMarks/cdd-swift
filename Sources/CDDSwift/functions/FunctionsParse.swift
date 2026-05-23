import SwiftSyntax

/// Parses webhooks / callback functions to OpenAPI definitions.
public class FunctionVisitor: SyntaxVisitor {
    /// Dictionary of parsed webhooks where key is the webhook name.
    public var webhooks: [String: PathItem] = [:]

    /// Dictionary of parsed callbacks where key is the operation name.
    public var callbacks: [String: Callback] = [:]

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    override public func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the name of the protocol being visited.
        let name = node.name.text

        if name == "WebhooksDelegate" {
            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    // The name of the function acts as the webhook's operation ID.
                    let funcName = funcDecl.name.text
                    // Create an OpenAPI Operation representing this webhook's payload structure.
                    let operation = Operation(operationId: funcName, requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object"))]))

                    // Wrap the operation in a POST PathItem since webhooks are typically delivered via POST.
                    var pathItem = PathItem()
                    pathItem.post = operation

                    // Derive the webhook path/name by stripping the 'on' prefix and lowercasing.
                    let webhookName = funcName.replacingOccurrences(of: "on", with: "").lowercased()
                    webhooks[webhookName] = pathItem
                }
            }
        } else if name.hasSuffix("Callbacks") {
            // Extract the original operation ID by stripping the 'Callbacks' suffix.
            let operationId = name.replacingOccurrences(of: "Callbacks", with: "")
            // Format the key to match the camelCase operation ID it belongs to.
            let callbackKey = operationId.prefix(1).lowercased() + operationId.dropFirst()
            // Initialize the callback mapping (Callback URLs to PathItems).
            var callbackItem: [String: PathItem] = [:]

            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    // The name of the callback function represents the event being emitted.
                    let funcName = funcDecl.name.text
                    // Create an OpenAPI Operation representing this webhook's payload structure.
                    let operation = Operation(operationId: funcName, requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object"))]))

                    // Create the PathItem representing the callback request.
                    var pathItem = PathItem()
                    pathItem.post = operation
                    // Use a standardized OpenAPI runtime expression for the callback URL.
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
