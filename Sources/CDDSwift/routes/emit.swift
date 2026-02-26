import Foundation

/// Emits Swift methods for an API Client from OpenAPI paths.
public func emitMethod(path: String, method: String, operation: Operation, documentSecurity: [SecurityRequirement]?, securitySchemes: [String: SecurityScheme]) -> String {
    let funcName = operation.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: \"/\", with: \"_\").replacingOccurrences(of: \"{\", with: \"\").replacingOccurrences(of: \"}\", with: \"\"))"
    
    var args: [String] = []
    var pathInterpolation = path
    
    struct ParamData {
        let name: String
        let inLoc: String
        let style: String
        let explode: Bool
        let isArray: Bool
        let isObject: Bool
    }
    
    var queryParams: [ParamData] = []
    var headerParams: [String] = []
    
    if let params = operation.parameters {
        for param in params {
            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            let pIn = param.in ?? "query"
            let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
            let isRequired = param.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            args.append("\(pName): \(type)\(optionalSuffix)\(isRequired ? \"\" : \" = nil\")")
            
            let style = param.style ?? (pIn == "query" || pIn == "cookie" ? "form" : "simple")
            let explode = param.explode ?? (style == "form")
            let isArray = param.schema?.type == "array"
            let isObject = param.schema?.type == "object"
            
            if pIn == "path" {
                if style == "simple" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? \"\" : \"?\").map { String(describing: $0) }.joined(separator: \",\") \(isRequired ? \"\" : \"?? \\\"\\\"\"))")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName))")
                    }
                } else if style == "label" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? \"\" : \"?\").isEmpty == false ? \".\" + \(pName)\(isRequired ? \"\" : \"?!\").map { String(describing: $0) }.joined(separator: \"\(explode ? \".\" : \",\)\") : \"\")")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: ".\\(\(pName))")
                    }
                } else if style == "matrix" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName)\(isRequired ? \"\" : \"?\").isEmpty == false ? \";\(pName)=\" + \(pName)\(isRequired ? \"\" : \"?!\").map { String(describing: $0) }.joined(separator: \"\(explode ? \";\(pName)=\" : \",\)\") : \"\")")
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
    
    var bodyParamName = ""
    var isMultipart = false
    var isFormUrlEncoded = false
    var multipartEncodings: [String: EncodingObject]? = nil
    
    if let reqBody = operation.requestBody {
        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
            let type = mapType(schema: schema)
            let isRequired = reqBody.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "body"
            args.append("body: \(type)\(optionalSuffix)\(isRequired ? \"\" : \" = nil\")")
        } else if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
            let type = mapType(schema: schema)
            let isRequired = reqBody.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "formData"
            isFormUrlEncoded = true
            multipartEncodings = formContent.encoding
            args.append("formData: \(type)\(optionalSuffix)\(isRequired ? \"\" : \" = nil\")")
        } else if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
            let type = mapType(schema: schema)
            let isRequired = reqBody.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "multipartData"
            isMultipart = true
            multipartEncodings = multiContent.encoding
            args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? \"\" : \" = nil\")")
        }
    }
    
    var returnType = "Void"
    if let responses = operation.responses {
        if let okResponse = responses["200"] ?? responses["201"] ?? responses["default"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
            returnType = mapType(schema: schema)
        }
    }
    
    let argsString = args.joined(separator: ", ")
    
    var output = ""
    if let summary = operation.summary {
        output += "    /// \(summary)\n"
    }
    if let desc = operation.description {
        output += "    /// \(desc.replacingOccurrences(of: \"\n\", with: \"\n    /// \"))\n"
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
    let requirements = operation.security ?? documentSecurity ?? []
    if !requirements.isEmpty {
        for req in requirements {
            // we process the first valid requirement mapping
            for (key, _) in req {
                if let scheme = securitySchemes[key] {
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    if scheme.type == "http" && scheme.scheme?.lowercased() == "bearer" {
                        output += "        if let token = \(propName) {\n"
                        output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
                        output += "        }\n"
                    } else if scheme.type == "apiKey" {
                        let location = scheme.in ?? "header"
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
            output += "            let unreserved = CharacterSet(charactersIn: \\\"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~\\\")\n"
            output += "            for (key, value) in dict {\n"
            output += "                let valueStr = String(describing: value)\n"
            output += "                if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \\\" \\\", with: \\\"+\\\"),\n"
            output += "                   let encodedVal = valueStr.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \\\" \\\", with: \\\"+\\\") {\n"
            output += "                    formComponents.append(\\\"\\\\(encodedKey)=\\\\(encodedVal)\\\")\n"
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
            output += "             bodyData.append("--\\(boundary)--\\r\\n\".data(using: .utf8)!)\n"
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
    var output = ""
    let protocolName = "\(operationId.prefix(1).uppercased())\(operationId.dropFirst())Callbacks"
    output += "/// Callbacks for \(operationId)\n"
    output += "public protocol \(protocolName) {\n"
    
    let sortedCallbacks = callbacks.sorted { $0.key < $1.key }
    for (callbackName, callbackDict) in sortedCallbacks {
        for (expression, pathItem) in callbackDict {
            let methods: [(String, Operation?)] = [
                ("GET", pathItem.get), ("POST", pathItem.post), ("PUT", pathItem.put),
                ("DELETE", pathItem.delete), ("PATCH", pathItem.patch)
            ]
            for (method, opOpt) in methods {
                if let op = opOpt {
                    let funcName = op.operationId ?? "on\(callbackName.prefix(1).uppercased())\(callbackName.dropFirst())"
                    var args: [String] = []
                    if let reqBody = op.requestBody {
                        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                            let type = mapType(schema: schema)
                            let isRequired = reqBody.required ?? false
                            let optionalSuffix = isRequired ? "" : "?"
                            args.append("payload: \(type)\(optionalSuffix)")
                        }
                    }
                    let argsString = args.joined(separator: ", ")
                    output += "    func \(funcName)(\(argsString)) async throws\n"
                }
            }
        }
    }
    output += "}\n"
    return output
}
