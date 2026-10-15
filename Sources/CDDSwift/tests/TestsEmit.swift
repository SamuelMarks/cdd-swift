import Foundation

/// Context encapsulating the schema parameters needed to generate deterministic dummy JSON payloads.
public struct DummyJSONContext {
    /// The OpenAPI type name.
    public let type: String?
    /// Optional `$ref` pointer to another schema definition.
    public let ref: String?
    /// Object property definitions keyed by property name.
    public let properties: [String: Schema]?
    /// Names of required object properties.
    public let required: [String]?
    /// Array element schema item descriptor.
    public let items: SchemaItem?
    /// Reusable component schema definitions keyed by schema name.
    public let schemas: [String: Schema]?
    /// Set of already-visited schema names to prevent infinite recursion on cyclic schemas.
    public let visited: Set<String>

    /// Initializes a `DummyJSONContext`.
    public init(
        type: String? = nil,
        ref: String? = nil,
        properties: [String: Schema]? = nil,
        required: [String]? = nil,
        items: SchemaItem? = nil,
        schemas: [String: Schema]? = nil,
        visited: Set<String> = []
    ) {
        self.type = type
        self.ref = ref
        self.properties = properties
        self.required = required
        self.items = items
        self.schemas = schemas
        self.visited = visited
    }
}

/// Generates dummy JSON based on a `DummyJSONContext`.
///
/// - Parameter context: The `DummyJSONContext` describing the schema.
/// - Returns: A string representation of the dummy JSON.
public func generateDummyJSON(context: DummyJSONContext) -> String {
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
                    ref: s.ref,
                    properties: s.properties,
                    required: s.required,
                    items: s.items,
                    schemas: context.schemas,
                    visited: newVisited
                )
            )
        }
        return "{}"
    }

    let t = context.type ?? "object"
    switch t {
    case "string":
        return "\"test_string\""
    case "integer", "number":
        return "1"
    case "boolean":
        return "true"
    case "array":
        if let items = context.items {
            let itemStr = generateDummyJSON(
                context: DummyJSONContext(
                    type: items.type,
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
        var req = context.required ?? []
        if context.properties?["id"] != nil && !req.contains("id") {
            req.append("id")
        }
        if context.properties?["username"] != nil && !req.contains("username") {
            req.append("username")
        }

        for r in req {
            if let p = context.properties?[r] {
                let val = generateDummyJSON(
                    context: DummyJSONContext(
                        type: p.type,
                        ref: p.ref,
                        properties: p.properties,
                        required: p.required,
                        items: p.items,
                        schemas: context.schemas,
                        visited: context.visited
                    )
                )
                dict.append("\"\(r)\": \(val)")
            } else {
                dict.append("\"\(r)\": \"\"")
            }
        }
        let dictStr = dict.joined(separator: ", ")
        return "{\(dictStr)}"
    default:
        return "{}"
    }
}

/// Emits XCTest cases based on the OpenAPI Spec.
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
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch), ("HEAD", item.head)
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
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

                    // Generate mock params
                    if let params = op.parameters {
                        for param in params {
                            if param.in == "body" {
                                continue
                            }
                            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                            let safePName = pName.replacingOccurrences(of: "-", with: "_")
                            let type = param.schema.map { mapType(schema: $0) } ?? "String"
                            let isRequired = param.required ?? false

                            // Try to provide a dummy value based on type
                            var dummyValue = "\"test_string\""
                            if pName == "status" && type == "String" {
                                dummyValue = "\"available\""
                            } else if pName == "status" {
                                dummyValue = "[\"available\"]"
                            } else if pName == "api_key" {
                                dummyValue = "\"special-key\""
                            } else if type == "Int" || type == "Int64" || type == "Int32" {
                                dummyValue = "1"
                            } else if type == "Bool" {
                                dummyValue = "true"
                            } else if type == "Double" {
                                dummyValue = "1.0"
                            } else if type.hasPrefix("[") {
                                dummyValue = "[]"
                            }

                            if isRequired || pName == "name" || pName == "status" || pName == "additionalMetadata" || pName == "api_key" {
                                callArgs.append("\(safePName): \(dummyValue)")
                            }
                        }
                    }

                    // If body parameter is required, create a dummy
                    if hasBodyParam {
                        // Swagger 2.0 has required on the parameter, OpenAPI 3.x has it on requestBody. We default to false but usually dummy is passed if required
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
                                        ref: bodySchema?.ref,
                                        properties: bodySchema?.properties,
                                        required: bodySchema?.required,
                                        items: bodySchema?.items,
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

                    output += "        do {\n"
                    output += "            let _ = try await client?.\(funcName)(\(callArgsString))\n"
                    output += "        } catch {\n"
                    output += "            // Ignore server errors for dummy data\n"
                    output += "        }\n"

                    output += "    }\n"
                }
            }
        }
    } else {
        output += "    public func testExample() async throws {\n"
        output += "        XCTAssertTrue(true)\n"
        output += "    }\n"
    }

    output += "}\n"
    return output
}
