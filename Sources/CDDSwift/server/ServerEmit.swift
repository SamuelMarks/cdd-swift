/// Vapor and Fluent server stub, DAO, migration, and database seeder emitter for OpenAPI documents.
import Foundation

/// Helper to map OpenAPI type to Vapor/Fluent field property wrapper.
///
/// - Parameter schema: The OpenAPI `Schema` to map to a Fluent column Swift type.
/// - Returns: The Swift type name used in Fluent `@Field` or `@OptionalField` wrappers.
func mapFluentFieldType(schema: Schema) -> String {
    if schema.ref != nil || schema.dynamicRef != nil {
        // Use String instead of UUID to prevent type casting issues dynamically
        return "String"
    }
    switch schema.type {
    case "string":
        if schema.format == "date-time" {
            return "Date"
        }
        if schema.format == "uuid" {
            return "UUID"
        }
        if schema.format == "binary" {
            return "Data"
        }
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

/// Helper to map Fakery initialization logic to properties.
///
/// - Parameter schema: The OpenAPI `Schema` describing the property to seed.
/// - Returns: A Swift expression string using `Fakery` or Foundation initializers.
func mapFakeryInitializer(schema: Schema) -> String {
    if schema.ref != nil || schema.dynamicRef != nil {
        return "\"mock_reference_string\""
    }
    switch schema.type {
    case "string":
        if schema.format == "date-time" {
            return "Date()"
        }
        if schema.format == "uuid" {
            return "UUID()"
        }
        return "faker.name.name()"
    case "integer": return schema.format == "int64" ? "Int64(faker.number.randomInt())" : "faker.number.randomInt()"
    case "number": return schema.format == "float" ? "Float(faker.number.randomDouble())" : "faker.number.randomDouble()"
    case "boolean": return "faker.number.randomBool()"
    case "array", "object": return "\"[]\""
    default: return "\"\""
    }
}

/// Emits Swift server stub files (e.g., using Vapor) from an OpenAPI Document.
///
/// - Parameters:
///   - document: The `OpenAPIDocument` describing schemas, paths, and security schemes.
///   - testsMocks: Whether to generate Fluent models, DAOs, migrations, and Fakery seeders.
/// - Returns: A dictionary mapping relative file paths to their generated Swift source code.
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
        var seederContent = """
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
            seederContent += "\n                for _ in 0..<10 {\n                    let item = Fluent\(schemaName)()\n"
            if let properties = schema.properties {
                for (propName, propSchema) in properties {
                    if propName.lowercased() == "id" {
                        continue
                    }
                    let initVal = mapFakeryInitializer(schema: propSchema)
                    seederContent += "                    item.\(propName) = \(initVal)\n"
                }
            }
            seederContent += "                    try await item.create(on: db)\n                }\n"
        }
        seederContent += "            }\n        }\n"
        files["Mocks/DatabaseSeeder.swift"] = seederContent

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

            let sortedProps = (schema.properties ?? [:]).sorted(by: { $0.key < $1.key })
            let requiredProps = Set(schema.required ?? [])
            for (propName, propSchema) in sortedProps {
                if propName.lowercased() == "id" {
                    continue
                }
                let swiftType = mapFluentFieldType(schema: propSchema)
                let isRequired = requiredProps.contains(propName)
                if isRequired {
                    fluentOutput += "\n    @Field(key: \"\(propName)\") public var \(propName): \(swiftType)"
                } else {
                    fluentOutput += "\n    @OptionalField(key: \"\(propName)\") public var \(propName): \(swiftType)?"
                }
            }

            let q = String(UnicodeScalar(34))
            let nl = String(UnicodeScalar(10))
            var dictEntries: [String] = []
            for (propName, propSchema) in sortedProps {
                if propName.lowercased() == "id" {
                    if propSchema.type == "integer" {
                        dictEntries.append("\(q)id\(q): 1")
                    } else {
                        dictEntries.append("\(q)id\(q): self.id?.uuidString ?? UUID().uuidString")
                    }
                    continue
                }
                let swiftType = mapFluentFieldType(schema: propSchema)
                let isRequired = requiredProps.contains(propName)
                if swiftType == "Date" {
                    dictEntries.append("\(q)\(propName)\(q): ISO8601DateFormatter().string(from: \(isRequired ? "self.\(propName)" : "(self.\(propName) ?? Date())"))")
                } else if swiftType == "UUID" {
                    dictEntries.append("\(q)\(propName)\(q): \(isRequired ? "self.\(propName).uuidString" : "(self.\(propName)?.uuidString ?? UUID().uuidString)")")
                } else if swiftType == "Data" {
                    dictEntries.append("\(q)\(propName)\(q): \(isRequired ? "self.\(propName).base64EncodedString()" : "(self.\(propName)?.base64EncodedString() ?? \(q)\(q))")")
                } else if isRequired {
                    dictEntries.append("\(q)\(propName)\(q): self.\(propName)")
                } else {
                    dictEntries.append("\(q)\(propName)\(q): self.\(propName) as Any")
                }
            }
            let dictBody = dictEntries.isEmpty ? "[:]" : "[" + nl + "            " + dictEntries.joined(separator: "," + nl + "            ") + nl + "        ]"

            var assignLines = ""
            for (propName, propSchema) in sortedProps {
                if propName.lowercased() == "id" {
                    continue
                }
                let swiftType = mapFluentFieldType(schema: propSchema)
                let modelType = mapType(schema: propSchema)
                let isRequired = requiredProps.contains(propName)
                if swiftType == modelType {
                    assignLines += "        entity.\(propName) = model.\(propName)" + nl
                } else if isRequired {
                    assignLines += "        entity.\(propName) = String(describing: model.\(propName))" + nl
                } else {
                    assignLines += "        entity.\(propName) = model.\(propName).map { String(describing: $0) }" + nl
                }
            }

            fluentOutput += """

                /// Default initializer.
                public init() {}

                /// Maps Fluent model properties to Codable struct.
                public func toModel() throws -> \(schemaName) {
                    let rawDict: [String: Any] = \(dictBody)
                    let filtered = rawDict.compactMapValues { val -> Any? in
                        let mirror = Mirror(reflecting: val)
                        if mirror.displayStyle == .optional { return mirror.children.first?.value }
                        return val
                    }
                    let data = try JSONSerialization.data(withJSONObject: filtered)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(\(schemaName).self, from: data)
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
                public func create(_ model: \(schemaName)) async throws -> \(schemaName) {
                    let entity = Fluent\(schemaName)()
            \(assignLines)        try await entity.save(on: db)
                    return model
                }
                /// Updates a \(schemaName).
                public func update(_ model: \(schemaName)) async throws -> \(schemaName) {
                    if let entity = try await Fluent\(schemaName).query(on: db).first() {
            \(assignLines)            try await entity.update(on: db)
                    }
                    return model
                }
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
                    if propName.lowercased() == "id" {
                        continue
                    }
                    let swiftType = mapFluentFieldType(schema: propSchema)
                    let isRequired = requiredProps.contains(propName)
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

    files["Routes/Routes.swift"] = emitVaporRoutesFile(
        document: document,
        schemas: schemas,
        sortedSchemas: sortedSchemas,
        testsMocks: testsMocks
    )
    files["Entrypoint.swift"] = emitVaporEntrypointFile(
        sortedSchemas: sortedSchemas,
        testsMocks: testsMocks
    )

    return files
}

/// Emits `Routes/Routes.swift` for the given `OpenAPIDocument`.
///
/// - Parameters:
///   - document: The `OpenAPIDocument` describing paths and operations.
///   - schemas: Dictionary of resolved component schemas.
///   - sortedSchemas: Sorted array of `(schemaName, Schema)` pairs.
///   - testsMocks: Whether DAO wiring and mock identity provider routes should be emitted.
/// - Returns: Generated Swift source code for `Routes/Routes.swift`.
private func emitVaporRoutesFile(
    document: OpenAPIDocument,
    schemas: [String: Schema],
    sortedSchemas: [(key: String, value: Schema)],
    testsMocks: Bool
) -> String {
    var routesOutput = "import Vapor\n"
    if testsMocks {
        routesOutput += "import Fluent\n"
    }
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
                             if (req.method == .POST || req.method == .PUT || req.method == .PATCH) && req.body.data == nil {
                                  throw Abort(.badRequest)
                             }
                        }
                        if enforceAuth {
                             guard let token = req.headers.bearerAuthorization?.token, token == "mock-token-123" else {
                                  throw Abort(.unauthorized)
                             }
                        }
                        // Handler for \(handlerName)
                """

                var wired = false
                if testsMocks {
                    if let successResponse = op.responses?["200"] ?? op.responses?["201"] ?? op.responses?["default"],
                       let content = successResponse.content,
                       let schema = content["application/json"]?.schema
                    {
                        if schema.type == "array", let items = schema.items, let ref = items.ref {
                            let returnType = lastPathSegment(ref)
                            if schemas.keys.contains(returnType) {
                                routesOutput += "\n        let results = try await _\(returnType.lowercased())DAO.getAll()\n"
                                routesOutput += "        var res = Response(status: .ok)\n"
                                routesOutput += "        try res.content.encode(results)\n"
                                routesOutput += "        return res\n"
                                wired = true
                            }
                        } else if let ref = schema.ref ?? schema.dynamicRef {
                            let returnType = lastPathSegment(ref)
                            if schemas.keys.contains(returnType) {
                                if method == "post" {
                                    routesOutput += "\n        if let decoded = try? req.content.decode(\(returnType).self) {\n"
                                    routesOutput += "            let created = try await _\(returnType.lowercased())DAO.create(decoded)\n"
                                    routesOutput += "            var res = Response(status: .ok)\n"
                                    routesOutput += "            try res.content.encode(created)\n"
                                    routesOutput += "            return res\n"
                                    routesOutput += "        }\n"
                                } else if method == "put" {
                                    routesOutput += "\n        if let decoded = try? req.content.decode(\(returnType).self) {\n"
                                    routesOutput += "            let updated = try await _\(returnType.lowercased())DAO.update(decoded)\n"
                                    routesOutput += "            var res = Response(status: .ok)\n"
                                    routesOutput += "            try res.content.encode(updated)\n"
                                    routesOutput += "            return res\n"
                                    routesOutput += "        }\n"
                                }
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
    return routesOutput
}

/// Emits `Entrypoint.swift` containing the `@main` `GeneratedServer` struct for Vapor.
///
/// - Parameters:
///   - sortedSchemas: Sorted array of `(schemaName, Schema)` pairs.
///   - testsMocks: Whether database configuration, migrations, and seeding are enabled.
/// - Returns: Generated Swift source code for `Entrypoint.swift`.
private func emitVaporEntrypointFile(
    sortedSchemas: [(key: String, value: Schema)],
    testsMocks: Bool
) -> String {
    var entrypointOutput = "import Vapor\n"
    if testsMocks {
        entrypointOutput += "import Fluent\nimport FluentSQLiteDriver\n"
    }
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
    return entrypointOutput
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
