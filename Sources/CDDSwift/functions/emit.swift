import Foundation

/// Emits Webhook and Callback protocols.
public func emitWebhooks(webhooks: [String: PathItem]?) -> String {
    guard let webhooks = webhooks, !webhooks.isEmpty else { return "" }
    var output = "public protocol WebhooksDelegate {\n"
    for (name, item) in webhooks.sorted(by: { $0.key < $1.key }) {
        if let postOp = item.post {
            let funcName = postOp.operationId ?? "on\(name.prefix(1).uppercased())\(name.dropFirst())"
            output += "    func \(funcName)(payload: AnyCodable) async throws\n"
        }
    }
    output += "}\n"
    return output
}
