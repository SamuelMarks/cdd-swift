/// Vapor and Fluent model, DAO, migration, and database seeder emitter for OpenAPI documents.
import Foundation

/// Helper to map OpenAPI type to Vapor/Fluent field property wrapper.
///
/// - Parameter schema: The OpenAPI `Schema` to map to a Fluent column Swift type.
/// - Returns: The Swift type name used in Fluent `@Field` or `@OptionalField` wrappers.
func mapFluentFieldType(schema: Schema) -> String {
    if schema.ref != nil || schema.dynamicRef != nil {
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

/// Emits `Mocks/DatabaseSeeder.swift` for seeding Fluent models with Fakery data.
///
/// - Parameter schemas: Dictionary mapping schema names to their OpenAPI `Schema` definitions.
/// - Returns: Generated Swift source code for `DatabaseSeeder`.
public func emitDatabaseSeeder(for schemas: [String: Schema]) -> String {
    let sortedSchemas = schemas.sorted(by: { $0.key < $1.key })
    var seederContent = [
        "import Vapor",
        "import Fluent",
        "import Fakery",
        "",
        "/// Seeder for the application.",
        "public struct DatabaseSeeder {",
        "    /// Seeds the database with fake data.",
        "    public static func seed(on db: Database) async throws {",
        "        let faker = Faker()"
    ].joined(separator: "\n")
    for (schemaName, schema) in sortedSchemas {
        seederContent += "\n        for _ in 0..<10 {\n            let item = Fluent\(schemaName)()\n"
        if let properties = schema.properties {
            for (propName, propSchema) in properties where propName.lowercased() != "id" {
                let initVal = mapFakeryInitializer(schema: propSchema)
                seederContent += "            item.\(propName) = \(initVal)\n"
            }
        }
        seederContent += "            try await item.create(on: db)\n        }\n"
    }
    seederContent += "    }\n}\n"
    return seederContent
}

/// Emits a `Fluent<name>` class and its `toModel()` conversion method.
///
/// - Parameters:
///   - name: The PascalCase model name.
///   - schema: The OpenAPI `Schema` describing the model's properties.
/// - Returns: Generated Swift source code for `Models/Fluent<name>.swift`.
public func emitFluentModel(name: String, schema: Schema) -> String {
    var fluentOutput = [
        "import Vapor",
        "import Fluent",
        "",
        "/// Concrete Fluent Model for \(name).",
        "public final class Fluent\(name): Model, @unchecked Sendable {",
        "    /// Table schema name.",
        "    public static let schema = \"\(name.lowercased())s\"",
        "    /// Unique identifier.",
        "    @ID(key: .id) public var id: UUID?"
    ].joined(separator: "\n")

    let sortedProps = (schema.properties ?? [:]).sorted(by: { $0.key < $1.key })
    let requiredProps = Set(schema.required ?? [])
    for (propName, propSchema) in sortedProps where propName.lowercased() != "id" {
        let swiftType = mapFluentFieldType(schema: propSchema)
        let isRequired = requiredProps.contains(propName)
        if isRequired {
            fluentOutput += "\n    @Field(key: \"\(propName)\") public var \(propName): \(swiftType)"
        } else {
            fluentOutput += "\n    @OptionalField(key: \"\(propName)\") public var \(propName): \(swiftType)?"
        }
    }

    let initArgs = sortedProps.map { propName, propSchema in
        emitFluentToModelArg(
            propName: propName,
            propSchema: propSchema,
            isRequired: requiredProps.contains(propName)
        )
    }
    let initCall = "\(name)(\(initArgs.joined(separator: ", ")))"

    fluentOutput += [
        "",
        "    /// Default initializer.",
        "    public init() {}",
        "",
        "    /// Maps Fluent model properties to Codable struct.",
        "    public func toModel() throws -> \(name) {",
        "        return \(initCall)",
        "    }",
        "}"
    ].joined(separator: "\n")
    return fluentOutput
}

/// Emits a single property initializer argument for `Fluent<name>.toModel()`.
///
/// - Parameters:
///   - propName: The property identifier name.
///   - propSchema: The OpenAPI `Schema` of the property.
///   - isRequired: Whether the property is required.
/// - Returns: A formatted `"propName: expr"` string.
private func emitFluentToModelArg(propName: String, propSchema: Schema, isRequired: Bool) -> String {
    if propName.lowercased() == "id" {
        return "\(propName): \(emitFluentIdExpr(for: mapType(schema: propSchema)))"
    }
    let swiftType = mapFluentFieldType(schema: propSchema)
    let modelType = mapType(schema: propSchema)
    if swiftType == modelType {
        return "\(propName): self.\(propName)"
    }
    if propSchema.ref != nil || propSchema.dynamicRef != nil {
        return "\(propName): \(isRequired ? "\(modelType)()" : "nil")"
    }
    if propSchema.type == "array" {
        return "\(propName): []"
    }
    if modelType == "AnyCodable" {
        let valExpr = isRequired ? "AnyCodable(self.\(propName))" : "self.\(propName).map { AnyCodable($0) }"
        return "\(propName): \(valExpr)"
    }
    return "\(propName): nil"
}

/// Emits the fallback `id` conversion expression for `Fluent<name>.toModel()`.
///
/// - Parameter modelType: The Swift type of the model's `id` property.
/// - Returns: A Swift expression string producing the `id` value.
private func emitFluentIdExpr(for modelType: String) -> String {
    switch modelType {
    case "Int": "1"
    case "Int64": "Int64(1)"
    case "UUID": "self.id ?? UUID()"
    default: "self.id?.uuidString ?? UUID().uuidString"
    }
}

/// Emits `<name>DAO`, `Stub<name>DAO`, and `Concrete<name>DAO` implementations.
///
/// - Parameters:
///   - name: The PascalCase model name.
///   - schema: The OpenAPI `Schema` describing the model's properties.
/// - Returns: Generated Swift source code for the model's DAO types.
public func emitModelDAO(name: String, schema: Schema) -> String {
    let assignLines = emitModelDAOAssignments(schema: schema)
    let headerAndStub = emitDAOProtocolAndStub(name: name)
    return headerAndStub + "\n\n" + emitConcreteDAO(name: name, assignLines: assignLines)
}

/// Emits field assignment statements mapping a domain model to its `Fluent<name>` entity.
///
/// - Parameter schema: The OpenAPI `Schema` describing the model's properties.
/// - Returns: Newline-delimited Swift assignment statements.
private func emitModelDAOAssignments(schema: Schema) -> String {
    let sortedProps = (schema.properties ?? [:]).sorted(by: { $0.key < $1.key })
    let requiredProps = Set(schema.required ?? [])
    var assignLines = ""
    for (propName, propSchema) in sortedProps where propName.lowercased() != "id" {
        let swiftType = mapFluentFieldType(schema: propSchema)
        let modelType = mapType(schema: propSchema)
        let isRequired = requiredProps.contains(propName)
        if swiftType == modelType {
            assignLines += "        entity.\(propName) = model.\(propName)\n"
        } else if isRequired {
            assignLines += "        entity.\(propName) = String(describing: model.\(propName))\n"
        } else {
            assignLines += "        entity.\(propName) = model.\(propName).map { String(describing: $0) }\n"
        }
    }
    return assignLines
}

/// Emits the `<name>DAO` protocol and `Stub<name>DAO` struct.
///
/// - Parameter name: The PascalCase model name.
/// - Returns: Generated Swift source code for the DAO protocol and stub implementation.
private func emitDAOProtocolAndStub(name: String) -> String {
    [
        "import Vapor",
        "import Fluent",
        "",
        "/// Abstract Data Access Object for \(name).",
        "public protocol \(name)DAO: Sendable {",
        "    /// Retrieves all \(name) records.",
        "    func getAll() async throws -> [\(name)]",
        "    /// Retrieves a single \(name) by ID.",
        "    func get(id: UUID) async throws -> \(name)?",
        "    /// Creates a \(name).",
        "    func create(_ model: \(name)) async throws -> \(name)",
        "    /// Updates a \(name).",
        "    func update(_ model: \(name)) async throws -> \(name)",
        "    /// Deletes a \(name).",
        "    func delete(id: UUID) async throws",
        "}",
        "",
        "/// Stub Data Access Object for \(name).",
        "public struct Stub\(name)DAO: \(name)DAO {",
        "    /// Default initializer.",
        "    public init() {}",
        "    /// Retrieves all \(name) records.",
        "    public func getAll() async throws -> [\(name)] { throw Abort(.notImplemented) }",
        "    /// Retrieves a single \(name) by ID.",
        "    public func get(id: UUID) async throws -> \(name)? { throw Abort(.notImplemented) }",
        "    /// Creates a \(name).",
        "    public func create(_ model: \(name)) async throws -> \(name) { throw Abort(.notImplemented) }",
        "    /// Updates a \(name).",
        "    public func update(_ model: \(name)) async throws -> \(name) { throw Abort(.notImplemented) }",
        "    /// Deletes a \(name).",
        "    public func delete(id: UUID) async throws { throw Abort(.notImplemented) }",
        "}"
    ].joined(separator: "\n")
}

/// Emits the `Concrete<name>DAO` struct backed by Fluent.
///
/// - Parameters:
///   - name: The PascalCase model name.
///   - assignLines: Generated Swift property assignment lines for `create` and `update`.
/// - Returns: Generated Swift source code for `Concrete<name>DAO`.
private func emitConcreteDAO(name: String, assignLines: String) -> String {
    var lines = "/// Concrete Data Access Object for \(name) using Fluent.\n"
    lines += "public struct Concrete\(name)DAO: \(name)DAO {\n"
    lines += "    /// The database instance.\n"
    lines += "    public let db: Database\n"
    lines += "    /// Initializes the DAO with a database instance.\n"
    lines += "    public init(db: Database) { self.db = db }\n"
    lines += "    /// Retrieves all \(name) records.\n"
    lines += "    public func getAll() async throws -> [\(name)] {\n"
    lines += "        var results: [\(name)] = []\n"
    lines += "        for item in try await Fluent\(name).query(on: db).all() {\n"
    lines += "            results.append(try item.toModel())\n"
    lines += "        }\n"
    lines += "        return results\n"
    lines += "    }\n"
    lines += "    /// Retrieves a single \(name) by ID.\n"
    lines += "    public func get(id: UUID) async throws -> \(name)? { return try await Fluent\(name).find(id, on: db)?.toModel() }\n"
    lines += "    /// Creates a \(name).\n"
    lines += "    public func create(_ model: \(name)) async throws -> \(name) {\n"
    lines += "        let entity = Fluent\(name)()\n"
    lines += "\(assignLines)        try await entity.save(on: db)\n"
    lines += "        return model\n"
    lines += "    }\n"
    lines += "    /// Updates a \(name).\n"
    lines += "    public func update(_ model: \(name)) async throws -> \(name) {\n"
    lines += "        if let entity = try await Fluent\(name).query(on: db).first() {\n"
    lines += "\(assignLines)            try await entity.update(on: db)\n"
    lines += "        }\n"
    lines += "        return model\n"
    lines += "    }\n"
    lines += "    /// Deletes a \(name).\n"
    lines += "    public func delete(id: UUID) async throws { try await Fluent\(name).find(id, on: db)?.delete(on: db) }\n"
    lines += "}"
    return lines
}

/// Emits a `Create<name>: AsyncMigration` struct for a Fluent model.
///
/// - Parameters:
///   - name: The PascalCase model name.
///   - schema: The OpenAPI `Schema` describing the model's columns.
/// - Returns: Generated Swift source code for `Create<name>`.
public func emitModelMigration(name: String, schema: Schema) -> String {
    let requiredProps = Set(schema.required ?? [])
    var migrationOutput = [
        "/// Database Migration for \(name).",
        "public struct Create\(name): AsyncMigration {",
        "    /// Applies the migration.",
        "    public func prepare(on database: Database) async throws {",
        "        try await database.schema(\"\(name.lowercased())s\")",
        "            .id()"
    ].joined(separator: "\n")

    if let properties = schema.properties {
        for (propName, propSchema) in properties.sorted(by: { $0.key < $1.key }) where propName.lowercased() != "id" {
            let swiftType = mapFluentFieldType(schema: propSchema)
            let fieldType = mapMigrationDataType(for: swiftType)
            let reqSuffix = requiredProps.contains(propName) ? ", .required" : ""
            migrationOutput += "\n            .field(FieldKey(stringLiteral: \"\(propName)\"), \(fieldType)\(reqSuffix))"
        }
    }

    migrationOutput += [
        "",
        "            .create()",
        "    }",
        "    /// Reverts the migration.",
        "    public func revert(on database: Database) async throws {",
        "        try await database.schema(\"\(name.lowercased())s\").delete()",
        "    }",
        "}"
    ].joined(separator: "\n")
    return migrationOutput
}

/// Maps a Fluent Swift column type name to its Fluent migration `DatabaseSchema.DataType` literal.
///
/// - Parameter swiftType: The Swift type name returned by `mapFluentFieldType`.
/// - Returns: The Fluent `.string`, `.int`, `.double`, `.bool`, `.uuid`, or `.datetime` literal.
private func mapMigrationDataType(for swiftType: String) -> String {
    let mapping: [String: String] = [
        "String": ".string",
        "Int": ".int",
        "Double": ".double",
        "Bool": ".bool",
        "UUID": ".uuid",
        "Date": ".datetime"
    ]
    return mapping[swiftType] ?? ".string"
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
    let securitySchemes = document.components?.securitySchemes ?? document.securityDefinitions ?? [:]
    let sortedSchemas = schemas.sorted(by: { $0.key < $1.key })

    var extensionsOutput = "import Vapor\n\n"
    for (schemaName, _) in sortedSchemas {
        extensionsOutput += "extension \(schemaName): Content {}\n"
    }
    if !schemas.isEmpty {
        files["Models/Extensions.swift"] = extensionsOutput
    }

    if testsMocks, !schemas.isEmpty {
        files["Mocks/DatabaseSeeder.swift"] = emitDatabaseSeeder(for: schemas)
        for (schemaName, schema) in sortedSchemas {
            files["Models/Fluent\(schemaName).swift"] = emitFluentModel(name: schemaName, schema: schema)
            let daoOutput = emitModelDAO(name: schemaName, schema: schema)
            let migrationOutput = emitModelMigration(name: schemaName, schema: schema)
            files["Mocks/\(schemaName)DAO.swift"] = daoOutput + "\n" + migrationOutput
        }
    }

    files["Routes/Routes.swift"] = emitRoutesFile(
        document: document,
        schemas: schemas,
        securitySchemes: securitySchemes,
        testsMocks: testsMocks
    )
    files["Entrypoint.swift"] = emitVaporEntrypointFile(
        sortedSchemas: sortedSchemas,
        testsMocks: testsMocks
    )

    return files
}
