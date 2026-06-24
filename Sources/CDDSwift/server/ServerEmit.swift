import Foundation

/// Helper to map OpenAPI type to Vapor/Fluent field property wrapper
func mapFluentFieldType(schema: Schema) -> String {
    if let ref = schema.ref ?? schema.dynamicRef {
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
public func emitServer(document: OpenAPIDocument, testsMocks: Bool = false) -> String {
    var output = "import Vapor\n"
    if testsMocks {
        output += "import Fluent\n"
        output += "import FluentSQLiteDriver\n"
        output += "import Fakery\n\n"
    }

    let schemas = document.components?.schemas ?? document.definitions ?? [:]
    let sortedSchemas = schemas.sorted(by: { $0.key < $1.key })

    if !schemas.isEmpty {
        output += "// MARK: - Content Extensions\n"
        for (schemaName, _) in sortedSchemas {
            output += "extension \(schemaName): Content {}\n"
        }
        output += "\n"

        if testsMocks {
            output += "// MARK: - Abstract DAO Interfaces\n"
            for (schemaName, _) in sortedSchemas {
                output += """
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
                \n
                """
            }

            output += "// MARK: - Stub DAOs\n"
            for (schemaName, _) in sortedSchemas {
                output += """
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
                \n
                """
            }

            output += "// MARK: - Concrete Fluent Models\n"
            for (schemaName, schema) in sortedSchemas {
                output += """
                /// Concrete Fluent Model for \(schemaName).
                public final class Fluent\(schemaName): Model, @unchecked Sendable {
                    /// Table schema name.
                    public static let schema = "\(schemaName.lowercased())s"
                    /// Unique identifier.
                    @ID(key: .id) public var id: UUID?
                """

                var fieldsInit = ""
                var toModelMap = ""

                if let properties = schema.properties {
                    for (propName, propSchema) in properties.sorted(by: { $0.key < $1.key }) {
                        if propName.lowercased() == "id" { continue } // id is handled by default
                        let swiftType = mapFluentFieldType(schema: propSchema)
                        let isRequired = schema.required?.contains(propName) ?? false

                        if isRequired {
                            output += "\n    @Field(key: \"\(propName)\") public var \(propName): \(swiftType)"
                            fieldsInit += "self.\(propName) = \(propName)\n        "
                            toModelMap += "\(propName): self.\(propName),\n            "
                        } else {
                            output += "\n    @OptionalField(key: \"\(propName)\") public var \(propName): \(swiftType)?"
                            fieldsInit += "self.\(propName) = \(propName)\n        "
                            toModelMap += "\(propName): self.\(propName),\n            "
                        }
                    }
                }

                output += """

                    /// Default initializer.
                    public init() {}

                    /// Maps Fluent model properties to Codable struct.
                    public func toModel() throws -> \(schemaName) {
                        // In YOLO mock mode, to avoid breaking initializer dependencies where some models have `id` and others don't,
                        // we simply return a default empty Codable object or try to decode it from JSON as a fallback for strict init requirements.
                        let data = "{}"
                        return try JSONDecoder().decode(\(schemaName).self, from: data.data(using: .utf8)!)
                    }
                }
                \n
                """
            }

            output += "// MARK: - Concrete DAOs\n"
            for (schemaName, _) in sortedSchemas {
                output += """
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
                \n
                """
            }

            output += "// MARK: - Migrations\n"
            for (schemaName, _) in sortedSchemas {
                output += """
                /// Database Migration for \(schemaName).
                public struct Create\(schemaName): AsyncMigration {
                    /// Applies the migration.
                    public func prepare(on database: Database) async throws {
                        try await database.schema("\(schemaName.lowercased())s")
                            .id()
                            .create()
                    }
                    /// Reverts the migration.
                    public func revert(on database: Database) async throws {
                        try await database.schema("\(schemaName.lowercased())s").delete()
                    }
                }
                \n
                """
            }

            output += "// MARK: - Seeder\n"
            output += """
            /// Seeder for the application.
            public struct DatabaseSeeder {
                /// Seeds the database with fake data.
                public static func seed(on db: Database) async throws {
                    let faker = Faker()
            """

            for (schemaName, schema) in sortedSchemas {
                output += """

                        for _ in 0..<10 {
                            let item = Fluent\(schemaName)()\n
                """
                if let properties = schema.properties {
                    for (propName, propSchema) in properties {
                        if propName.lowercased() == "id" { continue } // managed by Fluent UUID
                        let initVal = mapFakeryInitializer(schema: propSchema)
                        output += "            item.\(propName) = \(initVal)\n"
                    }
                }
                output += """
                            try await item.create(on: db)
                        }
                """
            }

            output += """

                }
            }
            \n
            """
        }
    }

    output += "// MARK: - Routes\n"
    output += "/// Registers routes to the Vapor application.\n"
    output += "public func routes(_ app: Application) throws {\n"

    output += """
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
            // Mock dispatcher
            return Response(status: .ok)
        }
    \n
    """

    if testsMocks {
        output += "    // Resolve DAOs based on configuration\n"
        output += "    let isEphemeral = ProcessInfo.processInfo.arguments.contains(\"--ephemeral\")\n"
        output += "    let hasDB = Environment.get(\"DATABASE_URL\") != nil\n"
        output += "    let useConcrete = isEphemeral || hasDB\n\n"

        for (schemaName, _) in sortedSchemas {
            output += "    let _\(schemaName.lowercased())DAO: \(schemaName)DAO = useConcrete ? Concrete\(schemaName)DAO(db: app.db) : Stub\(schemaName)DAO()\n"
        }
    }

    if let paths = document.paths {
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            // Convert OpenAPI path parameters like {id} to Vapor's :id
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
                output += "    app.\(method)(\(vaporPathArgs)) { req async throws -> Response in\n"

                output += """
                        if strictValidation {
                             // TODO: Inject OpenAPI specific validations
                        }
                        if enforceAuth {
                             guard let token = req.headers.bearerAuthorization?.token, token == "mock-token-123" else {
                                  throw Abort(.unauthorized)
                             }
                        }
                """

                output += "        // TODO: Implement \(handlerName)\n"

                // If it's testsMocks, wire up the mock DAO
                var wired = false
                if testsMocks {
                    // Try to extract the return type
                    if let successResponse = op.responses?["200"] ?? op.responses?["201"] ?? op.responses?["default"],
                       let content = successResponse.content,
                       let schema = content["application/json"]?.schema
                    {
                        if schema.type == "array", let items = schema.items, let ref = items.ref {
                            let returnType = ref.components(separatedBy: "/").last!
                            if schemas.keys.contains(returnType) {
                                output += "        let results = try await _\(returnType.lowercased())DAO.getAll()\n"
                                output += "        var res = Response(status: .ok)\n"
                                output += "        try res.content.encode(results)\n"
                                output += "        return res\n"
                                wired = true
                            }
                        } else if let ref = schema.ref ?? schema.dynamicRef {
                            let returnType = ref.components(separatedBy: "/").last!
                            if schemas.keys.contains(returnType) {
                                output += "        let result = try await _\(returnType.lowercased())DAO.getAll().first\n"
                                output += "        if let result = result {\n"
                                output += "            var res = Response(status: .ok)\n"
                                output += "            try res.content.encode(result)\n"
                                output += "            return res\n"
                                output += "        } else {\n"
                                output += "            throw Abort(.notFound)\n"
                                output += "        }\n"
                                wired = true
                            }
                        }
                    } else if method == "post" || method == "put" || method == "patch" || method == "delete" {
                        // It's a mutation without a definitive return type. Return 200 OK.
                        output += "        return Response(status: .ok)\n"
                        wired = true
                    }
                }

                if !wired {
                    output += "        return Response(status: .notImplemented)\n"
                }

                output += "    }\n"
            }
        }
    }

    if testsMocks {
        output += """
            // Integrated Identity Provider (IdP) Module
            let startAuthServer = ProcessInfo.processInfo.arguments.contains("--start-auth-server")
            if startAuthServer {
                app.post("auth", "register") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\"status\\":\\"registered\\"}"))
                }
                app.post("auth", "login") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\"token\\":\\"mock-token-123\\"}"))
                }
                app.post("auth", "refresh") { req async throws -> Response in
                    return Response(status: .ok, body: .init(string: "{\\"token\\":\\"mock-token-123\\"}"))
                }
                app.post("auth", "logout") { req async throws -> Response in
                    return Response(status: .ok)
                }
            }
        """
    }

    output += "}\n\n"

    output += "// MARK: - Entrypoint\n"
    output += """
    /// The main entrypoint for the generated Vapor application.
    @main
    public struct GeneratedServer {
        /// The main execution function.
        public static func main() async throws {
            var env = try Environment.detect()

    """

    if testsMocks {
        output += """
                // Extract custom arguments before Vapor parses them
                let isEphemeral = env.arguments.contains("--ephemeral")
                let isSeed = env.arguments.contains("--seed")

                if env.arguments.contains("--help") || env.arguments.contains("-h") {
                    print("Usage: serve [options]")
                    print("Options:")
                    print("  --ephemeral   Triggers the Concrete DAOs and overrides DATABASE_URL with a throwaway database.")
                    print("  --seed        Runs the fake data seeder on startup (requires a concrete DB connection).")
                }

                env.arguments.removeAll { $0 == "--ephemeral" || $0 == "--seed" }
        """
    }

    output += """

            try LoggingSystem.bootstrap(from: &env)
            let app = try await Application.make(env)
            defer { Task { try? await app.asyncShutdown() } }
    """

    if testsMocks {
        output += """

                // Database Connection Setup
                if isEphemeral {
                    app.databases.use(.sqlite(.memory), as: .sqlite)
                } else if let _ = Environment.get("DATABASE_URL") {
                    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite) // Use Postgres Driver in production
                }

                // Register migrations
        """
        for (schemaName, _) in sortedSchemas {
            output += "\n        app.migrations.add(Create\(schemaName)())"
        }
        output += """


                if isEphemeral || Environment.get("DATABASE_URL") != nil {
                    try await app.autoMigrate()
                }

                if isSeed && (isEphemeral || Environment.get("DATABASE_URL") != nil) {
                    try await DatabaseSeeder.seed(on: app.db)
                }
        """
    }

    output += """

            try routes(app)
            try await app.execute()
        }
    }
    """

    return output
}
