/// Swift protocol emitter for OpenAPI webhooks and callbacks.
import Foundation

/// Emits Webhook and Callback protocols.
///
/// - Parameter webhooks: Optional map of webhook names to OpenAPI `PathItem` definitions.
/// - Returns: Generated Swift `WebhooksDelegate` protocol source code.
public func emitWebhooks(webhooks: [String: PathItem]?) -> String {
    guard let webhooks = webhooks, !webhooks.isEmpty else { return "" }
    // Initialize the Swift protocol definition block.
    var output = "public protocol WebhooksDelegate {\n"
    for (name, item) in webhooks.sorted(by: { $0.key < $1.key }) {
        for (_, op) in item.operationsByMethod {
            let funcName = op.operationId ?? "on\(name.prefix(1).uppercased())\(name.dropFirst())"
            let payloadType: String
            if let schema = op.requestBody?.content?["application/json"]?.schema {
                payloadType = mapType(schema: schema)
            } else {
                payloadType = "AnyCodable"
            }
            output += "    func \(funcName)(payload: \(payloadType)) async throws\n"
        }
    }
    output += "}\n"
    return output
}
