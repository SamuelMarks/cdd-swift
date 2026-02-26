import Foundation

/// Emits Mock API client code.
public func emitMockClient(paths: [String: PathItem]?) -> String {
    var output = "public class MockAPIClient {\n"
    output += "    public init() {}\n"
    
    if let paths = paths {
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch)
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
                    let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
                    var returnType = "Void"
                    if let responses = op.responses {
                        if let okResponse = responses["200"] ?? responses["201"] ?? responses["default"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
                            returnType = mapType(schema: schema)
                        }
                    }
                    
                    var args: [String] = []
                    if let params = op.parameters {
                        for param in params {
                            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
                            let isRequired = param.required ?? false
                            let optionalSuffix = isRequired ? "" : "?"
                            args.append("\(pName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                        }
                    }
                    if let reqBody = op.requestBody, let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                        let type = mapType(schema: schema)
                        let isRequired = reqBody.required ?? false
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let formContent = op.requestBody?.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                        let type = mapType(schema: schema)
                        let isRequired = op.requestBody?.required ?? false
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let multiContent = op.requestBody?.content?["multipart/form-data"], let schema = multiContent.schema {
                        let type = mapType(schema: schema)
                        let isRequired = op.requestBody?.required ?? false
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    }
                    
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
