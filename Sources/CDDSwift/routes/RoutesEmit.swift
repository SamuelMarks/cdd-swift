import Foundation

/// Emits Swift methods for an API Client from OpenAPI paths.
public func emitMethod(path: String, method: String, operation: Operation, documentSecurity: [SecurityRequirement]?, securitySchemes: [String: SecurityScheme]) -> String {
    /// Documentation for funcName
    let funcName = operation.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"

    /// Documentation for args
    var args: [String] = []
    /// Documentation for pathInterpolation
    var pathInterpolation = path

    /// Documentation for ParamData
    struct ParamData {
        /// Documentation for name
        let name: String
        /// Documentation for inLoc
        let inLoc: String
        /// Documentation for style
        let style: String
        /// Documentation for explode
        let explode: Bool
        /// Documentation for isArray
        let isArray: Bool
        /// Documentation for isObject
        let isObject: Bool
    }

    /// Documentation for queryParams
    var queryParams: [ParamData] = []
    /// Documentation for headerParams
    var headerParams: [String] = []

    if let params = operation.parameters {
        for param in params {
            /// Documentation for pName
            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            /// Documentation for pIn
            let pIn = param.in ?? "query"
            /// Documentation for type
            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
            /// Documentation for isRequired
            let isRequired = param.required ?? false
            /// Documentation for optionalSuffix
            let optionalSuffix = isRequired ? "" : "?"
            args.append("\(pName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")

            /// Documentation for style
            let style = param.style ?? (pIn == "query" || pIn == "cookie" ? "form" : "simple")
            /// Documentation for explode
            let explode = param.explode ?? (style == "form")
            /// Documentation for isArray
            let isArray = param.schema?.type == "array"
            /// Documentation for isObject
            let isObject = param.schema?.type == "object"

            if pIn == "path" {
                if style == "simple" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? "" : "?").map { String(describing: $0) }.joined(separator: \",\") \(isRequired ? "" : "?? \\\"\\\""))")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName))")
                    }
                } else if style == "label" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? "" : "?").isEmpty == false ? \".\" + \(pName)\(isRequired ? "" : "?!").map { String(describing: $0) }.joined(separator: \"\(explode ? "." : ",")\") : \"\")")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: ".\\(\(pName))")
                    }
                } else if style == "matrix" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? "" : "?").isEmpty == false ? \";\(pName)=\" + \(pName)\(isRequired ? "" : "?!").map { String(describing: $0) }.joined(separator: \"\(explode ? ";\(pName)=" : ",")\") : \"\")")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: ";\(pName)=\\(\(pName))")
                    }
                } else {
                    pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName))")
                }
            } else if pIn == "query" {
                queryParams.append(ParamData(name: pName, inLoc: pIn, style: style, explode: explode, isArray: isArray, isObject: isObject))
            } else if pIn == "header" {
                headerParams.append(pName)
            }
        }
    }

    /// Documentation for bodyParamName
    var bodyParamName = ""
    /// Documentation for isMultipart
    var isMultipart = false
    /// Documentation for isFormUrlEncoded
    var isFormUrlEncoded = false
    /// Documentation for multipartEncodings
    var multipartEncodings: [String: EncodingObject]? = nil

    if let reqBody = operation.requestBody {
        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
            /// Documentation for type
            let type = mapType(schema: schema)
            /// Documentation for isRequired
            let isRequired = reqBody.required ?? false
            /// Documentation for optionalSuffix
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "body"
            args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        } else if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
            /// Documentation for type
            let type = mapType(schema: schema)
            /// Documentation for isRequired
            let isRequired = reqBody.required ?? false
            /// Documentation for optionalSuffix
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "formData"
            isFormUrlEncoded = true
            multipartEncodings = formContent.encoding
            args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        } else if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
            /// Documentation for type
            let type = mapType(schema: schema)
            /// Documentation for isRequired
            let isRequired = reqBody.required ?? false
            /// Documentation for optionalSuffix
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "multipartData"
            isMultipart = true
            multipartEncodings = multiContent.encoding
            args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        }
    }

    /// Documentation for returnType
    var returnType = "Void"
    if let responses = operation.responses {
        if let okResponse = responses["200"] ?? responses["201"] ?? responses["default"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
            returnType = mapType(schema: schema)
        }
    }

    /// Documentation for argsString
    let argsString = args.joined(separator: ", ")

    /// Documentation for output
    var output = ""
    if let summary = operation.summary {
        output += "    /// \(summary)\n"
    }
    if let desc = operation.description {
        output += "    /// \(desc.replacingOccurrences(of: "\n", with: "\n    /// "))\n"
    }
    output += "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"

    if queryParams.isEmpty {
        output += "        let url = baseURL.appendingPathComponent(\"\\(String(format: \\\"\(pathInterpolation)\\\"))\")\n"
        output += "        var request = URLRequest(url: url)\n"
    } else {
        output += "        var components = URLComponents(url: baseURL.appendingPathComponent(\"\\(String(format: \\\"\(pathInterpolation)\\\"))\"), resolvingAgainstBaseURL: true)!\n"
        output += "        var queryItems: [URLQueryItem] = []\n"
        for qp in queryParams {
            output += "        if let val = \(qp.name) {\n"
            if qp.isArray {
                if qp.style == "form" && qp.explode {
                    output += "            for item in val { queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: item))) }\n"
                } else if qp.style == "form" && !qp.explode {
                    output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: val.map { String(describing: $0) }.joined(separator: \",\")))\n"
                } else if qp.style == "spaceDelimited" {
                    output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: val.map { String(describing: $0) }.joined(separator: \" \")))\n"
                } else if qp.style == "pipeDelimited" {
                    output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: val.map { String(describing: $0) }.joined(separator: \"|\")))\n"
                } else {
                    output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: val)))\n"
                }
            } else if qp.isObject {
                if qp.style == "deepObject" {
                    output += "            if let dict = val as? [String: Any] {\n"
                    output += "                for (k, v) in dict { queryItems.append(URLQueryItem(name: \"\(qp.name)[\\(k)]\", value: String(describing: v))) }\n"
                    output += "            }\n"
                } else {
                    output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: val)))\n"
                }
            } else {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: val)))\n"
            }
            output += "        }\n"
        }
        output += "        components.queryItems = queryItems.isEmpty ? nil : queryItems\n"
        output += "        if let encodedQuery = components.percentEncodedQuery {\n"
        output += "            components.percentEncodedQuery = encodedQuery.replacingOccurrences(of: \"+\", with: \"%2B\")\n"
        output += "        }\n"
        output += "        var request = URLRequest(url: components.url!)\n"
    }

    output += "        request.httpMethod = \"\(method)\"\n"

    for hParam in headerParams {
        output += "        if let val = \(hParam) {\n"
        output += "            request.setValue(String(describing: val), forHTTPHeaderField: \"\(hParam)\")\n"
        output += "        }\n"
    }

    // Evaluate Security Requirements
    /// Documentation for requirements
    let requirements = operation.security ?? documentSecurity ?? []
    if !requirements.isEmpty {
        for req in requirements {
            // we process the first valid requirement mapping
            for (key, _) in req {
                if let scheme = securitySchemes[key] {
                    /// Documentation for propName
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    if scheme.type == "http" && scheme.scheme?.lowercased() == "bearer" {
                        output += "        if let token = \(propName) {\n"
                        output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
                        output += "        }\n"
                    } else if scheme.type == "apiKey" {
                        /// Documentation for location
                        let location = scheme.in ?? "header"
                        /// Documentation for name
                        let name = scheme.name ?? key
                        if location == "header" {
                            output += "        if let token = \(propName) {\n"
                            output += "            request.setValue(\"\\(token)\", forHTTPHeaderField: \"\(name)\")\n"
                            output += "        }\n"
                        } else if location == "query" {
                            // Handled at query builder theoretically, but appending here dynamically if possible or assumed available
                            output += "        // Note: apiKey in query is recommended to be appended to components before creating URL.\n"
                        }
                    } else if scheme.type == "oauth2" || scheme.type == "openIdConnect" {
                        output += "        if let token = \(propName) {\n"
                        output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
                        output += "        }\n"
                    }
                }
            }
        }
    }

    if !bodyParamName.isEmpty {
        if isFormUrlEncoded {
            output += "        request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")\n"
            output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
            output += "            var formComponents: [String] = []\n"
            output += "            let unreserved = CharacterSet(charactersIn: \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~\")\n"
            output += "            for (key, value) in dict {\n"
            output += "                let valueStr = String(describing: value)\n"
            output += "                if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \" \", with: \"+\"),\n"
            output += "                   let encodedVal = valueStr.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \" \", with: \"+\") {\n"
            output += "                    formComponents.append(\"\\(encodedKey)=\\(encodedVal)\")\n"
            output += "                }\n"
            output += "            }\n"
            output += "            let formString = formComponents.joined(separator: \"&\")\n"
            output += "            request.httpBody = formString.data(using: .utf8)\n"
            output += "        }\n"
        } else if isMultipart {
            output += "        let boundary = UUID().uuidString\n"
            output += "        request.setValue(\"multipart/form-data; boundary=\\(boundary)\", forHTTPHeaderField: \"Content-Type\")\n"
            output += "        var bodyData = Data()\n"

            output += "        let multipartEncodingTypes: [String: String] = [\n"
            if let encodings = multipartEncodings {
                for (key, enc) in encodings {
                    if let cType = enc.contentType {
                        output += "            \"\(key)\": \"\(cType)\",\n"
                    }
                }
            }
            output += "        ]\n"

            output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
            output += "             for (key, value) in dict {\n"
            output += "                 var contentType = \"text/plain\"\n"
            output += "                 if value is [Any] || value is [String: Any] { contentType = \"application/json\" }\n"
            output += "                 if let overrideType = multipartEncodingTypes[key] { contentType = overrideType }\n"
            output += "                 bodyData.append(\"--\\(boundary)\\r\\n\".data(using: .utf8)!)\n"
            output += "                 bodyData.append(\"Content-Disposition: form-data; name=\\\"\\(key)\\\"\\r\\n\".data(using: .utf8)!)\n"
            output += "                 bodyData.append(\"Content-Type: \\(contentType)\\r\\n\\r\\n\".data(using: .utf8)!)\n"

            output += "                 if let stringVal = value as? String {\n"
            output += "                     bodyData.append(\"\\(stringVal)\\r\\n\".data(using: .utf8)!)\n"
            output += "                 } else if let innerData = try? JSONSerialization.data(withJSONObject: value) {\n"
            output += "                     bodyData.append(innerData)\n"
            output += "                     bodyData.append(\"\\r\\n\".data(using: .utf8)!)\n"
            output += "                 } else {\n"
            output += "                     bodyData.append(\"\\(value)\\r\\n\".data(using: .utf8)!)\n"
            output += "                 }\n"
            output += "             }\n"
            output += "             bodyData.append(\"--\\(boundary)--\\r\\n\".data(using: .utf8)!)\n"
            output += "        }\n"
            output += "        request.httpBody = bodyData\n"
        } else {
            output += "        request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n"
            output += "        if let body = \(bodyParamName) {\n"
            output += "            request.httpBody = try JSONEncoder().encode(body)\n"
            output += "        }\n"
        }
    }

    output += "        let (data, response) = try await session.data(for: request)\n"
    output += "        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {\n"
    output += "            throw URLError(.badServerResponse)\n"
    output += "        }\n"

    if returnType != "Void" {
        output += "        return try JSONDecoder().decode(\(returnType).self, from: data)\n"
    }

    output += "    }\n\n"
    return output
}

/// Emits delegate protocols for OpenAPI callbacks.
public func emitCallbacks(operationId: String, callbacks: [String: Callback]?) -> String {
    guard let callbacks = callbacks, !callbacks.isEmpty else { return "" }
    /// Documentation for output
    var output = ""
    /// Documentation for protocolName
    let protocolName = "\(operationId.prefix(1).uppercased())\(operationId.dropFirst())Callbacks"
    output += "/// Callbacks for \(operationId)\n"
    output += "public protocol \(protocolName) {\n"

    /// Documentation for sortedCallbacks
    let sortedCallbacks = callbacks.sorted { $0.key < $1.key }
    for (callbackName, callbackDict) in sortedCallbacks {
        for (_, pathItem) in callbackDict {
            /// Documentation for methods
            let methods: [(String, Operation?)] = [
                ("GET", pathItem.get), ("POST", pathItem.post), ("PUT", pathItem.put),
                ("DELETE", pathItem.delete), ("PATCH", pathItem.patch),
            ]
            for (_, opOpt) in methods {
                if let op = opOpt {
                    /// Documentation for funcName
                    let funcName = op.operationId ?? "on\(callbackName.prefix(1).uppercased())\(callbackName.dropFirst())"
                    /// Documentation for args
                    var args: [String] = []
                    if let reqBody = op.requestBody {
                        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                            /// Documentation for type
                            let type = mapType(schema: schema)
                            /// Documentation for isRequired
                            let isRequired = reqBody.required ?? false
                            /// Documentation for optionalSuffix
                            let optionalSuffix = isRequired ? "" : "?"
                            args.append("payload: \(type)\(optionalSuffix)")
                        }
                    }
                    /// Documentation for argsString
                    let argsString = args.joined(separator: ", ")
                    output += "    func \(funcName)(\(argsString)) async throws\n"
                }
            }
        }
    }
    output += "}\n"
    return output
}
