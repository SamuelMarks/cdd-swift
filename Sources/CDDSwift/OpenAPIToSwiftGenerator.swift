import Foundation

/// A utility to generate Swift code from an OpenAPI Document.
public struct OpenAPIToSwiftGenerator {
    /// Generates Swift code from the given OpenAPI document.
    /// - Parameter document: The OpenAPI document to process.
    /// - Returns: A string containing the generated Swift source code.
    public static func generate(from document: OpenAPIDocument) -> String {
        var output = "import Foundation\n\n"
        
        // Generate Models
        output += "// MARK: - Models\n\n"
        if let schemas = document.components?.schemas {
            let sortedSchemas = schemas.sorted { $0.key < $1.key }
            for (name, schema) in sortedSchemas {
                output += generateModel(name: name, schema: schema)
                output += "\n"
            }
        }
        
        // Generate API Client
        output += "// MARK: - API Client\n\n"
        output += "/// API Client for \(document.info.title) (v\(document.info.version))\n"
        output += "public struct APIClient {\n"
        output += "    /// The base URL for the API.\n"
        output += "    public let baseURL: URL\n"
        output += "    /// The URL session used for networking.\n"
        output += "    public let session: URLSession\n"
        
        // Determine if we need an auth header injected
        let hasSecuritySchemes = (document.components?.securitySchemes?.isEmpty == false)
        if hasSecuritySchemes {
            output += "    /// The authorization token to be used in requests.\n"
            output += "    public let authToken: String?\n\n"
            output += "    /// Initializes a new API Client.\n"
            output += "    public init(baseURL: URL, session: URLSession = .shared, authToken: String? = nil) {\n"
            output += "        self.baseURL = baseURL\n"
            output += "        self.session = session\n"
            output += "        self.authToken = authToken\n"
            output += "    }\n\n"
        } else {
            output += "\n    /// Initializes a new API Client.\n"
            output += "    public init(baseURL: URL, session: URLSession = .shared) {\n"
            output += "        self.baseURL = baseURL\n"
            output += "        self.session = session\n"
            output += "    }\n\n"
        }
        
        
        if let paths = document.paths {
            let sortedPaths = paths.sorted { $0.key < $1.key }
            for (path, item) in sortedPaths {
                if let getOp = item.get {
                    output += generateMethod(path: path, method: "GET", operation: getOp, hasGlobalAuth: hasSecuritySchemes)
                }
                if let postOp = item.post {
                    output += generateMethod(path: path, method: "POST", operation: postOp, hasGlobalAuth: hasSecuritySchemes)
                }
                if let putOp = item.put {
                    output += generateMethod(path: path, method: "PUT", operation: putOp, hasGlobalAuth: hasSecuritySchemes)
                }
                if let deleteOp = item.delete {
                    output += generateMethod(path: path, method: "DELETE", operation: deleteOp, hasGlobalAuth: hasSecuritySchemes)
                }
                if let patchOp = item.patch {
                    output += generateMethod(path: path, method: "PATCH", operation: patchOp, hasGlobalAuth: hasSecuritySchemes)
                }
                if let additional = item.additionalOperations {
                    for (methodName, op) in additional {
                        output += generateMethod(path: path, method: methodName.uppercased(), operation: op, hasGlobalAuth: hasSecuritySchemes)
                    }
                }
            }
        }
        
        output += "}\n\n"
        
        // Generate Webhooks
        if let webhooks = document.webhooks, !webhooks.isEmpty {
            output += "// MARK: - Webhooks Protocol\n\n"
            output += "/// Webhook definitions for \(document.info.title)\n"
            output += "public protocol WebhooksDelegate {\n"
            let sortedWebhooks = webhooks.sorted { $0.key < $1.key }
            for (name, item) in sortedWebhooks {
                if let postOp = item.post {
                    let funcName = postOp.operationId ?? "on\(name.prefix(1).uppercased())\(name.dropFirst())"
                    var args: [String] = []
                    if let reqBody = postOp.requestBody {
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
            output += "}\n"
        }
        
        // Generate Callbacks
        var callbackProtocols = ""
        if let paths = document.paths {
            for (_, item) in paths {
                let operations = [item.get, item.post, item.put, item.delete, item.patch].compactMap { $0 }
                for op in operations {
                    if let callbacks = op.callbacks, !callbacks.isEmpty {
                        let protocolName = (op.operationId ?? "Unknown").prefix(1).uppercased() + (op.operationId ?? "Unknown").dropFirst() + "Callbacks"
                        callbackProtocols += "\n/// Callbacks for \(op.operationId ?? "Unknown")\n"
                        callbackProtocols += "public protocol \(protocolName) {\n"
                        let sortedCallbacks = callbacks.sorted { $0.key < $1.key }
                        for (callbackName, callbackDict) in sortedCallbacks {
                            for (expression, pathItem) in callbackDict {
                                if let postOp = pathItem.post {
                                    let funcName = postOp.operationId ?? "on\(callbackName.prefix(1).uppercased())\(callbackName.dropFirst())"
                                    var args: [String] = []
                                    if let reqBody = postOp.requestBody {
                                        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                                            let type = mapType(schema: schema)
                                            let isRequired = reqBody.required ?? false
                                            let optionalSuffix = isRequired ? "" : "?"
                                            args.append("payload: \(type)\(optionalSuffix)")
                                        }
                                    }
                                    let argsString = args.joined(separator: ", ")
                                    callbackProtocols += "    func \(funcName)(\(argsString)) async throws\n"
                                }
                            }
                        }
                        callbackProtocols += "}\n"
                    }
                }
            }
        }
        if !callbackProtocols.isEmpty {
            output += "\n// MARK: - Callbacks Protocols\n"
            output += callbackProtocols
        }
        
        return output
    }
    
    // MARK: - Internal Generators
    
    static func generateModel(name: String, schema: Schema) -> String {
        var output = ""
        if let desc = schema.description {
            let lines = desc.split(separator: "\n")
            for line in lines {
                output += "/// \(line)\n"
            }
        }
        output += "public struct \(name): Codable, Equatable {\n"
        var allProperties: [(name: String, schema: Schema, isRequired: Bool)] = []
        
        // Handle allOf
        if let allOf = schema.allOf {
            for subSchema in allOf {
                // If it's a ref, we'd theoretically need to resolve it, but for simplicity we assume inline properties or we generate a container that embeds the referenced type. For this generator, we will extract properties if available directly.
                if let props = subSchema.properties {
                    for (propName, propSchema) in props {
                        let isReq = subSchema.required?.contains(propName) ?? false
                        allProperties.append((propName, propSchema, isReq))
                    }
                }
            }
        }
        
        if let properties = schema.properties {
            for (propName, propSchema) in properties {
                let isReq = schema.required?.contains(propName) ?? false
                allProperties.append((propName, propSchema, isReq))
            }
        }
        
        // Remove duplicates favoring the later ones (basic override)
        var uniquePropsMap: [String: (Schema, Bool)] = [:]
        for prop in allProperties {
            uniquePropsMap[prop.name] = (prop.schema, prop.isRequired)
        }
        
        let sortedProps = uniquePropsMap.sorted { $0.key < $1.key }
        
        for (propName, propData) in sortedProps {
            let propSchema = propData.0
            if let propDesc = propSchema.description {
                let lines = propDesc.split(separator: "\n")
                for line in lines {
                    output += "    /// \(line)\n"
                }
            }
            let swiftType = mapType(schema: propSchema)
            let isRequired = propData.1
            let optionalSuffix = isRequired ? "" : "?"
            output += "    public var \(propName): \(swiftType)\(optionalSuffix)\n"
        }
        output += "\n"
        
        // Initializer
        if !sortedProps.isEmpty {
            let params = sortedProps.map { (propName, propData) -> String in
                let swiftType = mapType(schema: propData.0)
                let isRequired = propData.1
                let optionalSuffix = isRequired ? "" : "?"
                return "\(propName): \(swiftType)\(optionalSuffix)\(isRequired ? "" : " = nil")"
            }.joined(separator: ", ")
            
            output += "    public init(\(params)) {\n"
            for (propName, _) in sortedProps {
                output += "        self.\(propName) = \(propName)\n"
            }
            output += "    }\n"
        } else if schema.type == "string" && schema.enum_values != nil {
            // Handle Enums encoded as string
             output = ""
             if let desc = schema.description {
                 let lines = desc.split(separator: "\n")
                 for line in lines {
                     output += "/// \(line)\n"
                 }
             }
             output += "public enum \(name): String, Codable, Equatable, CaseIterable {\n"
             if let enumValues = schema.enum_values {
                 for val in enumValues {
                     if let strVal = val.value as? String {
                         output += "    case \(strVal.replacingOccurrences(of: "-", with: "_").lowercased()) = \"\(strVal)\"\n"
                     }
                 }
             }
             output += "}\n"
             return output
        } else if schema.type == "object" && schema.additionalProperties != nil {
            // Handle dictionary types
            // In a real scenario we'd typealias, but here we just return a struct wrapping it or skip if handled by mapType.
        } else if schema.anyOf != nil || schema.oneOf != nil {
             // Handle Polymorphism using an enum with associated values
             output = ""
             if let desc = schema.description {
                 let lines = desc.split(separator: "\n")
                 for line in lines {
                     output += "/// \(line)\n"
                 }
             }
             output += "public enum \(name): Codable, Equatable {\n"
             let options = schema.anyOf ?? schema.oneOf!
             var i = 1
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "    case option\(i)(\(typeName))\n"
                 i += 1
             }
             
             // Generate custom codable conformance for oneOf/anyOf
             output += "\n    public init(from decoder: Decoder) throws {\n"
             output += "        let container = try decoder.singleValueContainer()\n"
             i = 1
             for option in options {
                 let typeName = mapType(schema: option)
                 output += "        if let value = try? container.decode(\(typeName).self) {\n"
                 output += "            self = .option\(i)(value)\n"
                 output += "            return\n"
                 output += "        }\n"
                 i += 1
             }
             output += "        throw DecodingError.typeMismatch(\(name).self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: \"Failed to decode \(name) anyOf/oneOf\"))\n"
             output += "    }\n"
             
             output += "\n    public func encode(to encoder: Encoder) throws {\n"
             output += "        var container = encoder.singleValueContainer()\n"
             output += "        switch self {\n"
             i = 1
             for option in options {
                 output += "        case .option\(i)(let value):\n"
                 output += "            try container.encode(value)\n"
                 i += 1
             }
             output += "        }\n"
             output += "    }\n"
             
             output += "}\n"
             return output
        } else {
             // Empty struct
             output += "    public init() {}\n"
        }
        
        if schema.anyOf == nil && schema.oneOf == nil {
            output += "}\n"
        }
        return output
    }
    
    static func generateMethod(path: String, method: String, operation: Operation, hasGlobalAuth: Bool) -> String {
        let funcName = operation.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
        
        var args: [String] = []
        var pathInterpolation = path
        var queryParams: [String] = []
        var headerParams: [String] = []
        
        if let params = operation.parameters {
            for param in params {
                let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
                let pIn = param.in ?? "query"
                let type = param.schema != nil ? mapType(schema: param.schema!) : "String"
                let isRequired = param.required ?? false
                let optionalSuffix = isRequired ? "" : "?"
                args.append("\(pName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
                
                if pIn == "path" {
                    pathInterpolation = pathInterpolation.replacingOccurrences(of: "{\(pName)}", with: "\\(\(pName))")
                } else if pIn == "query" {
                    queryParams.append(pName)
                } else if pIn == "header" {
                    headerParams.append(pName)
                }
            }
        }
        
        var bodyParamName = ""
        var isMultipart = false
        var isFormUrlEncoded = false
        if let reqBody = operation.requestBody {
            if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
                let type = mapType(schema: schema)
                let isRequired = reqBody.required ?? false
                let optionalSuffix = isRequired ? "" : "?"
                bodyParamName = "body"
                args.append("body: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
            } else if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
                let type = mapType(schema: schema)
                let isRequired = reqBody.required ?? false
                let optionalSuffix = isRequired ? "" : "?"
                bodyParamName = "formData"
                isFormUrlEncoded = true
                args.append("formData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
            } else if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
                let type = mapType(schema: schema)
                let isRequired = reqBody.required ?? false
                let optionalSuffix = isRequired ? "" : "?"
                bodyParamName = "multipartData"
                isMultipart = true
                args.append("multipartData: \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
            }
        }
        
        var returnType = "Void"
        if let responses = operation.responses {
            if let okResponse = responses["200"] ?? responses["201"], let content = okResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
                returnType = mapType(schema: schema)
            } else if let defaultResponse = responses["default"], let content = defaultResponse.content, let jsonContent = content["application/json"], let schema = jsonContent.schema {
                returnType = mapType(schema: schema)
            }
        }
        
        let argsString = args.joined(separator: ", ")
        
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
            for qParam in queryParams {
                output += "        if let val = \(qParam) {\n"
                output += "            queryItems.append(URLQueryItem(name: \"\(qParam)\", value: String(describing: val)))\n"
                output += "        }\n"
            }
            output += "        components.queryItems = queryItems.isEmpty ? nil : queryItems\n"
            output += "        var request = URLRequest(url: components.url!)\n"
        }
        
        output += "        request.httpMethod = \"\(method)\"\n"
        
        for hParam in headerParams {
            output += "        if let val = \(hParam) {\n"
            output += "            request.setValue(String(describing: val), forHTTPHeaderField: \"\(hParam)\")\n"
            output += "        }\n"
        }
        
        let operationHasSecurityOverride = operation.security != nil
        let needsAuth = hasGlobalAuth || operationHasSecurityOverride
        
        if needsAuth {
            output += "        if let token = authToken {\n"
            output += "            request.setValue(\"Bearer \\(token)\", forHTTPHeaderField: \"Authorization\")\n"
            output += "        }\n"
        }
        
        if !bodyParamName.isEmpty {
            if isFormUrlEncoded {
                output += "        request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")\n"
                output += "        // Assuming formData can be serialized to Dictionary\n"
                output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
                output += "            let formString = dict.map { \"\\($0.key)=\\(String(describing: $0.value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? \\\"\\\")\" }.joined(separator: \"&\")\n"
                output += "            request.httpBody = formString.data(using: .utf8)\n"
                output += "        }\n"
            } else if isMultipart {
                output += "        let boundary = UUID().uuidString\n"
                output += "        request.setValue(\"multipart/form-data; boundary=\\(boundary)\", forHTTPHeaderField: \"Content-Type\")\n"
                output += "        // Basic multipart encoding stub\n"
                output += "        var bodyData = Data()\n"
                output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
                output += "             for (key, value) in dict {\n"
                output += "                 bodyData.append(\"--\\(boundary)\\r\\n\".data(using: .utf8)!)\n"
                output += "                 bodyData.append(\"Content-Disposition: form-data; name=\\\"\\(key)\\\"\\r\\n\\r\\n\".data(using: .utf8)!)\n"
                output += "                 bodyData.append(\"\\(value)\\r\\n\".data(using: .utf8)!)\n"
                output += "             }\n"
                output += "             bodyData.append(\"--\\(boundary)--\\r\\n\".data(using: .utf8)!)\n"
                output += "        }\n"
                output += "        request.httpBody = bodyData\n"
            } else {
                output += "        request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n"
                output += "        if let body = body {\n"
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
    
    static func mapType(schema: Schema) -> String {
        if let ref = schema.ref ?? schema.dynamicRef {
            return ref.components(separatedBy: "/").last ?? "Unknown"
        }
        switch schema.type {
        case "string":
            if schema.format == "date-time" { return "Date" }
            if schema.format == "uuid" { return "UUID" }
            if schema.enum_values != nil { return "String" } // Should be mapped to actual Enum name if passed, fallback to String
            return "String"
        case "integer": return schema.format == "int64" ? "Int64" : "Int"
        case "number": return schema.format == "float" ? "Float" : "Double"
        case "boolean": return "Bool"
        case "array":
            if let prefixItems = schema.prefixItems {
                let types = prefixItems.map { mapType(schema: $0) }.joined(separator: ", ")
                return "(\(types))"
            }
            if let items = schema.items {
                if let ref = items.ref {
                    return "[\(ref.components(separatedBy: "/").last ?? "Unknown")]"
                } else if let type = items.type {
                    let primitive = Schema(type: type)
                    return "[\(mapType(schema: primitive))]"
                }
            } else if let unevaluated = schema.unevaluatedItems {
                if let ref = unevaluated.ref {
                    return "[\(ref.components(separatedBy: "/").last ?? "Unknown")]"
                } else if let type = unevaluated.type {
                    let primitive = Schema(type: type)
                    return "[\(mapType(schema: primitive))]"
                }
            }
            return "[AnyCodable]" // Placeholder
        case "object":
            if let additional = schema.additionalProperties {
                if let ref = additional.ref {
                    let valueType = ref.components(separatedBy: "/").last ?? "Unknown"
                    return "[String: \(valueType)]"
                } else if let type = additional.type {
                    let primitive = Schema(type: type)
                    let valueType = mapType(schema: primitive)
                    return "[String: \(valueType)]"
                }
                return "[String: AnyCodable]"
            } else if let unevaluated = schema.unevaluatedProperties {
                if let ref = unevaluated.ref {
                    let valueType = ref.components(separatedBy: "/").last ?? "Unknown"
                    return "[String: \(valueType)]"
                } else if let type = unevaluated.type {
                    let primitive = Schema(type: type)
                    let valueType = mapType(schema: primitive)
                    return "[String: \(valueType)]"
                }
                return "[String: AnyCodable]"
            }
            return "AnyCodable"
        default:
            if schema.allOf != nil || schema.anyOf != nil || schema.oneOf != nil {
                // If it's a polymorphic anonymous type we default to AnyCodable. The main generateModel loop handles named root schemas.
                return "AnyCodable"
            }
            return "AnyCodable"
        }
    }
}


