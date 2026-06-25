import Foundation

/// Emits Mock API client code.
public func emitMockClient(paths: [String: PathItem]?) -> String {
    // Initialize the Mock API Client string.
    var output = "public class MockAPIClient {\n"
    output += "    public init() {}\n"

    if let paths = paths {
        // Sort paths alphabetically for consistent generation.
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            // Map HTTP methods to their corresponding Operation objects.
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch)
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
                    // Generate the mock function name, fallback to method + path if missing operationId.
                    let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
                    // Determine the expected return type from the operation's responses.
                    var returnType = "Void"
                    if let responses = op.responses {
                        if let okResponse = responses["200"] ?? responses["201"] ?? responses["default"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
                            returnType = mapType(schema: schema)
                        }
                    }

                    // Collect the arguments required for the mock function signature.
                    var args: [String] = []
                    if let params = op.parameters {
                        for param in params {
                            // The name of the parameter.
                            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                            let safePName = pName.replacingOccurrences(of: "-", with: "_")
                            // The mapped Swift type for the parameter.
                            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
                            // Whether the parameter is required.
                            let isRequired = param.required ?? false
                            // Suffix for optional parameters.
                            let optionalSuffix = isRequired ? "" : "?"
                            args.append("\(safePName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                        }
                    }
                    if let reqBody = op.requestBody, let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                        // The mapped Swift type for the payload.
                        let type = mapType(schema: schema)
                        // Whether the payload is required.
                        let isRequired = reqBody.required ?? false
                        // Suffix for optional payloads.
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let formContent = op.requestBody?.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                        // The mapped Swift type for the payload.
                        let type = mapType(schema: schema)
                        // Whether the payload is required.
                        let isRequired = op.requestBody?.required ?? false
                        // Suffix for optional payloads.
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let multiContent = op.requestBody?.content?["multipart/form-data"], let schema = multiContent.schema {
                        // The mapped Swift type for the payload.
                        let type = mapType(schema: schema)
                        // Whether the payload is required.
                        let isRequired = op.requestBody?.required ?? false
                        // Suffix for optional payloads.
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    }

                    // Join all arguments into a single string for the function signature.
                    let argsString = args.joined(separator: ", ")
                    output += "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"
                    if returnType != "Void" {
                        output += "        fatalError(\"Mock \(funcName) not implemented\")\n"
                    }
                    output += "    }\n"
                }
            }
        }
    }

    output += "}\n"
    return output
}
