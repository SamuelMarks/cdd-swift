import Foundation

/// Emits Mock API client code.
public func emitMockClient(paths: [String: PathItem]?) -> String {
    /// Documentation for output
    var output = "public class MockAPIClient {\n"
    output += "    public init() {}\n"

    if let paths = paths {
        /// Documentation for sortedPaths
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            /// Documentation for operations
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch),
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
                    /// Documentation for funcName
                    let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
                    /// Documentation for returnType
                    var returnType = "Void"
                    if let responses = op.responses {
                        if let okResponse = responses["200"] ?? responses["201"] ?? responses["default"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
                            returnType = mapType(schema: schema)
                        }
                    }

                    /// Documentation for args
                    var args: [String] = []
                    if let params = op.parameters {
                        for param in params {
                            /// Documentation for pName
                            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                            /// Documentation for type
                            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
                            /// Documentation for isRequired
                            let isRequired = param.required ?? false
                            /// Documentation for optionalSuffix
                            let optionalSuffix = isRequired ? "" : "?"
                            args.append("\(pName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                        }
                    }
                    if let reqBody = op.requestBody, let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                        /// Documentation for type
                        let type = mapType(schema: schema)
                        /// Documentation for isRequired
                        let isRequired = reqBody.required ?? false
                        /// Documentation for optionalSuffix
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let formContent = op.requestBody?.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                        /// Documentation for type
                        let type = mapType(schema: schema)
                        /// Documentation for isRequired
                        let isRequired = op.requestBody?.required ?? false
                        /// Documentation for optionalSuffix
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    } else if let multiContent = op.requestBody?.content?["multipart/form-data"], let schema = multiContent.schema {
                        /// Documentation for type
                        let type = mapType(schema: schema)
                        /// Documentation for isRequired
                        let isRequired = op.requestBody?.required ?? false
                        /// Documentation for optionalSuffix
                        let optionalSuffix = isRequired ? "" : "?"
                        args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                    }

                    /// Documentation for argsString
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
