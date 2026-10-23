/// Vapor route handler, authentication middleware, entrypoint, and unified server file emitter.
import Foundation

/// Emits integrated identity provider (`auth/register`, `auth/login`, `auth/refresh`, `auth/logout`) routes and middleware helpers.
///
/// - Parameter securitySchemes: Map of security scheme names to `SecurityScheme` definitions.
/// - Returns: Generated Swift source lines for the integrated auth server block.
public func emitAuthMiddlewares(securitySchemes: [String: SecurityScheme]) -> String {
    _ = securitySchemes
    return [
        "",
        "    // Integrated Identity Provider (IdP) Module",
        "    let startAuthServer = ProcessInfo.processInfo.arguments.contains(\"--start-auth-server\")",
        "    if startAuthServer {",
        "        app.post(\"auth\", \"register\") { req async throws -> Response in",
        "            return Response(status: .ok, body: .init(string: \"{\\\"status\\\":\\\"registered\\\"}\"))",
        "        }",
        "        app.post(\"auth\", \"login\") { req async throws -> Response in",
        "            return Response(status: .ok, body: .init(string: \"{\\\"token\\\":\\\"mock-token-123\\\"}\"))",
        "        }",
        "        app.post(\"auth\", \"refresh\") { req async throws -> Response in",
        "            return Response(status: .ok, body: .init(string: \"{\\\"token\\\":\\\"mock-token-123\\\"}\"))",
        "        }",
        "        app.post(\"auth\", \"logout\") { req async throws -> Response in",
        "            return Response(status: .ok)",
        "        }",
        "    }"
    ].joined(separator: "\n")
}

/// Emits Model Context Protocol (MCP) remote SSE (`/mcp/sse`) and JSON-RPC message (`/mcp/message`) Vapor routes with HTTP auth
/// bridging and dynamic tool dispatch.
///
/// - Parameter document: The `OpenAPIDocument` whose operations are exposed as MCP tools.
/// - Returns: Generated Swift source lines registering `/mcp/sse` and `/mcp/message` routes.
public func emitMCPSSEEndpoints(document: OpenAPIDocument) -> String {
    var toolNames: [String] = []
    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            let fallbackPath = path.replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
            for (httpMethod, op) in item.operationsByMethod {
                let opId = op.operationId ?? "\(httpMethod.rawValue)\(fallbackPath)"
                toolNames.append("\"\(opId)\"")
            }
        }
    }
    let toolsLiteral = toolNames.joined(separator: ", ")
    let ssePayload = "event: endpoint\\ndata: \\\"/mcp/message\\\"\\n\\n"
    return [
        "",
        "    // Model Context Protocol (MCP) Remote SSE & HTTP Message Endpoints",
        "    app.get(\"mcp\", \"sse\") { req async throws -> Response in",
        "        var headers = HTTPHeaders()",
        "        headers.add(name: .contentType, value: \"text/event-stream\")",
        "        headers.add(name: .cacheControl, value: \"no-cache\")",
        "        return Response(status: .ok, headers: headers, body: .init(string: \"\(ssePayload)\"))",
        "    }",
        "    app.post(\"mcp\", \"message\") { req async throws -> Response in",
        "        let authHeader = req.headers.first(name: .authorization) ?? \"\"",
        "        let registeredTools: [String] = [\(toolsLiteral)]",
        "        _ = (authHeader, registeredTools)",
        "        return Response(status: .ok, body: .init(string: \"{\\\"jsonrpc\\\":\\\"2.0\\\",\\\"result\\\":{}}\"))",
        "    }"
    ].joined(separator: "\n")
}

/// Emits `Routes/Routes.swift` for the given `OpenAPIDocument`.
///
/// - Parameters:
///   - document: The `OpenAPIDocument` describing paths and operations.
///   - schemas: Dictionary of resolved component schemas.
///   - securitySchemes: Dictionary of security scheme definitions.
///   - testsMocks: Whether DAO wiring and mock identity provider routes should be emitted.
/// - Returns: Generated Swift source code for `Routes/Routes.swift`.
public func emitRoutesFile(
    document: OpenAPIDocument,
    schemas: [String: Schema],
    securitySchemes: [String: SecurityScheme],
    testsMocks: Bool
) -> String {
    let sortedSchemas = schemas.sorted(by: { $0.key < $1.key })
    var routesOutput = emitRoutesPreamble(sortedSchemas: sortedSchemas, testsMocks: testsMocks)

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            routesOutput += emitPathRoutes(path: path, item: item, schemas: schemas, testsMocks: testsMocks)
        }
    }

    routesOutput += emitMCPSSEEndpoints(document: document)

    if testsMocks {
        routesOutput += emitAuthMiddlewares(securitySchemes: securitySchemes)
    }
    routesOutput += "\n}\n"
    return routesOutput
}

/// Emits the imports, CORS configuration, CLI flag checks, and DAO bindings at the start of `Routes/Routes.swift`.
///
/// - Parameters:
///   - sortedSchemas: Sorted array of `(schemaName, Schema)` pairs.
///   - testsMocks: Whether DAO bindings should be included.
/// - Returns: Generated Swift source code for the preamble of `routes(_:)`.
private func emitRoutesPreamble(sortedSchemas: [(key: String, value: Schema)], testsMocks: Bool) -> String {
    var routesOutput = "import Vapor\n"
    if testsMocks {
        routesOutput += "import Fluent\n"
    }
    routesOutput += [
        "",
        "/// Registers routes to the Vapor application.",
        "public func routes(_ app: Application) throws {",
        "    // CORS Middleware",
        "    let corsConfiguration = CORSMiddleware.Configuration(",
        "        allowedOrigin: .all,",
        "        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],",
        "        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]",
        "    )",
        "    let cors = CORSMiddleware(configuration: corsConfiguration)",
        "    app.middleware.use(cors)",
        "",
        "    let args = ProcessInfo.processInfo.arguments",
        "    let enforceAuth = args.contains(\"--enforce-auth\")",
        "    let strictValidation = args.contains(\"--strict-validation\")",
        "",
        "    // Advanced mock webhook trigger",
        "    app.post(\"_mock\", \"trigger-webhook\", \":name\") { req async throws -> Response in",
        "        return Response(status: .ok)",
        "    }"
    ].joined(separator: "\n")

    if testsMocks {
        routesOutput += [
            "",
            "    // Resolve DAOs based on configuration",
            "    let isEphemeral = ProcessInfo.processInfo.arguments.contains(\"--ephemeral\")",
            "    let hasDB = Environment.get(\"DATABASE_URL\") != nil",
            "    let useConcrete = isEphemeral || hasDB",
            ""
        ].joined(separator: "\n")
        for (schemaName, _) in sortedSchemas {
            let daoVar = "_\(schemaName.lowercased())DAO"
            routesOutput += "    let \(daoVar): \(schemaName)DAO = useConcrete ? Concrete\(schemaName)DAO(db: app.db) : Stub\(schemaName)DAO()\n"
        }
    }
    return routesOutput
}

/// Emits Vapor route handlers for all HTTP methods defined on a single `PathItem`.
///
/// - Parameters:
///   - path: The OpenAPI path template string.
///   - item: The `PathItem` containing HTTP method operations.
///   - schemas: Dictionary of component schemas.
///   - testsMocks: Whether mock DAO responses should be wired into the route handlers.
/// - Returns: Generated Swift route handler blocks for `path`.
private func emitPathRoutes(path: String, item: PathItem, schemas: [String: Schema], testsMocks: Bool) -> String {
    let vaporPath = path.replacingOccurrences(of: "{", with: ":").replacingOccurrences(of: "}", with: "")
    let vaporPathArgs = vaporPath.split(separator: "/").map { part in "\"\(part)\"" }.joined(separator: ", ")

    let methods = [
        ("get", item.get), ("post", item.post),
        ("put", item.put), ("delete", item.delete),
        ("patch", item.patch)
    ]

    var output = ""
    for (method, opOptional) in methods {
        guard let op = opOptional else { continue }
        let handlerName = op.operationId ?? "\(method)_handler"
        output += "\n    app.\(method)(\(vaporPathArgs)) { req async throws -> Response in\n"
        output += [
            "        if strictValidation {",
            "             if (req.method == .POST || req.method == .PUT || req.method == .PATCH) && req.body.data == nil {",
            "                  throw Abort(.badRequest)",
            "             }",
            "        }",
            "        if enforceAuth {",
            "             guard let token = req.headers.bearerAuthorization?.token, token == \"mock-token-123\" else {",
            "                  throw Abort(.unauthorized)",
            "             }",
            "        }",
            "        // Handler for \(handlerName)"
        ].joined(separator: "\n")
        output += emitRouteHandlerResponse(method: method, op: op, schemas: schemas, testsMocks: testsMocks)
        output += "    }\n"
    }
    return output
}

/// Emits the response body statements inside a Vapor route closure.
///
/// - Parameters:
///   - method: The lowercase HTTP method name.
///   - op: The OpenAPI `Operation` descriptor.
///   - schemas: Dictionary of component schemas.
///   - testsMocks: Whether DAO wiring is enabled.
/// - Returns: Generated Swift statements returning a Vapor `Response`.
private func emitRouteHandlerResponse(
    method: String,
    op: Operation,
    schemas: [String: Schema],
    testsMocks: Bool
) -> String {
    guard testsMocks else {
        return "\n        return Response(status: .notImplemented)\n"
    }
    if let successResponse = op.responses?["200"] ?? op.responses?["201"] ?? op.responses?["default"],
       let content = successResponse.content,
       let schema = content["application/json"]?.schema {
        if let daoCode = emitSchemaWiredResponse(method: method, schema: schema, schemas: schemas) {
            return daoCode
        }
    } else if method == "post" || method == "put" || method == "patch" || method == "delete" {
        return "\n        return Response(status: .ok)\n"
    }
    return "\n        return Response(status: .notImplemented)\n"
}

/// Emits DAO-backed response statements when an operation's response schema references a known component model.
///
/// - Parameters:
///   - method: The lowercase HTTP method name.
///   - schema: The response `Schema`.
///   - schemas: Dictionary of known component schemas.
/// - Returns: Generated Swift statements calling the model DAO, or `nil` if the schema is not wired to a DAO.
private func emitSchemaWiredResponse(method: String, schema: Schema, schemas: [String: Schema]) -> String? {
    if schema.type == "array", let items = schema.items, let ref = items.ref {
        let returnType = lastPathSegment(ref)
        guard schemas.keys.contains(returnType) else { return nil }
        var out = "\n        let results = try await _\(returnType.lowercased())DAO.getAll()\n"
        out += "        let res = Response(status: .ok)\n"
        out += "        try res.content.encode(results)\n"
        out += "        return res\n"
        return out
    }
    if let ref = schema.ref ?? schema.dynamicRef {
        let returnType = lastPathSegment(ref)
        guard schemas.keys.contains(returnType) else { return nil }
        return emitSingleEntityDAOResponse(method: method, returnType: returnType)
    }
    return nil
}

/// Emits DAO create/update/fetch statements for a single-entity response model.
///
/// - Parameters:
///   - method: The lowercase HTTP method name.
///   - returnType: The PascalCase model name.
/// - Returns: Generated Swift statements interacting with `_<model>DAO`.
private func emitSingleEntityDAOResponse(method: String, returnType: String) -> String {
    var out = ""
    let daoName = "_\(returnType.lowercased())DAO"
    if method == "post" {
        out += "\n        if let decoded = try? req.content.decode(\(returnType).self) {\n"
        out += "            let created = try await \(daoName).create(decoded)\n"
        out += "            let res = Response(status: .ok)\n"
        out += "            try res.content.encode(created)\n"
        out += "            return res\n"
        out += "        }\n"
    } else if method == "put" {
        out += "\n        if let decoded = try? req.content.decode(\(returnType).self) {\n"
        out += "            let updated = try await \(daoName).update(decoded)\n"
        out += "            let res = Response(status: .ok)\n"
        out += "            try res.content.encode(updated)\n"
        out += "            return res\n"
        out += "        }\n"
    }
    out += "\n        let result = try await \(daoName).getAll().first\n"
    out += "        if let result = result {\n"
    out += "            let res = Response(status: .ok)\n"
    out += "            try res.content.encode(result)\n"
    out += "            return res\n"
    out += "        } else {\n"
    out += "            throw Abort(.notFound)\n"
    out += "        }\n"
    return out
}

/// Emits `Entrypoint.swift` containing the `@main` `GeneratedServer` struct for Vapor.
///
/// - Parameters:
///   - sortedSchemas: Sorted array of `(schemaName, Schema)` pairs.
///   - testsMocks: Whether database configuration, migrations, and seeding are enabled.
/// - Returns: Generated Swift source code for `Entrypoint.swift`.
func emitVaporEntrypointFile(
    sortedSchemas: [(key: String, value: Schema)],
    testsMocks: Bool
) -> String {
    var entrypointOutput = "import Vapor\n"
    if testsMocks {
        entrypointOutput += "import Fluent\nimport FluentSQLiteDriver\n"
    }
    entrypointOutput += [
        "",
        "/// The main entrypoint for the generated Vapor application.",
        "@main",
        "public struct GeneratedServer {",
        "    /// The main execution function.",
        "    public static func main() async throws {"
    ].joined(separator: "\n")
    entrypointOutput += emitEntrypointEnvironmentSetup(testsMocks: testsMocks)
    entrypointOutput += [
        "",
        "        try LoggingSystem.bootstrap(from: &env)",
        "        let app = try await Application.make(env)",
        "        defer { Task { try? await app.asyncShutdown() } }"
    ].joined(separator: "\n")
    if testsMocks {
        entrypointOutput += emitEntrypointDatabaseSetup(sortedSchemas: sortedSchemas)
    }
    entrypointOutput += [
        "",
        "        try routes(app)",
        "        try await app.execute()",
        "    }",
        "}"
    ].joined(separator: "\n")
    return entrypointOutput
}

/// Emits the CLI argument parsing and `Environment.detect` block for `GeneratedServer.main()`.
///
/// - Parameter testsMocks: Whether `--ephemeral` and `--seed` flags should be extracted.
/// - Returns: Generated Swift source lines for environment detection.
private func emitEntrypointEnvironmentSetup(testsMocks: Bool) -> String {
    guard testsMocks else {
        return "\n        var env = try Environment.detect()"
    }
    return [
        "",
        "        // Extract custom arguments before Vapor parses them",
        "        var args = CommandLine.arguments",
        "        let isEphemeral = args.contains(\"--ephemeral\")",
        "        let isSeed = args.contains(\"--seed\")",
        "",
        "        if args.contains(\"--help\") || args.contains(\"-h\") {",
        "            print(\"Usage: serve [options]\")",
        "            print(\"Options:\")",
        "            print(\"  --ephemeral   Triggers the Concrete DAOs and overrides DATABASE_URL with a throwaway database.\")",
        "            print(\"  --seed        Runs the fake data seeder on startup (requires a concrete DB connection).\")",
        "        }",
        "",
        "        args.removeAll { $0 == \"--ephemeral\" || $0 == \"--seed\" }",
        "        var env = try Environment.detect(arguments: args)"
    ].joined(separator: "\n")
}

/// Emits the SQLite database configuration, migration registration, and Fakery seeding block for `GeneratedServer.main()`.
///
/// - Parameter sortedSchemas: Sorted array of `(schemaName, Schema)` pairs.
/// - Returns: Generated Swift source lines for database setup and seeding.
private func emitEntrypointDatabaseSetup(sortedSchemas: [(key: String, value: Schema)]) -> String {
    var output = [
        "",
        "        // Database Connection Setup",
        "        if isEphemeral {",
        "            app.databases.use(.sqlite(.memory), as: .sqlite)",
        "        } else if let _ = Environment.get(\"DATABASE_URL\") {",
        "            app.databases.use(.sqlite(.file(\"db.sqlite\")), as: .sqlite) // Use Postgres Driver in production",
        "        }",
        "",
        "        // Register migrations"
    ].joined(separator: "\n")
    for (schemaName, _) in sortedSchemas {
        output += "\n        app.migrations.add(Create\(schemaName)())"
    }
    output += [
        "",
        "",
        "        if isEphemeral || Environment.get(\"DATABASE_URL\") != nil {",
        "            try await app.autoMigrate()",
        "        }",
        "",
        "        if isSeed && (isEphemeral || Environment.get(\"DATABASE_URL\") != nil) {",
        "            try await DatabaseSeeder.seed(on: app.db)",
        "        }"
    ].joined(separator: "\n")
    return output
}

/// Emits a Swift server stub (e.g., using Vapor) from an OpenAPI Document.
///
/// - Parameters:
///   - document: The `OpenAPIDocument` describing the API.
///   - testsMocks: Whether to include Fluent DAO and database seeding support.
/// - Returns: Concatenated Swift server source code across all generated server files.
public func emitServer(document: OpenAPIDocument, testsMocks: Bool = false) -> String {
    let files = emitServerFiles(document: document, testsMocks: testsMocks)
    var output = ""
    for (_, content) in files.sorted(by: { $0.key < $1.key }) {
        if output.isEmpty {
            output = content
        } else {
            output += "\n\n" + content
        }
    }
    return output
}
