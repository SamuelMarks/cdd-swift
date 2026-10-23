/// XCTest suite and deterministic dummy JSON payload emitter for OpenAPI documents.
import Foundation

/// Context encapsulating the schema parameters needed to generate deterministic dummy JSON payloads.
public struct DummyJSONContext: Sendable {
    /// The OpenAPI type name.
    public let type: String?
    /// Optional format hint (e.g. `"uuid"`, `"date-time"`, `"email"`, `"uri"`).
    public let format: String?
    /// Optional `$ref` pointer to another schema definition.
    public let ref: String?
    /// Object property definitions keyed by property name.
    public let properties: [String: Schema]?
    /// Names of required object properties.
    public let required: [String]?
    /// Array element schema item descriptor.
    public let items: SchemaItem?
    /// Optional closed set of allowed enum values.
    public let enumValues: [AnyCodable]?
    /// Optional schema default or example value.
    public let exampleOrDefault: AnyCodable?
    /// Reusable component schema definitions keyed by schema name.
    public let schemas: [String: Schema]?
    /// Set of already-visited schema names to prevent infinite recursion on cyclic schemas.
    public let visited: Set<String>

    /// Initializes a `DummyJSONContext`.
    ///
    /// - Parameters:
    ///   - type: The OpenAPI type name.
    ///   - format: Optional format modifier string.
    ///   - ref: Optional `$ref` pointer string.
    ///   - properties: Object property schemas keyed by name.
    ///   - required: Required property names.
    ///   - items: Array item schema descriptor.
    ///   - enumValues: Optional list of allowed enum values.
    ///   - exampleOrDefault: Optional example or default value.
    ///   - schemas: Component schema registry for resolving `$ref` pointers.
    ///   - visited: Set of visited schema names to guard against cycles.
    public init(
        type: String? = nil,
        format: String? = nil,
        ref: String? = nil,
        properties: [String: Schema]? = nil,
        required: [String]? = nil,
        items: SchemaItem? = nil,
        enumValues: [AnyCodable]? = nil,
        exampleOrDefault: AnyCodable? = nil,
        schemas: [String: Schema]? = nil,
        visited: Set<String> = []
    ) {
        self.type = type
        self.format = format
        self.ref = ref
        self.properties = properties
        self.required = required
        self.items = items
        self.enumValues = enumValues
        self.exampleOrDefault = exampleOrDefault
        self.schemas = schemas
        self.visited = visited
    }
}

/// Synthesizes a Swift literal expression for a parameter in generated test cases using schema metadata (`example`, `default`, `enum`,
/// `format`, `type`).
///
/// - Parameters:
///   - param: The OpenAPI `Parameter` descriptor.
///   - swiftType: The mapped Swift type name for the parameter.
/// - Returns: A valid Swift literal expression string.
public func synthesizeDummyParameterLiteral(param: Parameter, swiftType: String) -> String {
    let q = String(UnicodeScalar(34))
    if let ex = param.example ?? param.schema?.example ?? param.schema?.default_value,
       let str = ex.stringValue {
        return swiftType.hasPrefix("[") ? "[\(q)\(str)\(q)]" : "\(q)\(str)\(q)"
    }
    if let firstEnum = param.schema?.enum_values?.first?.stringValue {
        return swiftType.hasPrefix("[") ? "[\(q)\(firstEnum)\(q)]" : "\(q)\(firstEnum)\(q)"
    }
    let literalByType: [String: String] = [
        "UUID": "UUID()",
        "Date": "Date()",
        "Data": "Data(\(q)test_data\(q).utf8)",
        "Int": "1",
        "Int64": "1",
        "Int32": "1",
        "Bool": "true",
        "Double": "1.0",
        "Float": "1.0",
        "[String]": "[\(q)available\(q)]"
    ]
    if let match = literalByType[swiftType] {
        return match
    }
    if swiftType.hasPrefix("[") {
        return "[]"
    }
    return "\(q)test_string\(q)"
}

/// Generates dummy JSON based on a `DummyJSONContext`.
///
/// - Parameter context: The `DummyJSONContext` describing the schema.
/// - Returns: A string representation of the dummy JSON.
public func generateDummyJSON(context: DummyJSONContext) -> String {
    let q = String(UnicodeScalar(34))
    if let ref = context.ref {
        return generateReferencedDummyJSON(ref: ref, context: context)
    }

    if let firstEnum = context.enumValues?.first?.stringValue {
        return "\(q)\(firstEnum)\(q)"
    }

    let t = context.type ?? "object"
    switch t {
    case "string":
        return generateDummyStringJSON(format: context.format)
    case "integer", "number":
        return "1"
    case "boolean":
        return "true"
    case "array":
        return generateDummyArrayJSON(context: context)
    case "object":
        return generateDummyObjectJSON(context: context)
    default:
        return "{}"
    }
}

/// Resolves a `$ref` schema pointer and generates its dummy JSON representation while guarding against cycles.
///
/// - Parameters:
///   - ref: The `$ref` string.
///   - context: The current `DummyJSONContext`.
/// - Returns: The resolved dummy JSON string (or `"{}"` if cyclic or missing).
private func generateReferencedDummyJSON(ref: String, context: DummyJSONContext) -> String {
    let name = lastPathSegment(ref)
    if context.visited.contains(name) {
        return "{}"
    }
    guard let s = context.schemas?[name] else {
        return "{}"
    }
    var newVisited = context.visited
    newVisited.insert(name)
    return generateDummyJSON(
        context: DummyJSONContext(
            type: s.type,
            format: s.format,
            ref: s.ref,
            properties: s.properties,
            required: s.required,
            items: s.items,
            enumValues: s.enum_values,
            exampleOrDefault: s.example ?? s.default_value,
            schemas: context.schemas,
            visited: newVisited
        )
    )
}

/// Generates a dummy JSON string literal for an OpenAPI `"string"` schema based on its format.
///
/// - Parameter format: Optional format string (`"uuid"`, `"date-time"`, etc.).
/// - Returns: Quoted JSON string literal.
private func generateDummyStringJSON(format: String?) -> String {
    let q = String(UnicodeScalar(34))
    if format == "uuid" {
        return "\(q)00000000-0000-0000-0000-000000000000\(q)"
    }
    if format == "date-time" {
        return "\(q)2026-01-01T00:00:00Z\(q)"
    }
    return "\(q)test_string\(q)"
}

/// Generates a dummy JSON array literal for an OpenAPI `"array"` schema.
///
/// - Parameter context: The `DummyJSONContext` containing `items`.
/// - Returns: JSON array literal string.
private func generateDummyArrayJSON(context: DummyJSONContext) -> String {
    guard let items = context.items else {
        return "[]"
    }
    let itemStr = generateDummyJSON(
        context: DummyJSONContext(
            type: items.type,
            format: items.format,
            ref: items.ref,
            schemas: context.schemas,
            visited: context.visited
        )
    )
    return "[\(itemStr)]"
}

/// Generates a dummy JSON object literal for an OpenAPI `"object"` schema.
///
/// - Parameter context: The `DummyJSONContext` containing `properties` and `required`.
/// - Returns: JSON object literal string.
private func generateDummyObjectJSON(context: DummyJSONContext) -> String {
    let q = String(UnicodeScalar(34))
    var dict: [String] = []
    var keysToInclude = context.required ?? []
    if keysToInclude.isEmpty, let propKeys = context.properties?.keys.sorted() {
        keysToInclude = propKeys
    }

    for key in keysToInclude {
        if let p = context.properties?[key] {
            let val = generateDummyJSON(
                context: DummyJSONContext(
                    type: p.type,
                    format: p.format,
                    ref: p.ref,
                    properties: p.properties,
                    required: p.required,
                    items: p.items,
                    enumValues: p.enum_values,
                    exampleOrDefault: p.example ?? p.default_value,
                    schemas: context.schemas,
                    visited: context.visited
                )
            )
            dict.append("\(q)\(key)\(q): \(val)")
        } else {
            dict.append("\(q)\(key)\(q): \(q)\(q)")
        }
    }
    return "{\(dict.joined(separator: ", "))}"
}

/// Emits XCTest cases based on the OpenAPI Spec.
///
/// - Parameters:
///   - paths: Optional map of endpoint paths to `PathItem` definitions.
///   - document: Optional full `OpenAPIDocument` providing component schemas and security schemes.
/// - Returns: Generated `APIClientTests` Swift source code.
public func emitTests(paths: [String: PathItem]?, document: OpenAPIDocument? = nil) -> String {
    var output = emitTestsClassHeader(document: document)
    let schemas = document?.components?.schemas ?? document?.definitions

    if let paths {
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            for (httpMethod, op) in item.operationsByMethod {
                output += emitOperationTestMethod(
                    path: path,
                    method: httpMethod.rawValue.uppercased(),
                    op: op,
                    schemas: schemas
                )
            }
        }
    } else {
        output += "    public func testExample() async throws {\n"
        output += "        XCTAssertNotNil(client)\n"
        output += "    }\n"
    }

    output += "}\n"
    return output
}

/// Emits the imports, class declaration, `setUp()`, and `tearDown()` methods for `APIClientTests`.
///
/// - Parameter document: Optional `OpenAPIDocument` used to inspect security schemes.
/// - Returns: Generated Swift class header for `APIClientTests`.
private func emitTestsClassHeader(document: OpenAPIDocument?) -> String {
    var output = "import XCTest\nimport Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n"
    output += "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\n"
    output += "open class APIClientTests: XCTestCase {\n"

    let securitySchemes = document?.components?.securitySchemes ?? document?.securityDefinitions ?? [:]
    var tokenArgs = ""
    for (key, scheme) in securitySchemes where scheme.type != nil {
        let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
        let envName = key.uppercased() + "_TOKEN"
        tokenArgs += ", \(propName): ProcessInfo.processInfo.environment[\"\(envName)\"] ?? \"test_token\""
    }

    output += """
            public var client: APIClient?

            open override func setUp() {
                super.setUp()
                let configuration = URLSessionConfiguration.default
                let session = URLSession(configuration: configuration)
                let baseURLStr = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8080/v2"
                let resolvedURL = URL(string: baseURLStr) ?? URL(fileURLWithPath: "/")
                client = APIClient(baseURL: resolvedURL, session: session\(tokenArgs))

            }

            open override func tearDown() {
                super.tearDown()
            }

    """
    return output
}

/// Emits a single XCTest method exercising an OpenAPI operation on `APIClient`.
///
/// - Parameters:
///   - path: The URL path template string.
///   - method: The uppercase HTTP method name.
///   - op: The OpenAPI `Operation` descriptor.
///   - schemas: Optional dictionary of component schemas.
/// - Returns: Generated Swift test method source code.
private func emitOperationTestMethod(
    path: String,
    method: String,
    op: Operation,
    schemas: [String: Schema]?
) -> String {
    let cleanPath = path
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
    let funcName = op.operationId ?? "\(method.lowercased())\(cleanPath)"

    var callArgs = buildParameterTestCallArgs(from: op.parameters)
    if let bodyArg = buildBodyTestCallArg(for: op, schemas: schemas) {
        callArgs.append(bodyArg)
    }

    let callArgsString = callArgs.joined(separator: ", ")
    let testPrefix = testOrderPrefix(forMethod: method)
    let testName = "test\(testPrefix)\(funcName.prefix(1).uppercased())\(funcName.dropFirst())"

    var output = "\n    public func \(testName)() async throws {\n"
    output += "        XCTAssertNotNil(client)\n"
    output += "        do {\n"
    output += "            let _ = try await client?.\(funcName)(\(callArgsString))\n"
    output += "        } catch {\n"
    output += "            // Ignore server errors for dummy data\n"
    output += "        }\n"
    output += "    }\n"
    return output
}

/// Builds test invocation argument strings for non-body operation parameters.
///
/// - Parameter parameters: Optional array of OpenAPI `Parameter` definitions.
/// - Returns: Array of `"paramName: dummyLiteral"` strings.
private func buildParameterTestCallArgs(from parameters: [Parameter]?) -> [String] {
    guard let params = parameters else { return [] }
    var callArgs: [String] = []
    for param in params where param.in != "body" {
        let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
        let safePName = pName.replacingOccurrences(of: "-", with: "_")
        let type = param.schema.map { mapType(schema: $0) } ?? "String"
        let isRequired = param.required ?? false
        let pIn: ParameterLocation = param.in ?? .query
        let dummyValue = synthesizeDummyParameterLiteral(param: param, swiftType: type)

        if isRequired || pIn == .formData || pIn == .header || param.schema?.enum_values != nil || param.example != nil {
            callArgs.append("\(safePName): \(dummyValue)")
        }
    }
    return callArgs
}

/// Describes the parameter name, Swift type, and `Schema` for a test call's request body.
private struct TestBodyDescriptor {
    /// Parameter label in the generated `APIClient` method.
    let paramName: String
    /// Mapped Swift type name.
    let swiftType: String
    /// Underlying OpenAPI `Schema` for the body.
    let schema: Schema
}

/// Extracts request body metadata and builds a dummy request body argument string for a generated test call.
///
/// - Parameters:
///   - op: The OpenAPI `Operation` descriptor.
///   - schemas: Optional dictionary of component schemas.
/// - Returns: Formatted `"bodyParam: expr"` string if a body argument should be passed, or `nil`.
private func buildBodyTestCallArg(for op: Operation, schemas: [String: Schema]?) -> String? {
    guard let descriptor = resolveTestBodyDescriptor(for: op) else {
        return nil
    }
    let bodyParamName = descriptor.paramName
    let bodyType = descriptor.swiftType
    let bodySchema = descriptor.schema
    let isRequired = op.requestBody?.required ?? true
    guard isRequired || bodyType == "Data" else {
        return nil
    }
    if bodyType == "String" {
        return "\(bodyParamName): \"test_string\""
    }
    if bodyType == "Data" {
        return "\(bodyParamName): Data(\"test_data\".utf8)"
    }
    let jsonStr = generateDummyJSON(
        context: DummyJSONContext(
            type: bodySchema.type,
            format: bodySchema.format,
            ref: bodySchema.ref,
            properties: bodySchema.properties,
            required: bodySchema.required,
            items: bodySchema.items,
            enumValues: bodySchema.enum_values,
            exampleOrDefault: bodySchema.example ?? bodySchema.default_value,
            schemas: schemas
        )
    )
    let escapedJson = jsonStr.replacingOccurrences(of: "\"", with: "\\\"")
    return "\(bodyParamName): try JSONDecoder().decode(\(bodyType).self, from: Data(\"\(escapedJson)\".utf8))"
}

/// Resolves the parameter name, Swift type name, and `Schema` for an operation's request body.
///
/// - Parameter op: The OpenAPI `Operation` descriptor.
/// - Returns: A `TestBodyDescriptor` if the operation has a request body, or `nil`.
private func resolveTestBodyDescriptor(for op: Operation) -> TestBodyDescriptor? {
    if let reqBody = op.requestBody {
        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
            return TestBodyDescriptor(paramName: "body", swiftType: mapType(schema: schema), schema: schema)
        }
        if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
            return TestBodyDescriptor(paramName: "formData", swiftType: mapType(schema: schema), schema: schema)
        }
        if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
            return TestBodyDescriptor(paramName: "multipartData", swiftType: mapType(schema: schema), schema: schema)
        }
        if let octetContent = reqBody.content?["application/octet-stream"], let schema = octetContent.schema {
            return TestBodyDescriptor(paramName: "fileData", swiftType: "Data", schema: schema)
        }
    }
    if let globalParams = op.parameters {
        for param in globalParams where param.in == "body" {
            if let schema = param.schema {
                return TestBodyDescriptor(paramName: param.name ?? "body", swiftType: mapType(schema: schema), schema: schema)
            }
        }
    }
    return nil
}

/// Returns a numeric ordering prefix for test names so CRUD operations run in a logical lifecycle order (`POST` -> `PUT` -> `PATCH` ->
/// `GET` -> `DELETE`).
///
/// - Parameter method: Uppercase HTTP method string.
/// - Returns: Prefix string such as `"01_POST_"`.
private func testOrderPrefix(forMethod method: String) -> String {
    switch method.uppercased() {
    case "POST": "01_POST_"
    case "PUT": "02_PUT_"
    case "PATCH": "03_PATCH_"
    case "GET": "04_GET_"
    case "DELETE": "99_DELETE_"
    default: "50_"
    }
}
