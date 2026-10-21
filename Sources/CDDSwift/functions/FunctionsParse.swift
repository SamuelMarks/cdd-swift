/// SwiftSyntax visitor extracting OpenAPI webhooks and callbacks from Swift protocols.
import SwiftSyntax

/// Parses webhooks / callback functions to OpenAPI definitions.
public class FunctionVisitor: SyntaxVisitor {
    /// Dictionary of parsed webhooks where key is the webhook name.
    public var webhooks: [String: PathItem] = [:]

    /// Dictionary of parsed callbacks where key is the operation name.
    public var callbacks: [String: Callback] = [:]

    /// Initializes the `FunctionVisitor` with a syntax tree traversal mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when walking the syntax tree.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Extracts the OpenAPI `Schema` for the `payload` parameter of a protocol function declaration.
    ///
    /// - Parameter funcDecl: The `FunctionDeclSyntax` node to inspect.
    /// - Returns: The resolved `Schema` for the first parameter, or `Schema(type: "object")` if none is present.
    private static func extractPayloadSchema(from funcDecl: FunctionDeclSyntax) -> Schema {
        guard let firstParam = funcDecl.signature.parameterClause.parameters.first else {
            return Schema(type: "object")
        }
        let typeParser = ModelVisitor(viewMode: .sourceAccurate)
        let (schema, _) = typeParser.parseType(firstParam.type)
        return schema
    }

    /// Visits protocol declarations to extract `WebhooksDelegate` and `*Callbacks` definitions.
    ///
    /// - Parameter node: The `ProtocolDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting protocol member functions.
    override public func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the name of the protocol being visited.
        let name = node.name.text

        if name == "WebhooksDelegate" {
            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    // The name of the function acts as the webhook's operation ID.
                    let funcName = funcDecl.name.text
                    let payloadSchema = Self.extractPayloadSchema(from: funcDecl)
                    // Create an OpenAPI Operation representing this webhook's payload structure.
                    let operation = Operation(
                        operationId: funcName,
                        requestBody: RequestBody(content: ["application/json": MediaType(schema: payloadSchema)])
                    )

                    // Wrap the operation in a POST PathItem since webhooks are typically delivered via POST.
                    var pathItem = PathItem()
                    pathItem.post = operation

                    // Derive the webhook path/name by stripping only a leading 'on' prefix if followed by an uppercase letter.
                    let stripped: String
                    if funcName.hasPrefix("on"), funcName.count > 2 {
                        let thirdIdx = funcName.index(funcName.startIndex, offsetBy: 2)
                        if funcName[thirdIdx].isUppercase {
                            stripped = String(funcName[thirdIdx...])
                        } else {
                            stripped = funcName
                        }
                    } else {
                        stripped = funcName
                    }
                    let webhookName = stripped.lowercased()
                    webhooks[webhookName] = pathItem
                }
            }
        } else if name.hasSuffix("Callbacks") {
            // Extract the original operation ID by stripping the 'Callbacks' suffix.
            let operationId = String(name.dropLast("Callbacks".count))
            // Format the key to match the camelCase operation ID it belongs to.
            let callbackKey = operationId.prefix(1).lowercased() + operationId.dropFirst()
            // Initialize the callback mapping (Callback URLs to PathItems).
            var callbackItem: [String: PathItem] = [:]

            for member in node.memberBlock.members {
                if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                    // The name of the callback function represents the event being emitted.
                    let funcName = funcDecl.name.text
                    let payloadSchema = Self.extractPayloadSchema(from: funcDecl)
                    // Create an OpenAPI Operation representing this webhook's payload structure.
                    let operation = Operation(
                        operationId: funcName,
                        requestBody: RequestBody(content: ["application/json": MediaType(schema: payloadSchema)])
                    )

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
