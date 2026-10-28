/// SwiftSyntax visitor extracting OpenAPI paths, operations, and security schemes from APIClient structs.
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

    /// Visits `class` declarations, skipping `MockAPIClient` and `XCTestCase` classes so their methods are not mistaken for API routes.
    ///
    /// - Parameter node: The `ClassDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` for mock and test classes, `.visitChildren` otherwise.
    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name == "MockAPIClient" || name.hasSuffix("Tests") {
            return .skipChildren
        }
        return .visitChildren
    }

    /// Visits `struct` declarations to inspect `APIClient` token properties and infer security schemes.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: `.visitChildren` for `APIClient`, `.skipChildren` for other structs.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard name == "APIClient" else {
            return .skipChildren
        }
        for member in node.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let ident = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let propName = ident.identifier.text
                        if propName.hasSuffix("Token") {
                            registerSecurityScheme(forPropertyName: propName)
                        }
                    }
                }
            }
        }
        return .visitChildren
    }

    /// Infers and registers a `SecurityScheme` and global `SecurityRequirement` from an `APIClient` token property name.
    ///
    /// - Parameter propName: The Swift property identifier ending with `"Token"`.
    private func registerSecurityScheme(forPropertyName propName: String) {
        let schemeKey = propName.replacingOccurrences(of: "Token", with: "")
        let capitalizedKey = String(schemeKey.prefix(1).lowercased() + schemeKey.dropFirst())
        if schemeKey.lowercased().contains("bearer") {
            securitySchemes[capitalizedKey] = SecurityScheme(type: "http", scheme: "bearer")
            globalSecurity.append([capitalizedKey: []])
        } else if schemeKey.lowercased().contains("api") || schemeKey.lowercased().contains("key") {
            securitySchemes[capitalizedKey] = SecurityScheme(type: "apiKey", name: "X-API-Key", in: "header")
            globalSecurity.append([capitalizedKey: []])
        } else {
            securitySchemes[capitalizedKey] = SecurityScheme(
                type: "oauth2",
                flows: OAuthFlows(implicit: OAuthFlow(
                    authorizationUrl: "https://example.com/oauth/authorize",
                    scopes: [:]
                ))
            )
            globalSecurity.append([capitalizedKey: []])
        }
    }

    /// Visits `func` declarations inside `APIClient` to extract OpenAPI operations, parameters, and links.
    ///
    /// - Parameter node: The `FunctionDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the operation metadata.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        var method = inferHTTPMethod(fromFunctionName: name)
        var pathName = "/" + name

        let description = parseDocstring(from: Syntax(node))
        let docMetadata = extractDocstringMetadata(from: description)
        if let overriddenRoute = docMetadata.routeOverride {
            method = overriddenRoute.method
            pathName = overriddenRoute.path
        }

        let (parameters, requestBody) = extractOperationParameters(from: node.signature.parameterClause.parameters, pathName: pathName)
        let responseContent = extractResponseContent(from: node.signature.returnClause)

        let operation = Operation(
            summary: docMetadata.cleanDescription,
            description: docMetadata.cleanDescription,
            operationId: name,
            parameters: parameters.isEmpty ? nil : parameters,
            requestBody: requestBody,
            responses: ["200": Response(description: "Success", content: responseContent, links: docMetadata.links)],
            security: nil
        )

        assignOperation(operation, method: method, toPath: pathName)
        return .skipChildren
    }

    /// Infers the lowercase HTTP method name from a Swift method identifier prefix.
    ///
    /// - Parameter name: The Swift function name.
    /// - Returns: The inferred lowercase HTTP method (`"get"`, `"post"`, `"put"`, `"delete"`, `"patch"`, or `"unknown"`).
    private func inferHTTPMethod(fromFunctionName name: String) -> String {
        let lower = name.lowercased()
        for prefix in ["get", "post", "put", "delete", "patch"] where lower.hasPrefix(prefix) {
            return prefix
        }
        return "unknown"
    }

    /// Metadata parsed from a route function docstring (`@link` and `@Route` directives).
    private struct RouteDocstringMetadata {
        /// Cleaned docstring description without `@link` or `@Route` lines.
        let cleanDescription: String?
        /// Extracted OpenAPI `Link` dictionary, if any.
        let links: [String: Link]?
        /// Optional `(method, path)` override parsed from `@Route("METHOD", "/path")`.
        let routeOverride: (method: String, path: String)?
    }

    /// Extracts `@link` definitions and `@Route("METHOD", "/path")` annotations from a function docstring.
    ///
    /// - Parameter description: Optional raw docstring text.
    /// - Returns: A `RouteDocstringMetadata` containing the cleaned description, links, and route override.
    private func extractDocstringMetadata(
        from description: String?
    ) -> RouteDocstringMetadata {
        guard let desc = description, desc.contains("@link") || desc.contains("@Route(") else {
            return RouteDocstringMetadata(cleanDescription: description, links: nil, routeOverride: nil)
        }
        let lines = desc.components(separatedBy: .newlines)
        var extractedLinks: [String: Link] = [:]
        var finalLines: [String] = []
        var routeOverride: (method: String, path: String)?
        for line in lines {
            if line.contains("@link") {
                let parts = line.components(separatedBy: "->").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    let left = parts[0].replacingOccurrences(of: "@link", with: "").trimmingCharacters(in: .whitespaces)
                    extractedLinks[left] = Link(operationId: parts[1])
                }
            } else if line.contains("@Route(") {
                let parts = line.split(whereSeparator: { $0 == "\"" })
                if parts.count >= 4 {
                    routeOverride = (method: String(parts[1]).lowercased(), path: String(parts[3]))
                }
            } else {
                finalLines.append(line)
            }
        }
        let links: [String: Link]? = extractedLinks.isEmpty ? nil : extractedLinks
        let cleanDescription = finalLines.isEmpty ? nil : finalLines.joined(separator: "\n")
        return RouteDocstringMetadata(cleanDescription: cleanDescription, links: links, routeOverride: routeOverride)
    }

    /// Extracts OpenAPI `Parameter` items and an optional `RequestBody` from a Swift function parameter list.
    ///
    /// - Parameters:
    ///   - parametersClause: The `FunctionParameterListSyntax` of the function.
    ///   - pathName: The resolved route path string used to distinguish `.path` vs `.query` parameters.
    /// - Returns: A tuple containing the extracted `Parameter` array and optional `RequestBody`.
    private func extractOperationParameters(
        from parametersClause: FunctionParameterListSyntax,
        pathName: String
    ) -> ([Parameter], RequestBody?) {
        var parameters: [Parameter] = []
        var requestBody: RequestBody?
        let typeParser = ModelVisitor(viewMode: .sourceAccurate)
        let bodyContentTypes: [String: String] = [
            "body": "application/json",
            "formData": "application/x-www-form-urlencoded",
            "multipartData": "multipart/form-data"
        ]

        for param in parametersClause {
            let pName = param.firstName.text
            let (paramSchema, isOpt) = typeParser.parseType(param.type)
            let isReq = !isOpt && param.defaultValue == nil
            if let mediaTypeKey = bodyContentTypes[pName] {
                let resolvedSchema = paramSchema.ref != nil ? paramSchema : Schema(type: "object")
                requestBody = RequestBody(
                    content: [mediaTypeKey: MediaType(schema: resolvedSchema)],
                    required: isReq
                )
            } else {
                let inLocation: ParameterLocation = pathName.contains("{\(pName)}") ? .path : .query
                parameters.append(Parameter(name: pName, in: inLocation, required: isReq ? true : nil, schema: paramSchema))
            }
        }
        return (parameters, requestBody)
    }

    /// Extracts the `200` response `MediaType` map from a Swift function's return clause.
    ///
    /// - Parameter returnClause: Optional `ReturnClauseSyntax` from the function signature.
    /// - Returns: Optional map of media type strings to `MediaType` definitions.
    private func extractResponseContent(from returnClause: ReturnClauseSyntax?) -> [String: MediaType]? {
        guard let returnClause else { return nil }
        let retText = returnClause.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard retText != "Void", retText != "()" else { return nil }
        let typeParser = ModelVisitor(viewMode: .sourceAccurate)
        let (retSchema, _) = typeParser.parseType(returnClause.type)
        return ["application/json": MediaType(schema: retSchema)]
    }

    /// Assigns an `Operation` to the given HTTP method slot on `paths[pathName]`.
    ///
    /// - Parameters:
    ///   - operation: The extracted `Operation` descriptor.
    ///   - method: The lowercase HTTP method string.
    ///   - pathName: The URL path key.
    private func assignOperation(_ operation: Operation, method: String, toPath pathName: String) {
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
    }
}
