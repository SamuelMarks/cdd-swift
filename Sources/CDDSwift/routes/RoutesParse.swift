/// SwiftSyntax visitor extracting OpenAPI paths, operations, and security schemes from APIClient structs.
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

    /// Initializes the `RouteVisitor` with a syntax tree traversal mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when walking syntax nodes.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits `struct` declarations to inspect `APIClient` token properties and infer security schemes.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: `.visitChildren` to continue visiting member functions.
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

    /// Visits `func` declarations inside `APIClient` to extract OpenAPI operations, parameters, and links.
    ///
    /// - Parameter node: The `FunctionDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the operation metadata.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text

        // Determine the HTTP method from the function name prefix.
        var method = ""
        var pathName = "/" + name
        if name.lowercased().hasPrefix("get") {
            method = "get"
        } else if name.lowercased().hasPrefix("post") {
            method = "post"
        } else if name.lowercased().hasPrefix("put") {
            method = "put"
        } else if name.lowercased().hasPrefix("delete") {
            method = "delete"
        } else if name.lowercased().hasPrefix("patch") {
            method = "patch"
        } else {
            method = "unknown"
        }

        let operationId = name
        let description = parseDocstring(from: Syntax(node))

        // Look for defined links
        var links: [String: Link]?
        var cleanDescription = description
        if let desc = description, desc.contains("@link") || desc.contains("@Route(") {
            let lines = desc.components(separatedBy: .newlines)
            var extractedLinks: [String: Link] = [:]
            var finalLines: [String] = []
            for line in lines {
                if line.contains("@link") {
                    let parts = line.components(separatedBy: "->").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        let left = parts[0].replacingOccurrences(of: "@link", with: "").trimmingCharacters(in: .whitespaces)
                        let right = parts[1]
                        extractedLinks[left] = Link(operationId: right)
                    }
                } else if line.contains("@Route(") {
                    let parts = line.split(whereSeparator: { $0 == "\"" })
                    if parts.count >= 4 {
                        method = String(parts[1]).lowercased()
                        pathName = String(parts[3])
                    }
                } else {
                    finalLines.append(line)
                }
            }
            if !extractedLinks.isEmpty || desc.contains("@Route(") {
                if !extractedLinks.isEmpty {
                    links = extractedLinks
                }
                cleanDescription = finalLines.isEmpty ? nil : finalLines.joined(separator: "\n")
            }
        }

        // Look for parameters and request body
        var parameters: [Parameter] = []
        var requestBody: RequestBody?
        let typeParser = ModelVisitor(viewMode: .sourceAccurate)

        for param in node.signature.parameterClause.parameters {
            let pName = param.firstName.text
            let (paramSchema, isOpt) = typeParser.parseType(param.type)
            let isReq = !isOpt && param.defaultValue == nil
            if pName == "body" {
                requestBody = RequestBody(content: ["application/json": MediaType(schema: paramSchema.ref != nil ? paramSchema : Schema(type: "object"))], required: isReq)
            } else if pName == "formData" {
                requestBody = RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: paramSchema.ref != nil ? paramSchema : Schema(type: "object"))], required: isReq)
            } else if pName == "multipartData" {
                requestBody = RequestBody(content: ["multipart/form-data": MediaType(schema: paramSchema.ref != nil ? paramSchema : Schema(type: "object"))], required: isReq)
            } else {
                let inLocation = pathName.contains("{\(pName)}") ? "path" : "query"
                let effectiveSchema = paramSchema.ref != nil ? Schema(type: "string") : paramSchema
                parameters.append(Parameter(name: pName, in: inLocation, required: isReq ? true : nil, schema: effectiveSchema))
            }
        }

        var responseContent: [String: MediaType]?
        if let returnClause = node.signature.returnClause {
            let retText = returnClause.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if retText != "Void" && retText != "()" {
                let (retSchema, _) = typeParser.parseType(returnClause.type)
                responseContent = ["application/json": MediaType(schema: retSchema)]
            }
        }

        let operation = Operation(summary: cleanDescription, description: cleanDescription, operationId: operationId, parameters: parameters.isEmpty ? nil : parameters, requestBody: requestBody, responses: ["200": Response(description: "Success", content: responseContent, links: links)], security: nil)

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
