import Foundation

/// A builder to construct an OpenAPI Document in Swift.
public class OpenAPIDocumentBuilder {
    private var openapi: String = "3.2.0"
    private var info: Info
    private var paths: [String: PathItem] = [:]
    private var webhooks: [String: PathItem] = [:]
    private var schemas: [String: Schema] = [:]
    private var securitySchemes: [String: SecurityScheme] = [:]
    
    /// Initializes a builder with required API Info.
    public init(title: String, version: String) {
        self.info = Info(title: title, version: version)
    }
    
    /// Adds a path with a specific item.
    public func addPath(_ path: String, item: PathItem) -> Self {
        self.paths[path] = item
        return self
    }
    
    /// Adds a webhook definition.
    public func addWebhook(_ name: String, item: PathItem) -> Self {
        self.webhooks[name] = item
        return self
    }
    
    /// Adds a reusable schema definition.
    public func addSchema(_ name: String, schema: Schema) -> Self {
        self.schemas[name] = schema
        return self
    }

    /// Adds a security scheme definition.
    public func addSecurityScheme(_ name: String, scheme: SecurityScheme) -> Self {
        self.securitySchemes[name] = scheme
        return self
    }
    
    /// Builds the final OpenAPIDocument.
    public func build() -> OpenAPIDocument {
        let components = Components(
            schemas: self.schemas.isEmpty ? nil : self.schemas,
            securitySchemes: self.securitySchemes.isEmpty ? nil : self.securitySchemes
        )
        return OpenAPIDocument(
            openapi: self.openapi,
            info: self.info,
            paths: self.paths.isEmpty ? nil : self.paths,
            webhooks: self.webhooks.isEmpty ? nil : self.webhooks,
            components: components
        )
    }
    
    /// Serializes the document to JSON.
    public func serialize() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(build())
        return String(data: data, encoding: .utf8) ?? ""
    }
}
