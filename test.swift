import SwiftParser
import SwiftSyntax

let source = """
public protocol WebhooksDelegate {
    func onOrderPlaced(payload: AnyCodable)
}
"""
let sourceFile = Parser.parse(source: source)
for stmt in sourceFile.statements {
    if let proto = stmt.item.as(ProtocolDeclSyntax.self) {
        for member in proto.memberBlock.members {
            print(type(of: member.decl))
        }
    }
}
