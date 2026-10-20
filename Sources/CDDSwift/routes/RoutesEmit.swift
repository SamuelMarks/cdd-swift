/// Swift API client method, parameter serializer, security injector, and callback delegate emitter for OpenAPI operations.
import Foundation

/// Describes a resolved OpenAPI operation parameter used during route method emission.
public struct RouteParamDescriptor: Sendable, Equatable {
    /// The raw OpenAPI parameter name.
    public let name: String
    /// The sanitized Swift identifier name for the parameter.
    public let swiftName: String
    /// The location of the parameter (`query`, `path`, `header`, `cookie`, `formData`, `body`).
    public let inLoc: String
    /// The serialization style (`form`, `simple`, `matrix`, `label`, `spaceDelimited`, `pipeDelimited`, `deepObject`).
    public let style: String
    /// Whether arrays and objects are exploded into separate key-value pairs.
    public let explode: Bool
    /// Indicates if the parameter schema is an array.
    public let isArray: Bool
    /// Indicates if the parameter schema is an object.
    public let isObject: Bool
    /// Indicates if the parameter schema is binary file data (`format: "binary"` or `type: "file"`).
    public let isBinary: Bool
    /// Indicates if the parameter is required.
    public let isRequired: Bool

    /// Initializes a `RouteParamDescriptor`.
    ///
    /// - Parameters:
    ///   - name: The raw OpenAPI parameter name.
    ///   - swiftName: The sanitized Swift variable name.
    ///   - inLoc: The parameter location (`query`, `path`, `header`, `cookie`, `formData`).
    ///   - style: The serialization style string.
    ///   - explode: Whether collection parameters explode.
    ///   - isArray: Whether the parameter is an array.
    ///   - isObject: Whether the parameter is an object.
    ///   - isBinary: Whether the parameter carries binary file data.
    ///   - isRequired: Whether the parameter is mandatory.
    public init(
        name: String,
        swiftName: String,
        inLoc: String,
        style: String,
        explode: Bool,
        isArray: Bool,
        isObject: Bool,
        isBinary: Bool = false,
        isRequired: Bool
    ) {
        self.name = name
        self.swiftName = swiftName
        self.inLoc = inLoc
        self.style = style
        self.explode = explode
        self.isArray = isArray
        self.isObject = isObject
        self.isBinary = isBinary
        self.isRequired = isRequired
    }
}

/// Infers the Swift return type for an `Operation` by inspecting its 2xx and `default` responses.
///
/// - Parameter responses: Optional map of HTTP status code strings to `Response` definitions.
/// - Returns: The mapped Swift return type string (defaults to `"Void"`).
public func inferOperationReturnType(responses: [String: Response]?) -> String {
    guard let responses = responses else { return "Void" }
    let twoXXKeys = responses.keys.filter { $0.hasPrefix("2") }.sorted()
    for code in twoXXKeys {
        if let resp = responses[code], let jsonMedia = resp.content?["application/json"], let schema = jsonMedia.schema {
            return mapType(schema: schema)
        }
    }
    if let defaultResp = responses["default"], let jsonMedia = defaultResp.content?["application/json"], let schema = jsonMedia.schema {
        return mapType(schema: schema)
    }
    return "Void"
}

/// Emits Swift methods for an API Client from OpenAPI paths.
///
/// - Parameters:
///   - path: The URL path template (e.g. `"/pets/{petId}"`).
///   - method: The uppercase HTTP method name (e.g. `"GET"`, `"POST"`).
///   - operation: The OpenAPI `Operation` descriptor.
///   - documentSecurity: Optional global security requirements from the root document.
///   - securitySchemes: Map of security scheme names to `SecurityScheme` definitions.
/// - Returns: Generated Swift `APIClient` method source code.
public func emitMethod(path: String, method: String, operation: Operation, documentSecurity: [SecurityRequirement]?, securitySchemes: [String: SecurityScheme]) -> String {
    // Generate the function name, using operationId if available, otherwise constructing it from method and path.
    let funcName = operation.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"

    // Initialize an array to collect function arguments.
    var args: [String] = []
    // Initialize the path interpolation string, to be modified with parameter variables.
    var pathInterpolation = path

    // Collect query parameters for URL composition.
    var queryParams: [RouteParamDescriptor] = []
    // Collect header parameters for request setup.
    var headerParams: [(name: String, isRequired: Bool)] = []
    // Collect Swagger 2.0 formData parameters.
    var formDataParams: [RouteParamDescriptor] = []

    if let params = operation.parameters {
        for param in params {
            // Extract the parameter name, falling back to ref or 'unknown'.
            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            let safePName = pName.replacingOccurrences(of: "-", with: "_")
            // Extract the parameter location, defaulting to 'query'.
            let pIn = param.in ?? "query"
            // Determine the mapped Swift type for the parameter.
            let type = param.schema.map { mapType(schema: $0) } ?? "String"
            // Determine if the parameter is required.
            let isRequired = param.required ?? false
            // Determine the optional suffix based on required status.
            let optionalSuffix = isRequired ? "" : "?"
            args.append("\(safePName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")

            // The style of the parameter (form, simple, matrix).
            let style = param.style ?? (pIn == "query" || pIn == "cookie" ? "form" : "simple")
            // Whether the parameter should explode (expand) arrays and objects.
            let explode = param.explode ?? (style == "form")
            // Indicates if the parameter schema is an array.
            let isArray = param.schema?.type == "array"
            // Indicates if the parameter schema is an object.
            let isObject = param.schema?.type == "object"

            if pIn == "path" {
                if style == "simple" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(safePName)\(isRequired ? "" : "?").map { String(describing: $0) }.joined(separator: \",\") \(isRequired ? "" : "?? \\\"\\\""))")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(safePName))")
                    }
                } else if style == "label" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(safePName)\(isRequired ? "" : "?").isEmpty == false ? \".\" + (\(safePName)\(isRequired ? "" : " ?? []")).map { String(describing: $0) }.joined(separator: \"\(explode ? "." : ",")\") : \"\")")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: ".\\(\(safePName))")
                    }
                } else if style == "matrix" {
                    if isArray {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(safePName)\(isRequired ? "" : "?").isEmpty == false ? \";\(pName)=\" + (\(safePName)\(isRequired ? "" : " ?? []")).map { String(describing: $0) }.joined(separator: \"\(explode ? ";\(pName)=" : ",")\") : \"\")")
                    } else {
                        pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: ";\(pName)=\\(\(safePName))")
                    }
                } else {
                    pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(safePName))")
                }
            } else if pIn == "query" {
                queryParams.append(RouteParamDescriptor(name: pName, swiftName: safePName, inLoc: pIn, style: style, explode: explode, isArray: isArray, isObject: isObject, isRequired: isRequired))
            } else if pIn == "header" {
                headerParams.append((name: pName, isRequired: isRequired))
            } else if pIn == "formData" {
                let isBin = param.schema?.format == "binary" || param.schema?.type == "file"
                formDataParams.append(RouteParamDescriptor(name: pName, swiftName: safePName, inLoc: pIn, style: style, explode: explode, isArray: isArray, isObject: isObject, isBinary: isBin, isRequired: isRequired))
            }
        }
    }

    // Track the name of the body parameter if one exists.
    var bodyParamName = ""
    // isMultipart
    var isMultipart = false
    // isFormUrlEncoded
    var isFormUrlEncoded = false
    // isOctetStream
    var isOctetStream = false
    // multipartEncodings
    var multipartEncodings: [String: EncodingObject]?

    if let reqBody = operation.requestBody {
        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
            // Determine the mapped Swift type for the parameter.
            let type = mapType(schema: schema)
            // Determine if the parameter is required.
            let isRequired = reqBody.required ?? false
            // Determine the optional suffix based on required status.
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "body"
            args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        } else if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
            // Determine the mapped Swift type for the parameter.
            let type = mapType(schema: schema)
            // Determine if the parameter is required.
            let isRequired = reqBody.required ?? false
            // Determine the optional suffix based on required status.
            let optionalSuffix = isRequired ? "" : "?"
            bodyParamName = "formData"
            isFormUrlEncoded = true
            multipartEncodings = formContent.encoding
            args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        } else if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
            // Determine the mapped Swift type for the parameter.
            let type = mapType(schema: schema)
            // Determine if the parameter is required.
            let isRequired = reqBody.required ?? false
            // Determine the optional suffix based on required status.
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
    } else if let params = operation.parameters {
        for param in params {
            if param.in == "body", param.schema != nil {
                let pName = param.name ?? "body"
                bodyParamName = pName
                break
            }
        }
    }

    // Determine the expected return type from the operation's 2xx responses.
    let returnType = inferOperationReturnType(responses: operation.responses)

    // Combine all arguments into a single string for the function signature.
    let argsString = args.joined(separator: ", ")

    var customBody = ""
    if !formDataParams.isEmpty {
        let q = String(UnicodeScalar(34))
        let bs = String(UnicodeScalar(92))
        let nl = String(UnicodeScalar(10))
        let hasBinary = isOctetStream || formDataParams.contains(where: { $0.isBinary })
        var lines: [String] = []
        if hasBinary {
            lines.append("        let boundary = UUID().uuidString")
            lines.append("        request.setValue(\(q)multipart/form-data; boundary=\(bs)(boundary)\(q), forHTTPHeaderField: \(q)Content-Type\(q))")
            lines.append("        var bodyData = Data()")
            for fp in formDataParams where !fp.isBinary {
                lines.append("        if let val = \(fp.swiftName) as Any? {")
                lines.append("            bodyData.append(Data(\(q)--\(bs)(boundary)\(bs)r\(bs)nContent-Disposition: form-data; name=\(bs)\(q)\(fp.name)\(bs)\(q)\(bs)r\(bs)n\(bs)r\(bs)n\(bs)(val)\(bs)r\(bs)n\(q).utf8))")
                lines.append("        }")
            }
            var fileVars = formDataParams.filter { $0.isBinary }.map { $0.swiftName }
            if !bodyParamName.isEmpty {
                fileVars.append(bodyParamName)
            }
            for fileVar in fileVars {
                lines.append("        if let fileValue = \(fileVar) as Any? {")
                lines.append("            let fileData = (fileValue as? Data) ?? Data(String(describing: fileValue).utf8)")
                lines.append("            bodyData.append(Data(\(q)--\(bs)(boundary)\(bs)r\(bs)nContent-Disposition: form-data; name=\(bs)\(q)file\(bs)\(q); filename=\(bs)\(q)file.bin\(bs)\(q)\(bs)r\(bs)nContent-Type: application/octet-stream\(bs)r\(bs)n\(bs)r\(bs)n\(q).utf8))")
                lines.append("            bodyData.append(fileData)")
                lines.append("            bodyData.append(Data(\(q)\(bs)r\(bs)n\(q).utf8))")
                lines.append("        }")
            }
            lines.append("        bodyData.append(Data(\(q)--\(bs)(boundary)--\(bs)r\(bs)n\(q).utf8))")
            lines.append("        request.httpBody = bodyData")
        } else {
            lines.append("        request.setValue(\(q)application/x-www-form-urlencoded\(q), forHTTPHeaderField: \(q)Content-Type\(q))")
            lines.append("        var formComponents: [String] = []")
            lines.append("        let unreserved = CharacterSet(charactersIn: \(q)abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~\(q))")
            for fp in formDataParams {
                if fp.isRequired {
                    lines.append("        if let encoded = String(describing: \(fp.swiftName)).addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \(q)%20\(q), with: \(q)+\(q)) {")
                    lines.append("            formComponents.append(\(q)\(fp.name)=\(bs)(encoded)\(q))")
                    lines.append("        }")
                } else {
                    lines.append("        if let val = \(fp.swiftName), let encoded = String(describing: val).addingPercentEncoding(withAllowedCharacters: unreserved)?.replacingOccurrences(of: \(q)%20\(q), with: \(q)+\(q)) {")
                    lines.append("            formComponents.append(\(q)\(fp.name)=\(bs)(encoded)\(q))")
                    lines.append("        }")
                }
            }
            lines.append("        request.httpBody = formComponents.joined(separator: \(q)&\(q)).data(using: String.Encoding.utf8)")
        }
        customBody = lines.joined(separator: nl)
    }

    // Initialize the output string for the generated method.
    var output = ""
    if let summary = operation.summary {
        output += "    /// \(summary)\n"
    }
    if let desc = operation.description {
        output += "    /// \(desc.replacingOccurrences(of: "\n", with: "\n    /// "))\n"
    }
    output += "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"

    output += "        guard var components = URLComponents(url: baseURL.appendingPathComponent(\"\(pathInterpolation)\"), resolvingAgainstBaseURL: true) else { throw URLError(.badURL) }\n"
    output += emitQueryAndSecuritySection(
        method: method,
        queryParams: queryParams,
        headerParams: headerParams,
        requirements: operation.security ?? documentSecurity ?? [],
        securitySchemes: securitySchemes
    )

    if !customBody.isEmpty {
        output += customBody + "\n"
    } else if !bodyParamName.isEmpty {
        output += emitStandardRequestBody(
            config: RequestBodyEmitConfig(
                bodyParamName: bodyParamName,
                isFormUrlEncoded: isFormUrlEncoded,
                isMultipart: isMultipart,
                isOctetStream: isOctetStream,
                multipartEncodings: multipartEncodings
            ),
            operation: operation
        )
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

/// Emits query parameter serialization, URLRequest creation, header injection, and security scheme injection.
///
/// - Parameters:
///   - method: The uppercase HTTP method name.
///   - queryParams: Array of query `RouteParamDescriptor` items.
///   - headerParams: Array of header `(name, isRequired)` tuples.
///   - requirements: Active `SecurityRequirement` array.
///   - securitySchemes: Map of defined `SecurityScheme` objects.
/// - Returns: Generated Swift source lines for query, header, and security setup.
private func emitQueryAndSecuritySection(
    method: String,
    queryParams: [RouteParamDescriptor],
    headerParams: [(name: String, isRequired: Bool)],
    requirements: [SecurityRequirement],
    securitySchemes: [String: SecurityScheme]
) -> String {
    var output = ""
    var hasSecurityQuery = false
    for req in requirements {
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
        let swiftParamName = qp.name.replacingOccurrences(of: "-", with: "_")
        let safeName = qp.name.replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "-", with: "_")
        let valName = "val_\(safeName)"
        if qp.isRequired {
            output += "        let \(valName) = \(swiftParamName)\n"
        } else {
            output += "        if let \(valName) = \(swiftParamName) {\n"
        }
        if qp.isArray {
            if qp.style == "form" && qp.explode {
                output += "            for item in \(valName) { queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: item))) }\n"
            } else if qp.style == "form" && !qp.explode {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \",\")))\n"
            } else if qp.style == "spaceDelimited" {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \" \")))\n"
            } else if qp.style == "pipeDelimited" {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \"|\")))\n"
            } else {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: \(valName))))\n"
            }
        } else if qp.isObject {
            if qp.style == "deepObject" {
                output += "            if let dict = \(valName) as? [String: Any] {\n"
                output += "                for (k, v) in dict { queryItems.append(URLQueryItem(name: \"\(qp.name)[\\(k)]\", value: String(describing: v))) }\n"
                output += "            }\n"
            } else {
                output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: \(valName))))\n"
            }
        } else {
            output += "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: \(valName))))\n"
        }
        if !qp.isRequired {
            output += "        }\n"
        }
    }

    if !requirements.isEmpty {
        for req in requirements {
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
    output += "        var request = URLRequest(url: components.url ?? baseURL)\n"
    output += "        request.httpMethod = \"\(method)\"\n"

    for hParam in headerParams {
        let swiftParamName = hParam.name.replacingOccurrences(of: "-", with: "_")
        let safeName = hParam.name.replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "-", with: "_")
        let valName = "val_\(safeName)"
        if hParam.isRequired {
            output += "        let \(valName) = \(swiftParamName)\n"
            output += "        request.setValue(String(describing: \(valName)), forHTTPHeaderField: \"\(hParam.name)\")\n"
        } else {
            output += "        if let \(valName) = \(swiftParamName) {\n"
            output += "            request.setValue(String(describing: \(valName)), forHTTPHeaderField: \"\(hParam.name)\")\n"
            output += "        }\n"
        }
    }

    if !requirements.isEmpty {
        for req in requirements {
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
    return output
}

/// Configuration describing the content type and parameter name of an operation's request body.
private struct RequestBodyEmitConfig {
    /// The Swift parameter name holding the request body.
    let bodyParamName: String
    /// Whether the body is `application/x-www-form-urlencoded`.
    let isFormUrlEncoded: Bool
    /// Whether the body is `multipart/form-data`.
    let isMultipart: Bool
    /// Whether the body is `application/octet-stream`.
    let isOctetStream: Bool
    /// Optional per-property multipart encodings.
    let multipartEncodings: [String: EncodingObject]?
}

/// Emits request body serialization code for JSON, form-urlencoded, multipart/form-data, or octet-stream bodies.
///
/// - Parameters:
///   - config: The `RequestBodyEmitConfig` describing body serialization options.
///   - operation: The OpenAPI `Operation` descriptor.
/// - Returns: Generated Swift statements populating `request.httpBody`.
private func emitStandardRequestBody(
    config: RequestBodyEmitConfig,
    operation: Operation
) -> String {
    let bodyParamName = config.bodyParamName
    let isFormUrlEncoded = config.isFormUrlEncoded
    let isMultipart = config.isMultipart
    let isOctetStream = config.isOctetStream
    let multipartEncodings = config.multipartEncodings
    var output = ""
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
        output += "            request.httpBody = formString.data(using: String.Encoding.utf8)\n"
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
        output += "                     fileData = stringVal.data(using: String.Encoding.utf8)\n"
        output += "                 } else {\n"
        output += "                     fileData = String(describing: value).data(using: String.Encoding.utf8)\n"
        output += "                 }\n"
        output += "                 if let fd = fileData {\n"
        output += "                     bodyData.append(Data(\"--\\(boundary)\\r\\n\".utf8))\n"
        output += "                     bodyData.append(Data(\"Content-Disposition: form-data; name=\\\"\\(key)\\\"\\(filename)\\r\\n\".utf8))\n"
        output += "                     bodyData.append(Data(\"Content-Type: \\(contentType)\\r\\n\\r\\n\".utf8))\n"
        output += "                     bodyData.append(fd)\n"
        output += "                     bodyData.append(Data(\"\\r\\n\".utf8))\n"
        output += "                 }\n"
        output += "             }\n"
        output += "             bodyData.append(Data(\"--\\(boundary)--\\r\\n\".utf8))\n"
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
        var isBodyRequired = operation.requestBody?.required ?? false
        if !isBodyRequired, let params = operation.parameters, params.contains(where: { $0.in == "body" && ($0.required ?? false) }) {
            isBodyRequired = true
        }
        if isBodyRequired {
            output += "        request.httpBody = try JSONEncoder().encode(\(bodyParamName))\n"
        } else {
            output += "        if let body = \(bodyParamName) {\n"
            output += "            request.httpBody = try JSONEncoder().encode(body)\n"
            output += "        }\n"
        }
    }
    return output
}

/// Emits delegate protocols for OpenAPI callbacks.
///
/// - Parameters:
///   - operationId: The parent operation identifier.
///   - callbacks: Optional dictionary mapping callback names to `Callback` definitions.
/// - Returns: Generated Swift callback protocol source code.
public func emitCallbacks(operationId: String, callbacks: [String: Callback]?) -> String {
    guard let callbacks = callbacks, !callbacks.isEmpty else { return "" }
    // Initialize the output string for the generated method.
    var output = ""
    // protocolName
    let protocolName = "\(operationId.prefix(1).uppercased())\(operationId.dropFirst())Callbacks"
    output += "/// Callbacks for \(operationId)\n"
    output += "public protocol \(protocolName) {\n"

    // sortedCallbacks
    let sortedCallbacks = callbacks.sorted { $0.key < $1.key }
    for (callbackName, callbackDict) in sortedCallbacks {
        for (_, pathItem) in callbackDict {
            for (_, op) in pathItem.operationsByMethod {
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
    output += "}\n"
    return output
}
