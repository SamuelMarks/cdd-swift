/// Swift API client method, parameter serializer, and security injector emitter for OpenAPI operations.

/// Describes a resolved OpenAPI operation parameter used during route method emission.
public struct RouteParamDescriptor: Sendable, Equatable {
    /// The raw OpenAPI parameter name.
    public let name: String
    /// The sanitized Swift identifier name for the parameter.
    public let swiftName: String
    /// The location of the parameter (`query`, `path`, `header`, `cookie`, `formData`, `body`).
    public let inLoc: ParameterLocation
    /// The serialization style (`form`, `simple`, `matrix`, `label`, `spaceDelimited`, `pipeDelimited`, `deepObject`).
    public let style: ParameterStyle
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
    ///   - style: The serialization style.
    ///   - explode: Whether collection parameters explode.
    ///   - isArray: Whether the parameter is an array.
    ///   - isObject: Whether the parameter is an object.
    ///   - isBinary: Whether the parameter carries binary file data.
    ///   - isRequired: Whether the parameter is mandatory.
    public init(
        name: String,
        swiftName: String,
        inLoc: ParameterLocation,
        style: ParameterStyle,
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
    guard let responses else { return "Void" }
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

/// Extracted parameter groups and function arguments from an OpenAPI `Operation`.
public struct ExtractedRouteParameters: Sendable {
    /// Formatted Swift parameter signature strings (`name: Type = nil`).
    public let args: [String]
    /// Interpolated URL path template string.
    public let pathInterpolation: String
    /// Query parameter descriptors.
    public let queryParams: [RouteParamDescriptor]
    /// Header parameter descriptors (`(name, isRequired)`).
    public let headerParams: [(name: String, isRequired: Bool)]
    /// FormData parameter descriptors.
    public let formDataParams: [RouteParamDescriptor]
}

/// Interpolates a single path parameter into a URL path template according to its `ParameterStyle` and `explode` flag.
///
/// - Parameters:
///   - path: The URL path template containing `{paramName}` placeholders.
///   - param: The `RouteParamDescriptor` describing the path parameter.
/// - Returns: The updated path string with Swift string interpolation for `param`.
public func interpolatePathParameter(path: String, param: RouteParamDescriptor) -> String {
    let pName = param.name
    let safePName = param.swiftName
    let isRequired = param.isRequired
    let isArray = param.isArray
    let explode = param.explode
    switch param.style {
    case .simple:
        if isArray {
            return path.replacingOccurrences(
                of: "{\(pName)}",
                with: #"\(\#(safePName)\#(isRequired ? "" : "?").map { String(describing: $0) }.joined(separator: ",") \#(isRequired ? "" : "?? \"\""))"#
            )
        }
        return path.replacingOccurrences(of: "{\(pName)}", with: #"\(\#(safePName))"#)
    case .label:
        if isArray {
            return path.replacingOccurrences(
                of: "{\(pName)}",
                with: #"\(\#(safePName)\#(isRequired ? "" : "?").isEmpty == false ? "." + (\#(safePName)\#(isRequired ? "" : " ?? []")).map { String(describing: $0) }.joined(separator: "\#(explode ? "." : ",")") : "")"#
            )
        }
        return path.replacingOccurrences(of: "{\(pName)}", with: #".\(\#(safePName))"#)
    case .matrix:
        if isArray {
            return path.replacingOccurrences(
                of: "{\(pName)}",
                with: #"\(\#(safePName)\#(isRequired ? "" : "?").isEmpty == false ? ";\#(pName)=" + (\#(safePName)\#(isRequired ? "" : " ?? []")).map { String(describing: $0) }.joined(separator: "\#(explode ? ";\(pName)=" : ",")") : "")"#
            )
        }
        return path.replacingOccurrences(of: "{\(pName)}", with: #";\#(pName)=\(\#(safePName))"#)
    default:
        return path.replacingOccurrences(of: "{\(pName)}", with: #"\(\#(safePName))"#)
    }
}

/// Resolves the effective OpenAPI `ParameterStyle` and `explode` flag for a `Parameter`, falling back to Swagger 2.0 `collectionFormat`.
///
/// - Parameters:
///   - param: The OpenAPI or Swagger 2.0 `Parameter`.
///   - location: The resolved `ParameterLocation`.
/// - Returns: A tuple containing the resolved `ParameterStyle` and `explode` flag.
public func resolveParameterStyleAndExplode(
    param: Parameter,
    location: ParameterLocation
) -> (style: ParameterStyle, explode: Bool) {
    if let explicitStyle = param.style {
        return (explicitStyle, param.explode ?? (explicitStyle == .form))
    }
    if let cf = param.collectionFormat ?? param.schema?.items?.collectionFormat {
        let mappedStyle = cf.openAPIStyle(for: location)
        return (mappedStyle, param.explode ?? cf.openAPIExplode)
    }
    let defaultStyle: ParameterStyle = (location == .query || location == .cookie) ? .form : .simple
    return (defaultStyle, param.explode ?? (defaultStyle == .form))
}

/// Extracts and categorizes parameters from an OpenAPI `Operation` and URL path template.
///
/// - Parameters:
///   - operation: The OpenAPI `Operation` to inspect.
///   - path: The URL path template string.
/// - Returns: An `ExtractedRouteParameters` value containing arguments, interpolated path, and grouped descriptors.
public func extractRouteParameters(from operation: Operation, path: String) -> ExtractedRouteParameters {
    var args: [String] = []
    var pathInterpolation = path
    var queryParams: [RouteParamDescriptor] = []
    var headerParams: [(name: String, isRequired: Bool)] = []
    var formDataParams: [RouteParamDescriptor] = []

    if let params = operation.parameters {
        for param in params {
            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            let safePName = pName.replacingOccurrences(of: "-", with: "_")
            let pIn: ParameterLocation = param.in ?? .query
            let type = param.schema.map { mapType(schema: $0) } ?? "String"
            let isRequired = param.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            args.append("\(safePName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")

            let (style, explode) = resolveParameterStyleAndExplode(param: param, location: pIn)
            let isArray = param.schema?.type == "array"
            let isObject = param.schema?.type == "object"
            let isBin = param.schema?.format == "binary" || param.schema?.type == "file"
            let descriptor = RouteParamDescriptor(
                name: pName,
                swiftName: safePName,
                inLoc: pIn,
                style: style,
                explode: explode,
                isArray: isArray,
                isObject: isObject,
                isBinary: isBin,
                isRequired: isRequired
            )

            if pIn == .path {
                pathInterpolation = interpolatePathParameter(path: pathInterpolation, param: descriptor)
            } else if pIn == .query {
                queryParams.append(descriptor)
            } else if pIn == .header {
                headerParams.append((name: pName, isRequired: isRequired))
            } else if pIn == .formData {
                formDataParams.append(descriptor)
            }
        }
    }

    return ExtractedRouteParameters(
        args: args,
        pathInterpolation: pathInterpolation,
        queryParams: queryParams,
        headerParams: headerParams,
        formDataParams: formDataParams
    )
}

/// Emits Swift source code that serializes an array query parameter according to its `ParameterStyle` and `explode` flag.
///
/// - Parameters:
///   - qp: The `RouteParamDescriptor` for the array query parameter.
///   - valName: The bound Swift local variable name holding the array value.
/// - Returns: Generated Swift statement appending one or more `URLQueryItem` values.
private func emitArrayQueryParameterSerialization(for qp: RouteParamDescriptor, valName: String) -> String {
    if qp.style == .form, qp.explode {
        return "            for item in \(valName) { queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: item))) }\n"
    } else if qp.style == .form, !qp.explode {
        return "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \",\")))\n"
    } else if qp.style == .spaceDelimited {
        return "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \" \")))\n"
    } else if qp.style == .pipeDelimited {
        return "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \"|\")))\n"
    } else if qp.style == .custom("tabDelimited") {
        return "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: \(valName).map { String(describing: $0) }.joined(separator: \"\\t\")))\n"
    }
    return "            queryItems.append(URLQueryItem(name: \"\(qp.name)\", value: String(describing: \(valName))))\n"
}

/// Emits Swift source code that serializes query parameters into `queryItems`.
///
/// - Parameter queryParams: Array of `RouteParamDescriptor` items located in the query string.
/// - Returns: Generated Swift statements appending `URLQueryItem` values.
public func emitQueryParameterSerialization(for queryParams: [RouteParamDescriptor]) -> String {
    var output = ""
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
            output += emitArrayQueryParameterSerialization(for: qp, valName: valName)
        } else if qp.isObject {
            if qp.style == .deepObject {
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
    return output
}

/// Emits Swift source code that sets HTTP request headers from operation parameters.
///
/// - Parameter headerParams: Array of `(name, isRequired)` tuples for header parameters.
/// - Returns: Generated Swift statements calling `request.setValue(_:forHTTPHeaderField:)`.
public func emitHeaderParameterSerialization(for headerParams: [(name: String, isRequired: Bool)]) -> String {
    var output = ""
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
    return output
}

/// Emits Swift source code injecting security credentials into HTTP headers (Bearer tokens and API keys).
///
/// - Parameters:
///   - requirements: Active `SecurityRequirement` array for the operation.
///   - schemes: Map of security scheme names to `SecurityScheme` definitions.
/// - Returns: Generated Swift statements setting authorization headers on `request`.
public func emitSecurityInjection(requirements: [SecurityRequirement], schemes: [String: SecurityScheme]) -> String {
    var output = ""
    guard !requirements.isEmpty else { return output }
    for req in requirements {
        for (key, _) in req {
            if let scheme = schemes[key] {
                let propName = key.prefix(1).lowercased() + key.dropFirst() + "Token"
                if scheme.type == .http && scheme.scheme?.lowercased() == "bearer" {
                    output += "        if let token = \(propName) {\n"
                    output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
                    output += "        }\n"
                } else if scheme.type == .apiKey {
                    let location: ParameterLocation = scheme.in ?? .header
                    let name = scheme.name ?? key
                    if location == .header {
                        output += "        if let token = \(propName) {\n"
                        output += "            request.setValue(\"\\(token)\", forHTTPHeaderField: \"\(name)\")\n"
                        output += "        }\n"
                    }
                } else if scheme.type == .oauth2 || scheme.type == .openIdConnect {
                    output += "        if let token = \(propName) {\n"
                    output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
                    output += "        }\n"
                }
            }
        }
    }
    return output
}

/// Emits Swift source code that executes the HTTP request, validates the 2xx status code, and decodes the response payload.
///
/// - Parameters:
///   - returnType: The expected Swift return type name (`"Void"`, `"String"`, `"Data"`, or a `Decodable` type).
///   - funcName: The Swift method name used for error logging.
/// - Returns: Generated Swift statements handling the HTTP response and decoding the return value.
public func emitResponseHandling(returnType: String, funcName: String = "request") -> String {
    var output = ""
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
    return output
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
public func emitMethod(
    path: String,
    method: String,
    operation: Operation,
    documentSecurity: [SecurityRequirement]?,
    securitySchemes: [String: SecurityScheme]
) -> String {
    let sanitizedPath = path
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
    let funcName = operation.operationId ?? "\(method.lowercased())\(sanitizedPath)"

    let extracted = extractRouteParameters(from: operation, path: path)
    let (bodyArgs, bodySerializationCode) = emitRequestBodySerialization(operation: operation, formDataParams: extracted.formDataParams)
    let args = extracted.args + bodyArgs
    let returnType = inferOperationReturnType(responses: operation.responses)
    let argsString = args.joined(separator: ", ")

    var output = ""
    if let summary = operation.summary {
        output += "    /// \(summary)\n"
    }
    if let desc = operation.description {
        output += "    /// \(desc.replacingOccurrences(of: "\n", with: "\n    /// "))\n"
    }
    output += "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"
    output += "        guard var components = URLComponents(url: baseURL.appendingPathComponent(\"\(extracted.pathInterpolation)\"), resolvingAgainstBaseURL: true) else { throw URLError(.badURL) }\n"
    output += emitQueryAndSecuritySection(
        method: method,
        queryParams: extracted.queryParams,
        headerParams: extracted.headerParams,
        requirements: operation.security ?? documentSecurity ?? [],
        securitySchemes: securitySchemes
    )
    output += bodySerializationCode
    output += emitResponseHandling(returnType: returnType, funcName: funcName)
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
            if let scheme = securitySchemes[key], scheme.type == .apiKey, scheme.in == .query {
                hasSecurityQuery = true
            }
        }
    }
    if !queryParams.isEmpty || hasSecurityQuery {
        output += "        var queryItems: [URLQueryItem] = []\n"
    } else {
        output += "        let queryItems: [URLQueryItem] = []\n"
    }
    output += emitQueryParameterSerialization(for: queryParams)

    if !requirements.isEmpty {
        for req in requirements {
            for (key, _) in req {
                if let scheme = securitySchemes[key], scheme.type == .apiKey, scheme.in == .query {
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
    output += emitHeaderParameterSerialization(for: headerParams)
    output += emitSecurityInjection(requirements: requirements, schemes: securitySchemes)
    return output
}
