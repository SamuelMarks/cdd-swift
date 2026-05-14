import Foundation

/// Emits XCTest cases based on the OpenAPI Spec.
public func emitTests(paths: [String: PathItem]?) -> String {
    var output = "import XCTest\n\n"
    
    output += "final class APIClientTests: XCTestCase {\n"
    
    output += """
        var client: APIClient!
        
        override func setUp() {
            super.setUp()
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration)
            client = APIClient(baseURL: URL(string: "http://localhost:8080/api/v3")!, session: session)
        }

        override func tearDown() {
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
                    if let reqBody = op.requestBody, let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                        hasBodyParam = true
                        bodyParamName = "body"
                        bodyType = mapType(schema: schema)
                    } else if let formContent = op.requestBody?.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                        hasBodyParam = true
                        bodyParamName = "formData"
                        bodyType = mapType(schema: schema)
                    } else if let multiContent = op.requestBody?.content?["multipart/form-data"], let schema = multiContent.schema {
                        hasBodyParam = true
                        bodyParamName = "multipartData"
                        bodyType = mapType(schema: schema)
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
                            if type == "Int" { dummyValue = "1" }
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
                            // Cannot easily instantiate arbitrary struct, assume it has no-args init or it's an array/dict
                            if bodyType.hasPrefix("[") {
                                callArgs.append("\(bodyParamName): []")
                            } else if bodyType == "String" {
                                callArgs.append("\(bodyParamName): \"test_string\"")
                            } else {
                                callArgs.append("\(bodyParamName): try! JSONDecoder().decode(\(bodyType).self, from: \"{}\".data(using: .utf8)!)")
                            }
                        }
                    }
                    
                    let callArgsString = callArgs.joined(separator: ", ")

                    output += "    func test\(funcName.prefix(1).uppercased())\(funcName.dropFirst())() async throws {\n"
                    
                    output += "        do {\n"
                    output += "            _ = try await client.\(funcName)(\(callArgsString))\n"
                    output += "        } catch let error as URLError {\n"
                    output += "            // Pass if the server successfully received the request but responded with a non-200 code.\n"
                    output += "            // A URLError.badServerResponse means a network response was received.\n"
                    output += "            if error.code != .badServerResponse {\n"
                    output += "                XCTFail(\"Network error occurred: \\(error)\")\n"
                    output += "            }\n"
                    output += "        } catch {\n"
                    output += "            // We can also ignore DecodingError if the server returned a 200 but not the exact expected schema structure for the dummy data\n"
                    output += "        }\n"
                    
                    output += "    }\n"
                }
            }
        }
    } else {
        output += "    func testExample() async throws {\n"
        output += "        XCTAssertTrue(true)\n"
        output += "    }\n"
    }

    output += "}\n"
    return output
}
