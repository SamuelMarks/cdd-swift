import Foundation

/// Helper to map OpenAPI type to Vapor/Fluent field property wrapper
func mapFluentFieldType(schema: Schema) -> String {
    if let _ = schema.ref ?? schema.dynamicRef {
        // Use String instead of UUID to prevent type casting issues dynamically
        return "String"
    }
    switch schema.type {
    case "string":
        if schema.format == "date-time" { return "Date" }
        if schema.format == "uuid" { return "UUID" }
        if schema.format == "binary" { return "Data" }
        return "String"
    case "integer": return schema.format == "int64" ? "Int64" : "Int"
    case "number": return schema.format == "float" ? "Float" : "Double"
    case "boolean": return "Bool"
    case "array", "object":
        // For arrays/objects, we could use JSON properties, but simplified to AnyCodable or string mappings
        return "String"
    default:
        return "String"
    }
}

/// Helper to map Fakery initialization logic to properties
func mapFakeryInitializer(schema: Schema) -> String {
    if schema.ref != nil || schema.dynamicRef != nil {
        return "\"mock_reference_string\""
    }
    switch schema.type {
    case "string":
        if schema.format == "date-time" { return "Date()" }
        if schema.format == "uuid" { return "UUID()" }
        return "faker.name.name()"
    case "integer": return schema.format == "int64" ? "Int64(faker.number.randomInt())" : "faker.number.randomInt()"
    case "number": return schema.format == "float" ? "Float(faker.number.randomDouble())" : "faker.number.randomDouble()"
    case "boolean": return "faker.number.randomBool()"
    case "array", "object": return "\"[]\""
    default: return "\"\""
    }
}

import Foundation

/// Emits a Swift server stub (e.g., using Vapor) from an OpenAPI Document.

/// Emits Swift server stub files (e.g., using Vapor) from an OpenAPI Document.
public func emitServerFiles(document: OpenAPIDocument, testsMocks: Bool = false) -> [String: String] {
    var files: [String: String] = [:]
    let schemas = document.components?.schemas ?? document.definitions ?? [:]
    let sortedSchemas = schemas.sorted(by: { $0.key < $1.key })

    // Extensions
    var extensionsOutput = "import Vapor\n\n"
    for (schemaName, _) in sortedSchemas {
        extensionsOutput += "extension \(schemaName): Content, @unchecked Sendable {}\n"
    }
    if !schemas.isEmpty {
        files["Models/Extensions.swift"] = extensionsOutput
    }

    if testsMocks, !schemas.isEmpty {
        files["Mocks/DatabaseSeeder.swift"] = """
        import Vapor
        import Fluent
        import Fakery

        /// Seeder for the application.
        public struct DatabaseSeeder {
            /// Seeds the database with fake data.
            public static func seed(on db: Database) async throws {
                let faker = Faker()
        """
        for (schemaName, schema) in sortedSchemas {
            files["Mocks/DatabaseSeeder.swift"]! += "\n                for _ in 0..<10 {\n                    let item = Fluent\(schemaName)()\n"
            if let properties = schema.properties {
                for (propName, propSchema) in properties {
                    if propName.lowercased() == "id" { continue }
                    let initVal = mapFakeryInitializer(schema: propSchema)
                    files["Mocks/DatabaseSeeder.swift"]! += "                    item.\(propName) = \(initVal)\n"
                }
            }
            files["Mocks/DatabaseSeeder.swift"]! += "                    try await item.create(on: db)\n                }\n"
        }
        files["Mocks/DatabaseSeeder.swift"]! += "            }\n        }\n"

        for (schemaName, schema) in sortedSchemas {
            var fluentOutput = """
            import Vapor
            import Fluent

            /// Concrete Fluent Model for \(schemaName).
            public final class Fluent\(schemaName): Model, @unchecked Sendable {
                /// Table schema name.
                public static let schema = "\(schemaName.lowercased())s"
                /// Unique identifier.
                @ID(key: .id) public var id: UUID?
            """

            if let properties = schema.properties {
                for (propName, propSchema) in properties.sorted(by: { $0.key < $1.key }) {
                    if propName.lowercased() == "id" { continue }
                    let swiftType = mapFluentFieldType(schema: propSchema)
                    let isRequired = schema.required?.contains(propName) ?? false
                    if isRequired {
                        fluentOutput += "\n    @Field(key: \"\(propName)\") public var \(propName): \(swiftType)"
                    } else {
                        fluentOutput += "\n    @OptionalField(key: \"\(propName)\") public var \(propName): \(swiftType)?"
                    }
                }
            }

            fluentOutput += """

                /// Default initializer.
                public init() {}

                /// Maps Fluent model properties to Codable struct.
                public func toModel() throws -> \(schemaName) {
                    let data = "{}"
                    return try JSONDecoder().decode(\(schemaName).self, from: data.data(using: .utf8)!)
                }
            }
            """
            files["Models/Fluent\(schemaName).swift"] = fluentOutput

            var daoOutput = """
            import Vapor
            import Fluent

            /// Abstract Data Access Object for \(schemaName).
            public protocol \(schemaName)DAO {
                /// Retrieves all \(schemaName) records.
                func getAll() async throws -> [\(schemaName)]
                /// Retrieves a single \(schemaName) by ID.
                func get(id: UUID) async throws -> \(schemaName)?
                /// Creates a \(schemaName).
                func create(_ model: \(schemaName)) async throws -> \(schemaName)
                /// Updates a \(schemaName).
                func update(_ model: \(schemaName)) async throws -> \(schemaName)
                /// Deletes a \(schemaName).
                func delete(id: UUID) async throws
            }

            /// Stub Data Access Object for \(schemaName).
            public struct Stub\(schemaName)DAO: \(schemaName)DAO {
                /// Default initializer.
                public init() {}
                /// Retrieves all \(schemaName) records.
                public func getAll() async throws -> [\(schemaName)] { throw Abort(.notImplemented) }
                /// Retrieves a single \(schemaName) by ID.
                public func get(id: UUID) async throws -> \(schemaName)? { throw Abort(.notImplemented) }
                /// Creates a \(schemaName).
                public func create(_ model: \(schemaName)) async throws -> \(schemaName) { throw Abort(.notImplemented) }
                /// Updates a \(schemaName).
                public func update(_ model: \(schemaName)) async throws -> \(schemaName) { throw Abort(.notImplemented) }
                /// Deletes a \(schemaName).
                public func delete(id: UUID) async throws { throw Abort(.notImplemented) }
            }

            /// Concrete Data Access Object for \(schemaName) using Fluent.
            public struct Concrete\(schemaName)DAO: \(schemaName)DAO {
                /// The database instance.
                public let db: Database
                /// Initializes the DAO with a database instance.
                public init(db: Database) { self.db = db }
                /// Retrieves all \(schemaName) records.
                public func getAll() async throws -> [\(schemaName)] {
                    var results: [\(schemaName)] = []
                    for item in try await Fluent\(schemaName).query(on: db).all() {
                        results.append(try item.toModel())
                    }
                    return results
                }
                /// Retrieves a single \(schemaName) by ID.
                public func get(id: UUID) async throws -> \(schemaName)? { return try await Fluent\(schemaName).find(id, on: db)?.toModel() }
                /// Creates a \(schemaName).
                public func create(_ model: \(schemaName)) async throws -> \(schemaName) { throw Abort(.notImplemented) }
                /// Updates a \(schemaName).
                public func update(_ model: \(schemaName)) async throws -> \(schemaName) { throw Abort(.notImplemented) }
                /// Deletes a \(schemaName).
                public func delete(id: UUID) async throws { try await Fluent\(schemaName).find(id, on: db)?.delete(on: db) }
            }
            """

            var migrationOutput = """
            /// Database Migration for \(schemaName).
            public struct Create\(schemaName): AsyncMigration {
                /// Applies the migration.
                public func prepare(on database: Database) async throws {
                    try await database.schema("\(schemaName.lowercased())s")
                        .id()
            """

            if let properties = schema.properties {
                for (propName, propSchema) in properties.sorted(by: { $0.key < $1.key }) {
                    if propName.lowercased() == "id" { continue }
                    let swiftType = mapFluentFieldType(schema: propSchema)
                    let isRequired = schema.required?.contains(propName) ?? false
                    let fieldType: String
                    switch swiftType {
                    case "String": fieldType = ".string"
                    case "Int": fieldType = ".int"
                    case "Double": fieldType = ".double"
                    case "Bool": fieldType = ".bool"
                    case "UUID": fieldType = ".uuid"
                    case "Date": fieldType = ".datetime"
                    default: fieldType = ".string"
                    }
                    if isRequired {
                        migrationOutput += "\n                        .field(FieldKey(stringLiteral: \"\(propName)\"), \(fieldType), .required)"
                    } else {
                        migrationOutput += "\n                        .field(FieldKey(stringLiteral: \"\(propName)\"), \(fieldType))"
                    }
                }
            }

            migrationOutput += """

                        .create()
                }
                /// Reverts the migration.
                public func revert(on database: Database) async throws {
                    try await database.schema("\(schemaName.lowercased())s").delete()
                }
            }
            """
            daoOutput += "\n" + migrationOutput
            files["Mocks/\(schemaName)DAO.swift"] = daoOutput
        }
    }

    var routesOutput = "import Vapor\n"
    if testsMocks { routesOutput += "import Fluent\n" }
    routesOutput += """

    /// Registers routes to the Vapor application.
    public func routes(_ app: Application) throws {
        // CORS Middleware
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
        let cors = CORSMiddleware(configuration: corsConfiguration)
        app.middleware.use(cors)

        let args = ProcessInfo.processInfo.arguments
        let enforceAuth = args.contains("--enforce-auth")
        let strictValidation = args.contains("--strict-validation")

        // Advanced mock webhook trigger
        app.post("_mock", "trigger-webhook", ":name") { req async throws -> Response in
            return Response(status: .ok)
        }
    """

    if testsMocks {
        routesOutput += """

            // Resolve DAOs based on configuration
            let isEphemeral = ProcessInfo.processInfo.arguments.contains("--ephemeral")
            let hasDB = Environment.get("DATABASE_URL") != nil
            let useConcrete = isEphemeral || hasDB

        """
        for (schemaName, _) in sortedSchemas {
            routesOutput += "    let _\(schemaName.lowercased())DAO: \(schemaName)DAO = useConcrete ? Concrete\(schemaName)DAO(db: app.db) : Stub\(schemaName)DAO()\n"
        }
    }

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            let vaporPath = path.replacingOccurrences(of: "{", with: ":").replacingOccurrences(of: "}", with: "")
            let vaporPathArgs = vaporPath.split(separator: "/").map { part in "\"\(part)\"" }.joined(separator: ", ")

            let methods = [
                ("get", item.get), ("post", item.post),
                ("put", item.put), ("delete", item.delete),
                ("patch", item.patch)
            ]

            for (method, opOptional) in methods {
                guard let op = opOptional else { continue }
                let handlerName = op.operationId ?? "\(method)_handler"
                routesOutput += "\n    app.\(method)(\(vaporPathArgs)) { req async throws -> Response in\n"
                routesOutput += """
                        if strictValidation {
                             // TODO: Inject OpenAPI specific validations
                        }
                        if enforceAuth {
                             guard let token = req.headers.bearerAuthorization?.token, token == "mock-token-123" else {
                                  throw Abort(.unauthorized)
                             }
                        }
                        // TODO: Implement \(handlerName)
                """

                var wired = false
                if testsMocks {
                    if let successResponse = op.responses?["200"] ?? op.responses?["201"] ?? op.responses?["default"],
                       let content = successResponse.content,
                       let schema = content["application/json"]?.schema
                    {
                        if schema.type == "array", let items = schema.items, let ref = items.ref {
                            let returnType = ref.components(separatedBy: "/").last!
                            if schemas.keys.contains(returnType) {
                                routesOutput += "\n        let results = try await _\(returnType.lowercased())DAO.getAll()\n"
                                routesOutput += "        var res = Response(status: .ok)\n"
                                routesOutput += "        try res.content.encode(results)\n"
                                routesOutput += "        return res\n"
                                wired = true
                            }
                        } else if let ref = schema.ref ?? schema.dynamicRef {
                            let returnType = ref.components(separatedBy: "/").last!
                            if schemas.keys.contains(returnType) {
                                routesOutput += "\n        let result = try await _\(returnType.lowercased())DAO.getAll().first\n"
                                routesOutput += "        if let result = result {\n"
                                routesOutput += "            var res = Response(status: .ok)\n"
                                routesOutput += "            try res.content.encode(result)\n"
                                routesOutput += "            return res\n"
                                routesOutput += "        } else {\n"
                                routesOutput += "            throw Abort(.notFound)\n"
                                routesOutput += "        }\n"
                                wired = true
                            }
                        }
                    } else if method == "post" || method == "put" || method == "patch" || method == "delete" {
                        routesOutput += "\n        return Response(status: .ok)\n"
                        wired = true
                    }
                }
                if !wired {
                    routesOutput += "\n        return Response(status: .notImplemented)\n"
                }
                routesOutput += "    }\n"
            }
        }
    }

    if testsMocks {
        routesOutput += """

            // Integrated Identity Provider (IdP) Module
            let startAuthServer = ProcessInfo.processInfo.arguments.contains("--start-auth-server")
            if startAuthServer {
                app.post("auth", "register") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\\"status\\\":\\\"registered\\\"}"))
                }
                app.post("auth", "login") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\\"token\\\":\\\"mock-token-123\\\"}"))
                }
                app.post("auth", "refresh") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\\"token\\\":\\\"mock-token-123\\\"}"))
                }
                app.post("auth", "logout") { req async throws -> Response in
                    return Response(status: .ok)
                }
            }
        """
    }
    routesOutput += "}\n"
    files["Routes/Routes.swift"] = routesOutput

    var entrypointOutput = "import Vapor\n"
    if testsMocks { entrypointOutput += "import Fluent\nimport FluentSQLiteDriver\n" }
    entrypointOutput += """

    /// The main entrypoint for the generated Vapor application.
    @main
    public struct GeneratedServer {
        /// The main execution function.
        public static func main() async throws {
    """

    if testsMocks {
        entrypointOutput += """

                // Extract custom arguments before Vapor parses them
                var args = CommandLine.arguments
                let isEphemeral = args.contains("--ephemeral")
                let isSeed = args.contains("--seed")

                if args.contains("--help") || args.contains("-h") {
                    print("Usage: serve [options]")
                    print("Options:")
                    print("  --ephemeral   Triggers the Concrete DAOs and overrides DATABASE_URL with a throwaway database.")
                    print("  --seed        Runs the fake data seeder on startup (requires a concrete DB connection).")
                }

                args.removeAll { $0 == "--ephemeral" || $0 == "--seed" }
                var env = try Environment.detect(arguments: args)
        """
    } else {
        entrypointOutput += """
                var env = try Environment.detect()
        """
    }

    entrypointOutput += """

            try LoggingSystem.bootstrap(from: &env)
            let app = try await Application.make(env)
            defer { Task { try? await app.asyncShutdown() } }
    """

    if testsMocks {
        entrypointOutput += """

                // Database Connection Setup
                if isEphemeral {
                    app.databases.use(.sqlite(.memory), as: .sqlite)
                } else if let _ = Environment.get("DATABASE_URL") {
                    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite) // Use Postgres Driver in production
                }

                // Register migrations
        """
        for (schemaName, _) in sortedSchemas {
            entrypointOutput += "\n        app.migrations.add(Create\(schemaName)())"
        }
        entrypointOutput += """


                if isEphemeral || Environment.get("DATABASE_URL") != nil {
                    try await app.autoMigrate()
                }

                if isSeed && (isEphemeral || Environment.get("DATABASE_URL") != nil) {
                    try await DatabaseSeeder.seed(on: app.db)
                }
        """
    }

    entrypointOutput += """

            try routes(app)
            try await app.execute()
        }
    }
    """
    files["Entrypoint.swift"] = entrypointOutput

    return files
}

/// Emits a Swift server stub (e.g., using Vapor) from an OpenAPI Document.
public func emitServer(document: OpenAPIDocument, testsMocks: Bool = false) -> String {
    let files = emitServerFiles(document: document, testsMocks: testsMocks)
    let sortedKeys = files.keys.sorted()
    var output = ""
    for key in sortedKeys {
        if output.isEmpty {
            output = files[key]!
        } else {
            output += "\n\n" + files[key]!
        }
    }
    return output
}
