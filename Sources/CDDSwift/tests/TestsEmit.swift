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

/// Synthesizes a Swift literal expression for a parameter in generated test cases using schema metadata (`example`, `default`, `enum`, `format`, `type`).
///
/// - Parameters:
///   - param: The OpenAPI `Parameter` descriptor.
///   - swiftType: The mapped Swift type name for the parameter.
/// - Returns: A valid Swift literal expression string.
public func synthesizeDummyParameterLiteral(param: Parameter, swiftType: String) -> String {
    let q = String(UnicodeScalar(34))
    if let ex = param.example ?? param.schema?.example ?? param.schema?.default_value,
       let str = ex.value as? String
    {
        return swiftType.hasPrefix("[") ? "[\(q)\(str)\(q)]" : "\(q)\(str)\(q)"
    }
    if let firstEnum = param.schema?.enum_values?.first?.value as? String {
        return swiftType.hasPrefix("[") ? "[\(q)\(firstEnum)\(q)]" : "\(q)\(firstEnum)\(q)"
    }
    if swiftType == "UUID" {
        return "UUID()"
    }
    if swiftType == "Date" {
        return "Date()"
    }
    if swiftType == "Data" {
        return "Data(\(q)test_data\(q).utf8)"
    }
    if swiftType == "Int" || swiftType == "Int64" || swiftType == "Int32" {
        return "1"
    }
    if swiftType == "Bool" {
        return "true"
    }
    if swiftType == "Double" || swiftType == "Float" {
        return "1.0"
    }
    if swiftType == "[String]" {
        return "[\(q)available\(q)]"
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
        let name = lastPathSegment(ref)
        if context.visited.contains(name) {
            return "{}"
        }
        if let s = context.schemas?[name] {
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
        return "{}"
    }

    if let firstEnum = context.enumValues?.first?.value as? String {
        return "\(q)\(firstEnum)\(q)"
    }

    let t = context.type ?? "object"
    switch t {
    case "string":
        if context.format == "uuid" {
            return "\(q)00000000-0000-0000-0000-000000000000\(q)"
        }
        if context.format == "date-time" {
            return "\(q)2026-01-01T00:00:00Z\(q)"
        }
        return "\(q)test_string\(q)"
    case "integer", "number":
        return "1"
    case "boolean":
        return "true"
    case "array":
        if let items = context.items {
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
        } else {
            return "[]"
        }
    case "object":
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
        let dictStr = dict.joined(separator: ", ")
        return "{\(dictStr)}"
    default:
        return "{}"
    }
}

/// Emits XCTest cases based on the OpenAPI Spec.
///
/// - Parameters:
///   - paths: Optional map of endpoint paths to `PathItem` definitions.
///   - document: Optional full `OpenAPIDocument` providing component schemas and security schemes.
/// - Returns: Generated `APIClientTests` Swift source code.
public func emitTests(paths: [String: PathItem]?, document: OpenAPIDocument? = nil) -> String {
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

    let schemas = document?.components?.schemas ?? document?.definitions

    if let paths = paths {
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            for (httpMethod, op) in item.operationsByMethod {
                let method = httpMethod.rawValue.uppercased()
                let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"

                var hasBodyParam = false
                var bodyParamName = ""
                var bodyType = ""
                var bodySchema: Schema?

                if let reqBody = op.requestBody, let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                    hasBodyParam = true
                    bodyParamName = "body"
                    bodyType = mapType(schema: schema)
                    bodySchema = schema
                } else if let formContent = op.requestBody?.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                    hasBodyParam = true
                    bodyParamName = "formData"
                    bodyType = mapType(schema: schema)
                    bodySchema = schema
                } else if let multiContent = op.requestBody?.content?["multipart/form-data"], let schema = multiContent.schema {
                    hasBodyParam = true
                    bodyParamName = "multipartData"
                    bodyType = mapType(schema: schema)
                    bodySchema = schema
                } else if let octetContent = op.requestBody?.content?["application/octet-stream"], let schema = octetContent.schema {
                    hasBodyParam = true
                    bodyParamName = "fileData"
                    bodyType = "Data"
                    bodySchema = schema
                } else if let globalParams = op.parameters {
                    for param in globalParams {
                        if param.in == "body", let schema = param.schema {
                            hasBodyParam = true
                            bodyParamName = param.name ?? "body"
                            bodyType = mapType(schema: schema)
                            bodySchema = schema
                            break
                        }
                    }
                }

                var callArgs: [String] = []

                if let params = op.parameters {
                    for param in params {
                        if param.in == "body" {
                            continue
                        }
                        let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                        let safePName = pName.replacingOccurrences(of: "-", with: "_")
                        let type = param.schema.map { mapType(schema: $0) } ?? "String"
                        let isRequired = param.required ?? false
                        let pIn = param.in ?? "query"
                        let dummyValue = synthesizeDummyParameterLiteral(param: param, swiftType: type)

                        if isRequired || pIn == "formData" || pIn == "header" || param.schema?.enum_values != nil || param.example != nil {
                            callArgs.append("\(safePName): \(dummyValue)")
                        }
                    }
                }

                if hasBodyParam {
                    let isRequired = op.requestBody?.required ?? true
                    if isRequired || bodyType == "Data" {
                        if bodyType == "String" {
                            callArgs.append("\(bodyParamName): \"test_string\"")
                        } else if bodyType == "Data" {
                            callArgs.append("\(bodyParamName): Data(\"test_data\".utf8)")
                        } else {
                            let jsonStr = generateDummyJSON(
                                context: DummyJSONContext(
                                    type: bodySchema?.type,
                                    format: bodySchema?.format,
                                    ref: bodySchema?.ref,
                                    properties: bodySchema?.properties,
                                    required: bodySchema?.required,
                                    items: bodySchema?.items,
                                    enumValues: bodySchema?.enum_values,
                                    exampleOrDefault: bodySchema?.example ?? bodySchema?.default_value,
                                    schemas: schemas
                                )
                            )
                            let escapedJson = jsonStr.replacingOccurrences(of: "\"", with: "\\\"")
                            callArgs.append("\(bodyParamName): try JSONDecoder().decode(\(bodyType).self, from: Data(\"\(escapedJson)\".utf8))")
                        }
                    }
                }

                let callArgsString = callArgs.joined(separator: ", ")

                var testPrefix = "00"
                switch method.uppercased() {
                case "POST": testPrefix = "01_POST_"
                case "PUT": testPrefix = "02_PUT_"
                case "PATCH": testPrefix = "03_PATCH_"
                case "GET": testPrefix = "04_GET_"
                case "DELETE": testPrefix = "99_DELETE_"
                default: testPrefix = "50_"
                }

                let testName = "test\(testPrefix)\(funcName.prefix(1).uppercased())\(funcName.dropFirst())"
                output += "    public func \(testName)() async throws {\n"
                output += "        XCTAssertNotNil(client)\n"
                output += "        do {\n"
                output += "            let _ = try await client?.\(funcName)(\(callArgsString))\n"
                output += "        } catch {\n"
                output += "            // Ignore server errors for dummy data\n"
                output += "        }\n"

                output += "    }\n"
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
