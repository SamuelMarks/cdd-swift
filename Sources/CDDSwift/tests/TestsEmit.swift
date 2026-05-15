import Foundation

fileprivate func generateDummyJSON(type: String?, ref: String?, properties: [String: Schema]?, required: [String]?, items: SchemaItem?, components: Components?, visited: Set<String> = []) -> String {
    if let ref = ref {
        let name = ref.components(separatedBy: "/").last ?? ""
        if visited.contains(name) { return "{}" } // break cycle
        if let s = components?.schemas?[name] {
            var newVisited = visited
            newVisited.insert(name)
            return generateDummyJSON(type: s.type, ref: s.ref, properties: s.properties, required: s.required, items: s.items, components: components, visited: newVisited)
        }
        return "{}"
    }
    
    let t = type ?? "object"
    switch t {
    case "string":
        return "\"test_string\""
    case "integer", "number":
        return "1"
    case "boolean":
        return "true"
    case "array":
        if let items = items {
            let itemStr = generateDummyJSON(type: items.type, ref: items.ref, properties: nil, required: nil, items: nil, components: components, visited: visited)
            return "[\(itemStr)]"
        }
        return "[]"
    case "object":
        var dict: [String] = []
        let req = required ?? []
        for r in req {
            if let p = properties?[r] {
                let val = generateDummyJSON(type: p.type, ref: p.ref, properties: p.properties, required: p.required, items: p.items, components: components, visited: visited)
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
public func emitTests(paths: [String: PathItem]?, components: Components? = nil) -> String {
    var output = "import XCTest\n\n"
    
    output += "@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)\n"
    output += "open class APIClientTests: XCTestCase {\n"
    
    output += """
        public var client: APIClient!
        
        open override func setUp() {
            super.setUp()
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration)
            let baseURLStr = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8080/v2"
            client = APIClient(baseURL: URL(string: baseURLStr)!, session: session)
        }

        open override func tearDown() {
            super.tearDown()
        }

"""

    if let paths = paths {
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch),
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
                    let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
                    
                    var hasBodyParam = false
                    var bodyParamName = ""
                    var bodyType = ""
                    var bodySchema: Schema? = nil
                    
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
                    }

                    var callArgs: [String] = []
                    
                    // Generate mock params
                    if let params = op.parameters {
                        for param in params {
                            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
                            let isRequired = param.required ?? false
                            
                            // Try to provide a dummy value based on type
                            var dummyValue = "\"test_string\""
                            if pName == "status" && type == "String" { dummyValue = "\"available\"" }
                            else if pName == "status" { dummyValue = "[\"available\"]" }
                            else if type == "Int" || type == "Int64" || type == "Int32" { dummyValue = "1" }
                            else if type == "Bool" { dummyValue = "true" }
                            else if type == "Double" { dummyValue = "1.0" }
                            else if type.hasPrefix("[") { dummyValue = "[]" }
                            
                            if isRequired {
                                callArgs.append("\(pName): \(dummyValue)")
                            }
                        }
                    }
                    
                    // If body parameter is required, create a dummy
                    if hasBodyParam {
                        let isRequired = op.requestBody?.required ?? false
                        if isRequired {
                            if bodyType == "String" {
                                callArgs.append("\(bodyParamName): \"test_string\"")
                            } else {
                                let jsonStr = generateDummyJSON(type: bodySchema?.type, ref: bodySchema?.ref, properties: bodySchema?.properties, required: bodySchema?.required, items: bodySchema?.items, components: components)
                                let escapedJson = jsonStr.replacingOccurrences(of: "\"", with: "\\\"")
                                callArgs.append("\(bodyParamName): try! JSONDecoder().decode(\(bodyType).self, from: \"\(escapedJson)\".data(using: .utf8)!)")
                            }
                        }
                    }
                    
                    let callArgsString = callArgs.joined(separator: ", ")

                    output += "    public func test\(funcName.prefix(1).uppercased())\(funcName.dropFirst())() async throws {\n"
                    
                    output += "        let _ = try await client.\(funcName)(\(callArgsString))\n"
                    
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
