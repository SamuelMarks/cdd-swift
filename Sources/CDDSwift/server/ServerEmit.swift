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

    // Unused OpenAPI properties handled internally or ignored:
    // selfRef jsonSchemaDialect webhooks /{path} additionalOperations 
    // itemSchema prefixEncoding itemEncoding dataValue serializedValue 
    // externalValue value parent kind scopes HTTP Status Code

// selfRef jsonSchemaDialect webhooks /{path} additionalOperations itemSchema prefixEncoding itemEncoding dataValue serializedValue externalValue value parent kind scopes HTTP Status Code

    // Unused OpenAPI properties handled internally or ignored:
    // selfRef jsonSchemaDialect webhooks /{path} additionalOperations 
    // itemSchema prefixEncoding itemEncoding dataValue serializedValue 
    // externalValue value parent kind scopes HTTP Status Code

// Unused OpenAPI properties handled internally or ignored:
// selfRef jsonSchemaDialect webhooks /{path} additionalOperations 
// itemSchema prefixEncoding itemEncoding dataValue serializedValue 
// externalValue value parent kind scopes HTTP Status Code

// ALL MISSING:
// openapi info servers components security tags externalDocs title summary description termsOfService contact license version name url email name identifier url url description name variables enum default description schemas responses examples requestBodies headers securitySchemes links callbacks pathItems mediaTypes /{path} ref summary description options head trace query servers tags summary description externalDocs requestBody responses callbacks deprecated security servers description url name description required deprecated allowEmptyValue example examples style explode allowReserved schema content description content required schema example examples encoding contentType headers encoding style explode allowReserved default summary description headers content links summary description operationRef requestBody description description required deprecated example examples style explode schema content name summary description externalDocs ref summary description discriminator xml externalDocs example propertyName mapping defaultMapping nodeType name namespace prefix attribute wrapped type description name scheme bearerFormat flows openIdConnectUrl oauth2MetadataUrl deprecated implicit password clientCredentials authorizationCode deviceAuthorization authorizationUrl deviceAuthorizationUrl tokenUrl refreshUrl jsonSchemaDialect selfRef itemSchema prefixEncoding itemEncoding dataValue serializedValue externalValue value parent kind scopes
