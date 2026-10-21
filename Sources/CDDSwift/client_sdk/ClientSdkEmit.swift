/// OpenAPI document builder and Swift SDK generator.
import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    /// The OpenAPI specification version.
    private var openapi: String = "3.2.0"
    /// Metadata about the API.
    private var info: Info
    /// The available paths and operations.
    private var paths: [String: PathItem] = [:]
    /// The incoming webhooks defined by the API.
    private var webhooks: [String: PathItem] = [:]
    /// Reusable data models.
    private var schemas: [String: Schema] = [:]
    /// Reusable security schemes.
    private var securitySchemes: [String: SecurityScheme] = [:]

    /// Initializes a builder with required API Info.
    ///
    /// - Parameters:
    ///   - title: The title of the API.
    ///   - version: The semantic version of the API.
    public init(title: String, version: String) {
        info = Info(title: title, version: version)
    }

    /// Adds a path with a specific item.
    ///
    /// - Parameters:
    ///   - path: The URL path template (e.g. `"/pets"`).
    ///   - item: The `PathItem` definition.
    /// - Returns: `self` for fluent chaining.
    public func addPath(_ path: String, item: PathItem) -> Self {
        paths[path] = item
        return self
    }

    /// Adds a webhook definition.
    ///
    /// - Parameters:
    ///   - name: The webhook identifier.
    ///   - item: The `PathItem` describing the webhook operations.
    /// - Returns: `self` for fluent chaining.
    public func addWebhook(_ name: String, item: PathItem) -> Self {
        webhooks[name] = item
        return self
    }

    /// Adds a reusable schema definition.
    ///
    /// - Parameters:
    ///   - name: The schema component name.
    ///   - schema: The `Schema` definition.
    /// - Returns: `self` for fluent chaining.
    public func addSchema(_ name: String, schema: Schema) -> Self {
        schemas[name] = schema
        return self
    }

    /// Adds a security scheme definition.
    ///
    /// - Parameters:
    ///   - name: The security scheme component name.
    ///   - scheme: The `SecurityScheme` definition.
    /// - Returns: `self` for fluent chaining.
    public func addSecurityScheme(_ name: String, scheme: SecurityScheme) -> Self {
        securitySchemes[name] = scheme
        return self
    }

    /// Builds the final OpenAPIDocument.
    ///
    /// - Returns: The constructed `OpenAPIDocument`.
    public func build() -> OpenAPIDocument {
        let components = Components(
            schemas: schemas.isEmpty ? nil : schemas,
            securitySchemes: securitySchemes.isEmpty ? nil : securitySchemes
        )
        return OpenAPIDocument(
            openapi: openapi,
            info: info,
            paths: paths.isEmpty ? nil : paths,
            webhooks: webhooks.isEmpty ? nil : webhooks,
            components: components
        )
    }

    /// Serializes the document to JSON.
    ///
    /// - Returns: A pretty-printed JSON string representation of the `OpenAPIDocument`.
    /// - Throws: An `EncodingError` if encoding fails.
    public func serialize() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(build())
        return String(decoding: data, as: UTF8.self)
    }
}

/// OpenAPIToSwiftGenerator generates swift SDK files from openapi models.
public enum OpenAPIToSwiftGenerator {
    /// Generates Swift files from the given OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The OpenAPI document to process.
    ///   - tests: A boolean flag indicating whether to generate tests along with the SDK files.
    /// - Returns: A dictionary of filenames to their generated Swift source code.
    public static func generateFiles(from document: OpenAPIDocument, tests: Bool = false) -> [String: String] {
        let modelsOutput = emitModelsFile(from: document)
        var clientOutput = emitAPIClientStruct(from: document)
        clientOutput += emitMCPAdapter(document: document)
        clientOutput += emitCallbacksAndWebhooks(from: document)

        var files: [String: String] = ["models.swift": modelsOutput]

        if tests {
            var mocksOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n"
            mocksOutput += "import GeneratedSDK\n\n"
            mocksOutput += emitMockClient(paths: document.paths)
            files["mocks.swift"] = mocksOutput

            var testsOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n"
            testsOutput += "import GeneratedSDK\n"
            testsOutput += "import GeneratedSDKMocks\n"
            let generatedTests = emitTests(paths: document.paths, document: document).replacingOccurrences(
                of: "import XCTest\n",
                with: "import XCTest\n\n"
            )
            let composableTests = generatedTests.replacingOccurrences(of: "final class APIClientTests", with: "open class APIClientTests")
            testsOutput += composableTests
            files["tests.swift"] = testsOutput
            files["client.swift"] = clientOutput
        } else {
            clientOutput += "// MARK: - Mocks\n\n"
            clientOutput += emitMockClient(paths: document.paths)
            clientOutput += "\n"
            clientOutput += "// MARK: - Tests Stub\n\n"
            clientOutput += emitTests(paths: document.paths, document: document)
            files["client.swift"] = clientOutput
        }

        return files
    }

    /// Emits `models.swift` containing all component schema models and embedded `AnyCodable`.
    ///
    /// - Parameter document: The `OpenAPIDocument` containing schemas.
    /// - Returns: Generated Swift source code for `models.swift`.
    private static func emitModelsFile(from document: OpenAPIDocument) -> String {
        var modelsOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        modelsOutput += "// MARK: - Models\n\n"
        if let schemas = document.components?.schemas ?? document.definitions {
            for (name, schema) in schemas.sorted(by: { $0.key < $1.key }) {
                modelsOutput += emitModel(name: name, schema: schema, schemas: schemas)
                modelsOutput += "\n"
            }
        }
        modelsOutput += AnyCodable.embeddedSwiftSource
        modelsOutput += "\n"
        return modelsOutput
    }

    /// Emits the `APIClient` struct declaration, initializer, and route methods.
    ///
    /// - Parameter document: The `OpenAPIDocument` describing paths and security schemes.
    /// - Returns: Generated Swift source code for `APIClient`.
    private static func emitAPIClientStruct(from document: OpenAPIDocument) -> String {
        var clientOutput = "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
        clientOutput += "// MARK: - API Client\n\n"
        clientOutput += emitDocstring("API Client for \(document.info.title) (v\(document.info.version))", indent: 0)
        clientOutput += "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\n"
        clientOutput += "public struct APIClient {\n"
        clientOutput += "    public let baseURL: URL\n"
        clientOutput += "    public let session: URLSession\n"

        let securitySchemes = document.components?.securitySchemes ?? document.securityDefinitions ?? [:]
        clientOutput += emitAPIClientInitializer(securitySchemes: securitySchemes)
        clientOutput += emitAPIClientMethods(document: document, securitySchemes: securitySchemes)
        clientOutput += "    public var mcp: MCPAdapter { MCPAdapter(client: self) }\n"
        clientOutput += "}\n\n"
        return clientOutput
    }

    /// Emits the security token properties and `public init` for `APIClient`.
    ///
    /// - Parameter securitySchemes: Map of security scheme names to `SecurityScheme` definitions.
    /// - Returns: Generated Swift source lines for properties and initializer.
    private static func emitAPIClientInitializer(securitySchemes: [String: SecurityScheme]) -> String {
        guard !securitySchemes.isEmpty else {
            return "\n    public init(baseURL: URL, session: URLSession = .shared) {\n" +
                "        self.baseURL = baseURL\n" +
                "        self.session = session\n" +
                "    }\n\n"
        }
        var output = ""
        for (key, scheme) in securitySchemes where scheme.type != nil {
            let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
            output += "    public let \(propName): String?\n"
        }
        output += "\n"
        var initParams = "baseURL: URL, session: URLSession = .shared"
        for (key, scheme) in securitySchemes where scheme.type != nil {
            let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
            initParams += ", \(propName): String? = nil"
        }
        output += "    public init(\(initParams)) {\n"
        output += "        self.baseURL = baseURL\n"
        output += "        self.session = session\n"
        for (key, scheme) in securitySchemes where scheme.type != nil {
            let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
            output += "        self.\(propName) = \(propName)\n"
        }
        output += "    }\n\n"
        return output
    }

    /// Emits all operation methods inside `APIClient` from `document.paths`.
    ///
    /// - Parameters:
    ///   - document: The `OpenAPIDocument`.
    ///   - securitySchemes: Map of security scheme definitions.
    /// - Returns: Generated Swift methods for all paths and operations.
    private static func emitAPIClientMethods(
        document: OpenAPIDocument,
        securitySchemes: [String: SecurityScheme]
    ) -> String {
        guard let paths = document.paths else { return "" }
        var output = ""
        for (path, item) in paths.sorted(by: { $0.key < $1.key }) {
            for (httpMethod, op) in item.operationsByMethod {
                output += emitMethod(
                    path: path,
                    method: httpMethod.rawValue.uppercased(),
                    operation: op,
                    documentSecurity: document.security,
                    securitySchemes: securitySchemes
                )
            }
            if let additional = item.additionalOperations {
                for (methodName, op) in additional {
                    output += emitMethod(
                        path: path,
                        method: methodName.uppercased(),
                        operation: op,
                        documentSecurity: document.security,
                        securitySchemes: securitySchemes
                    )
                }
            }
        }
        return output
    }

    /// Emits callback protocols and webhook handler protocols for `document`.
    ///
    /// - Parameter document: The `OpenAPIDocument`.
    /// - Returns: Generated Swift callback and webhook protocol definitions.
    private static func emitCallbacksAndWebhooks(from document: OpenAPIDocument) -> String {
        var output = ""
        if let paths = document.paths {
            for (_, item) in paths.sorted(by: { $0.key < $1.key }) {
                for (_, op) in item.operationsByMethod {
                    if let cbs = op.callbacks, !cbs.isEmpty {
                        output += emitCallbacks(operationId: op.operationId ?? "Unknown", callbacks: cbs)
                        output += "\n"
                    }
                }
            }
        }
        if let webhooks = document.webhooks, !webhooks.isEmpty {
            output += "// MARK: - Webhooks Protocol\n\n"
            output += emitWebhooks(webhooks: webhooks)
            output += "\n"
        }
        return output
    }

    /// Generates Swift code from the given OpenAPI document.
    ///
    /// - Parameter document: The OpenAPI document to process.
    /// - Returns: A string containing the generated Swift source code.
    public static func generate(from document: OpenAPIDocument) -> String {
        let files = generateFiles(from: document)
        var models = ""
        if let modelsFile = files["models.swift"] {
            models = modelsFile
        }
        var client = ""
        if let clientFile = files["client.swift"] {
            client = clientFile
        }
        let clientStripped = client.replacingOccurrences(
            of: "import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n",
            with: ""
        )
        return models + "\n" + clientStripped
    }
}
