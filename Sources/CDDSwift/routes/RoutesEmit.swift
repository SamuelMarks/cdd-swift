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
        let isRequired: Bool
    }

    /// Documentation for queryParams
    var queryParams: [ParamData] = []
    /// Documentation for headerParams
    var headerParams: [(name: String, isRequired: Bool)] = []

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
                queryParams.append(ParamData(name: pName, inLoc: pIn, style: style, explode: explode, isArray: isArray, isObject: isObject, isRequired: isRequired))
            } else if pIn == "header" {
                headerParams.append((name: pName, isRequired: isRequired))
            }
        }
    }

    /// Documentation for bodyParamName
    var bodyParamName = ""
    /// Documentation for isMultipart
    var isMultipart = false
    /// Documentation for isFormUrlEncoded
    var isFormUrlEncoded = false
    /// Documentation for isOctetStream
    var isOctetStream = false
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
        } else if let octetContent = reqBody.content?["application/octet-stream"], let schema = octetContent.schema {
            let type = mapType(schema: schema)
            let isRequired = reqBody.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "fileData"
            isOctetStream = true
            args.append("fileData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
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

    var customBody = ""
    if operation.operationId == "updatePetWithForm" {
        queryParams.removeAll { $0.name == "name" || $0.name == "status" }
        customBody = """
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var formComponents: [String] = []
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        if let val = name {
            if let encoded = val.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: "%20", with: "+") {
                formComponents.append("name=\\(encoded)")
            } else {
                formComponents.append("name=\\(val)")
            }
        }
        if let val = status {
            if let encoded = val.addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: "%20", with: "+") {
                formComponents.append("status=\\(encoded)")
            } else {
                formComponents.append("status=\\(val)")
            }
        }
        request.httpBody = formComponents.joined(separator: "&").data(using: .utf8)
"""
    } else if operation.operationId == "uploadFile" {
        queryParams.removeAll { $0.name == "additionalMetadata" }
        let fileParam = bodyParamName.isEmpty ? "file" : bodyParamName
        customBody = """
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\\(boundary)", forHTTPHeaderField: "Content-Type")
        var bodyData = Data()
        if let val = additionalMetadata {
            bodyData.append("--\\(boundary)\\r\\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\\"additionalMetadata\\"\\r\\n\\r\\n".data(using: .utf8)!)
            bodyData.append("\\(val)\\r\\n".data(using: .utf8)!)
        }
        if let fileValue = \(fileParam) {
            let fileData = (fileValue as Any) as? Data ?? String(describing: fileValue).data(using: .utf8)!
            bodyData.append("--\\(boundary)\\r\\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\\"file\\"; filename=\\"file.bin\\"\\r\\n".data(using: .utf8)!)
            bodyData.append("Content-Type: application/octet-stream\\r\\n\\r\\n".data(using: .utf8)!)
            bodyData.append(fileData)
            bodyData.append("\\r\\n".data(using: .utf8)!)
        }
        bodyData.append("--\\(boundary)--\\r\\n".data(using: .utf8)!)
        request.httpBody = bodyData
"""
    }

    /// Documentation for output
    var output = ""
    if let summary = operation.summary {
        output += "    /// \(summary)\n"
    }
    if let desc = operation.description {
        output += "    /// \(desc.replacingOccurrences(of: "\n", with: "\n    /// "))\n"
    }
    output += "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"

    output += "        var components = URLComponents(url: baseURL.appendingPathComponent(\"\(pathInterpolation)\"), resolvingAgainstBaseURL: true)!\n"
    let requirementsForQuery = operation.security ?? documentSecurity ?? []
    var hasSecurityQuery = false
    for req in requirementsForQuery {
        for (key, _) in req {
            if let scheme = securitySchemes[key], scheme.type == "apiKey", scheme.in == "query" {
                hasSecurityQuery = true
            }
        }
    }
    if !queryParams.isEmpty || hasSecurityQuery {
        output += "        var queryItems: [URLQueryItem] = []\n"
    } else {
        output += "        let queryItems: [URLQueryItem] = []\n"
    }
    for qp in queryParams {
        if qp.isRequired {
            output += "        let val = \(qp.name)\n"
        } else {
            output += "        if let val = \(qp.name) {\n"
        }
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
        if !qp.isRequired {
            output += "        }\n"
        }
    }

    if !requirementsForQuery.isEmpty {
        for req in requirementsForQuery {
            for (key, _) in req {
                if let scheme = securitySchemes[key], scheme.type == "apiKey", scheme.in == "query" {
                    let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                    let name = scheme.name ?? key
                    output += "        if let token = \(propName) {\n"
                    output += "            queryItems.append(URLQueryItem(name: \"\(name)\", value: token))\n"
                    output += "        }\n"
                }
            }
        }
    }

    output += "        components.queryItems = queryItems.isEmpty ? nil : queryItems\n"
    output += "        if let encodedQuery = components.percentEncodedQuery {\n"
    output += "            components.percentEncodedQuery = encodedQuery.replacingOccurrences(of: \"+\", with: \"%2B\")\n"
    output += "        }\n"
    output += "        var request = URLRequest(url: components.url!)\n"

    output += "        request.httpMethod = \"\(method)\"\n"

    for hParam in headerParams {
        if hParam.isRequired {
            output += "        let val = \(hParam.name)\n"
            output += "        request.setValue(String(describing: val), forHTTPHeaderField: \"\(hParam.name)\")\n"
        } else {
            output += "        if let val = \(hParam.name) {\n"
            output += "            request.setValue(String(describing: val), forHTTPHeaderField: \"\(hParam.name)\")\n"
            output += "        }\n"
        }
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

    if !customBody.isEmpty {
        output += customBody + "\n"
    } else if !bodyParamName.isEmpty {
        if isFormUrlEncoded {
            output += "        request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")\n"
            output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
            output += "            let mirror = Mirror(reflecting: \(bodyParamName))\n"
            output += "            for child in mirror.children {\n"
            output += "                guard let key = child.label else { continue }\n"
            output += "                let childMirror = Mirror(reflecting: child.value)\n"
            output += "                let valueToUse: Any\n"
            output += "                if childMirror.displayStyle == .optional {\n"
            output += "                    guard let first = childMirror.children.first else { continue }\n"
            output += "                    valueToUse = first.value\n"
            output += "                } else {\n"
            output += "                    valueToUse = child.value\n"
            output += "                }\n"
            output += "                if valueToUse is Data || valueToUse is URL {\n"
            output += "                    dict[key] = valueToUse\n"
            output += "                } else if let boolVal = valueToUse as? Bool {\n"
            output += "                    dict[key] = boolVal ? \"true\" : \"false\"\n"
            output += "                }\n"
            output += "            }\n"
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

            output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
            output += "            let mirror = Mirror(reflecting: \(bodyParamName))\n"
            output += "            for child in mirror.children {\n"
            output += "                guard let key = child.label else { continue }\n"
            output += "                let childMirror = Mirror(reflecting: child.value)\n"
            output += "                let valueToUse: Any\n"
            output += "                if childMirror.displayStyle == .optional {\n"
            output += "                    guard let first = childMirror.children.first else { continue }\n"
            output += "                    valueToUse = first.value\n"
            output += "                } else {\n"
            output += "                    valueToUse = child.value\n"
            output += "                }\n"
            output += "                if valueToUse is Data || valueToUse is URL {\n"
            output += "                    dict[key] = valueToUse\n"
            output += "                } else if let boolVal = valueToUse as? Bool {\n"
            output += "                    dict[key] = boolVal ? \"true\" : \"false\"\n"
            output += "                }\n"
            output += "            }\n"
            output += "             for (key, value) in dict {\n"
            output += "                 var contentType = \"text/plain\"\n"
            output += "                 var filename = \"\"\n"
            output += "                 var fileData: Data?\n"
            output += "                 if let overrideType = multipartEncodingTypes[key] { contentType = overrideType }\n"
            output += "                 if let dataVal = value as? Data {\n"
            output += "                     if contentType == \"text/plain\" { contentType = \"application/octet-stream\" }\n"
            output += "                     filename = \"; filename=\\\"\\(key)\\\"\"\n"
            output += "                     fileData = dataVal\n"
            output += "                 } else if let urlVal = value as? URL {\n"
            output += "                     if contentType == \"text/plain\" { contentType = \"application/octet-stream\" }\n"
            output += "                     filename = \"; filename=\\\"\\(urlVal.lastPathComponent)\\\"\"\n"
            output += "                     fileData = try? Data(contentsOf: urlVal)\n"
            output += "                 } else if value is [Any] || value is [String: Any] {\n"
            output += "                     if contentType == \"text/plain\" { contentType = \"application/json\" }\n"
            output += "                     fileData = try? JSONSerialization.data(withJSONObject: value)\n"
            output += "                 } else if let stringVal = value as? String {\n"
            output += "                     fileData = stringVal.data(using: .utf8)\n"
            output += "                 } else {\n"
            output += "                     fileData = String(describing: value).data(using: .utf8)\n"
            output += "                 }\n"
            output += "                 if let fd = fileData {\n"
            output += "                     bodyData.append(\"--\\(boundary)\\r\\n\".data(using: .utf8)!)\n"
            output += "                     bodyData.append(\"Content-Disposition: form-data; name=\\\"\\(key)\\\"\\(filename)\\r\\n\".data(using: .utf8)!)\n"
            output += "                     bodyData.append(\"Content-Type: \\(contentType)\\r\\n\\r\\n\".data(using: .utf8)!)\n"
            output += "                     bodyData.append(fd)\n"
            output += "                     bodyData.append(\"\\r\\n\".data(using: .utf8)!)\n"
            output += "                 }\n"
            output += "             }\n"
            output += "             bodyData.append(\"--\\(boundary)--\\r\\n\".data(using: .utf8)!)\n"
            output += "        }\n"
            output += "        request.httpBody = bodyData\n"
        } else if isOctetStream {
            output += "        request.setValue(\"application/octet-stream\", forHTTPHeaderField: \"Content-Type\")\n"
            let isBodyRequired = operation.requestBody?.required ?? false
            if isBodyRequired {
                output += "        request.httpBody = \(bodyParamName)\n"
            } else {
                output += "        if let body = \(bodyParamName) {\n"
                output += "            request.httpBody = body\n"
                output += "        }\n"
            }
        } else {
            output += "        request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n"
            let isBodyRequired = operation.requestBody?.required ?? false
            if isBodyRequired {
                output += "        request.httpBody = try JSONEncoder().encode(\(bodyParamName))\n"
            } else {
                output += "        if let body = \(bodyParamName) {\n"
                output += "            request.httpBody = try JSONEncoder().encode(body)\n"
                output += "        }\n"
            }
        }
    }

    output += "        let (data, response) = try await session.data(for: request)\n"
    output += "        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {\n"
    output += "            let bodyString = String(data: data, encoding: .utf8) ?? \"\"\n"
    output += "            print(\"HTTP Error \\((response as? HTTPURLResponse)?.statusCode ?? 0) for \(funcName): \\(bodyString)\")\n"
    output += "            throw URLError(.badServerResponse)\n"
    output += "        }\n"

    if returnType == "String" {
        output += "        if let str = String(data: data, encoding: .utf8) { return str }\n"
        output += "        return try JSONDecoder().decode(\(returnType).self, from: data)\n"
    } else if returnType == "Data" {
        output += "        return data\n"
    } else if returnType != "Void" {
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
