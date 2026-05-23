import Foundation
import SwiftParser
import SwiftSyntax

/// Route parser class to extract OpenAPI paths and security schemes from an API client.
public class RouteVisitor: SyntaxVisitor {
    /// Dictionary mapping route path to its associated PathItem details.
    public var paths: [String: PathItem] = [:]

    /// Extracted Security Schemes for the API.
    public var securitySchemes: [String: SecurityScheme] = [:]

    /// Global Security Requirements applied to the API Client.
    public var globalSecurity: [SecurityRequirement] = []

    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits and parses Struct declarations to find the APIClient.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the struct name.
        let name = node.name.text
        if name == "APIClient" {
            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    for binding in varDecl.bindings {
                        if let ident = binding.pattern.as(IdentifierPatternSyntax.self) {
                            // Identify token properties representing security schemes.
                            let propName = ident.identifier.text
                            if propName.hasSuffix("Token") {
                                // Extract the core scheme name from the property.
                                let schemeKey = propName.replacingOccurrences(of: "Token", with: "")
                                // Ensure consistent casing for the scheme key.
                                let capitalizedKey = schemeKey.prefix(1).lowercased() + schemeKey.dropFirst()
                                if schemeKey.lowercased().contains("bearer") {
                                    securitySchemes[String(capitalizedKey)] = SecurityScheme(type: "http", scheme: "bearer")
                                    globalSecurity.append([String(capitalizedKey): []])
                                } else if schemeKey.lowercased().contains("api") || schemeKey.lowercased().contains("key") {
                                    securitySchemes[String(capitalizedKey)] = SecurityScheme(type: "apiKey", name: "X-API-Key", in: "header")
                                    globalSecurity.append([String(capitalizedKey): []])
                                } else {
                                    securitySchemes[String(capitalizedKey)] = SecurityScheme(type: "oauth2", flows: OAuthFlows(implicit: OAuthFlow(authorizationUrl: "https://example.com/oauth/authorize", scopes: [:])))
                                    globalSecurity.append([String(capitalizedKey): []])
                                }
                            }
                        }
                    }
                }
            }
        }
        return .visitChildren
    }

    /// Visits and parses Struct declarations to find the APIClient.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the struct name.
        // Extract the struct name.
        let name = node.name.text

        // Determine the HTTP method from the function name prefix.
        var method = ""
        // pathName
        // pathName
        let pathName = "/" + name
        if name.lowercased().hasPrefix("get") { method = "get" } else if name.lowercased().hasPrefix("post") { method = "post" } else if name.lowercased().hasPrefix("put") { method = "put" } else if name.lowercased().hasPrefix("delete") { method = "delete" } else if name.lowercased().hasPrefix("patch") { method = "patch" } else { return .skipChildren }

        // operationId
        // operationId
        let operationId = name
        /// Description.
        /// Description.
        let description = parseDocstring(from: Syntax(node))

        // Look for defined links
        var links: [String: Link]?
        // cleanDescription
        var cleanDescription = description
        if let desc = description, desc.contains("@link") {
            // lines
            // lines
            let lines = desc.components(separatedBy: .newlines)
            // extractedLinks
            var extractedLinks: [String: Link] = [:]
            // finalLines
            var finalLines: [String] = []
            for line in lines {
                if line.contains("@link") {
                    // parts
                    let parts = line.components(separatedBy: "->").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        // left
                        let left = parts[0].replacingOccurrences(of: "@link", with: "").trimmingCharacters(in: .whitespaces)
                        // right
                        let right = parts[1]
                        extractedLinks[left] = Link(operationId: right)
                    }
                } else {
                    finalLines.append(line)
                }
            }
            if !extractedLinks.isEmpty {
                links = extractedLinks
                cleanDescription = finalLines.isEmpty ? nil : finalLines.joined(separator: "\n")
            }
        }

        // Look for parameters
        var parameters: [Parameter] = []
        // Look for request body
        // Look for request body
        var requestBody: RequestBody?

        for param in node.signature.parameterClause.parameters {
            /// Parameter name.
            /// Parameter name.
            let pName = param.firstName.text
            if pName == "body" {
                requestBody = RequestBody(content: ["application/json": MediaType(schema: Schema(type: "object"))], required: true)
            } else if pName == "formData" {
                requestBody = RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))], required: true)
            } else if pName == "multipartData" {
                requestBody = RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "object"))], required: true)
            } else {
                parameters.append(Parameter(name: pName, in: "query", schema: Schema(type: "string")))
            }
        }

        // operation
        let operation = Operation(summary: cleanDescription, description: cleanDescription, operationId: operationId, parameters: parameters.isEmpty ? nil : parameters, requestBody: requestBody, responses: ["200": Response(description: "Success", links: links)], security: nil)

        // Create or update the PathItem with the inferred operation.
        // Create or update the PathItem with the inferred operation.
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
