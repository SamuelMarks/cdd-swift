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

    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for name
        let name = node.name.text
        if name == "APIClient" {
            for member in node.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    for binding in varDecl.bindings {
                        if let ident = binding.pattern.as(IdentifierPatternSyntax.self) {
                            /// Documentation for propName
                            let propName = ident.identifier.text
                            if propName.hasSuffix("Token") {
                                /// Documentation for schemeKey
                                let schemeKey = propName.replacingOccurrences(of: "Token", with: "")
                                /// Documentation for capitalizedKey
                                /// Documentation for capitalizedKey
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

    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        /// Documentation for name
        /// Documentation for name
        let name = node.name.text

        /// Documentation for method
        var method = ""
        /// Documentation for pathName
        /// Documentation for pathName
        let pathName = "/" + name
        if name.lowercased().hasPrefix("get") { method = "get" }
        else if name.lowercased().hasPrefix("post") { method = "post" }
        else if name.lowercased().hasPrefix("put") { method = "put" }
        else if name.lowercased().hasPrefix("delete") { method = "delete" }
        else if name.lowercased().hasPrefix("patch") { method = "patch" }
        else { return .skipChildren }

        /// Documentation for operationId
        /// Documentation for operationId
        let operationId = name
        /// Documentation for description
        /// Documentation for description
        let description = parseDocstring(from: Syntax(node))

        /// Documentation for links
        var links: [String: Link]? = nil
        /// Documentation for cleanDescription
        var cleanDescription = description
        if let desc = description, desc.contains("@link") {
            /// Documentation for lines
            /// Documentation for lines
            let lines = desc.components(separatedBy: .newlines)
            /// Documentation for extractedLinks
            var extractedLinks: [String: Link] = [:]
            /// Documentation for finalLines
            var finalLines: [String] = []
            for line in lines {
                if line.contains("@link") {
                    /// Documentation for parts
                    let parts = line.components(separatedBy: "->").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        /// Documentation for left
                        let left = parts[0].replacingOccurrences(of: "@link", with: "").trimmingCharacters(in: .whitespaces)
                        /// Documentation for right
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

        /// Documentation for parameters
        var parameters: [Parameter] = []
        /// Documentation for requestBody
        /// Documentation for requestBody
        var requestBody: RequestBody? = nil

        for param in node.signature.parameterClause.parameters {
            /// Documentation for pName
            /// Documentation for pName
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

        /// Documentation for operation
        let operation = Operation(summary: cleanDescription, description: cleanDescription, operationId: operationId, parameters: parameters.isEmpty ? nil : parameters, requestBody: requestBody, responses: ["200": Response(description: "Success", links: links)], security: nil)

        /// Documentation for pathItem
        /// Documentation for pathItem
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
