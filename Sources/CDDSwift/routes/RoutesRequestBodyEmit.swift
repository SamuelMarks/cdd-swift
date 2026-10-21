/// Request body serialization and OpenAPI callback delegate emission helpers for API client routes.
import Foundation

/// Configuration describing the content type and parameter name of an operation's request body.
struct RequestBodyEmitConfig {
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

/// Extracts request body arguments and emits the corresponding HTTP body serialization statements.
///
/// - Parameters:
///   - operation: The OpenAPI `Operation` descriptor.
///   - formDataParams: Any Swagger 2.0 `formData` parameter descriptors.
/// - Returns: A tuple `(bodyArgs: [String], bodySerializationCode: String)`.
public func emitRequestBodySerialization(
    operation: Operation,
    formDataParams: [RouteParamDescriptor]
) -> (bodyArgs: [String], bodySerializationCode: String) {
    let (bodyArgs, config) = extractRequestBodyConfig(from: operation)

    if !formDataParams.isEmpty {
        let code = emitFormDataParamsBody(
            formDataParams: formDataParams,
            bodyParamName: config.bodyParamName,
            isOctetStream: config.isOctetStream
        )
        return (bodyArgs, code)
    }

    if !config.bodyParamName.isEmpty {
        let code = emitStandardRequestBody(config: config, operation: operation)
        return (bodyArgs, code)
    }

    return (bodyArgs, "")
}

/// Inspects an OpenAPI `Operation` to extract its request body argument signature and `RequestBodyEmitConfig`.
///
/// - Parameter operation: The OpenAPI `Operation` descriptor.
/// - Returns: A tuple of Swift parameter strings and the resolved `RequestBodyEmitConfig`.
private func extractRequestBodyConfig(from operation: Operation) -> ([String], RequestBodyEmitConfig) {
    var bodyArgs: [String] = []
    var bodyParamName = ""
    var isMultipart = false
    var isFormUrlEncoded = false
    var isOctetStream = false
    var multipartEncodings: [String: EncodingObject]?

    if let reqBody = operation.requestBody {
        let isRequired = reqBody.required ?? false
        let optionalSuffix = isRequired ? "" : "?"
        let defaultSuffix = isRequired ? "" : " = nil"
        if let jsonContent = reqBody.content?["application/json"], let schema = jsonContent.schema {
            let type = mapType(schema: schema)
            bodyParamName = "body"
            bodyArgs.append("body: \(type)\(optionalSuffix)\(defaultSuffix)")
        } else if let formContent = reqBody.content?["application/x-www-form-urlencoded"], let schema = formContent.schema {
            let type = mapType(schema: schema)
            bodyParamName = "formData"
            isFormUrlEncoded = true
            multipartEncodings = formContent.encoding
            bodyArgs.append("formData: \(type)\(optionalSuffix)\(defaultSuffix)")
        } else if let multiContent = reqBody.content?["multipart/form-data"], let schema = multiContent.schema {
            let type = mapType(schema: schema)
            bodyParamName = "multipartData"
            isMultipart = true
            multipartEncodings = multiContent.encoding
            bodyArgs.append("multipartData: \(type)\(optionalSuffix)\(defaultSuffix)")
        } else if let octetContent = reqBody.content?["application/octet-stream"], let schema = octetContent.schema {
            let type = mapType(schema: schema)
            bodyParamName = "fileData"
            isOctetStream = true
            bodyArgs.append("fileData: \(type)\(optionalSuffix)\(defaultSuffix)")
        }
    } else if let params = operation.parameters {
        for param in params where param.in == .body && param.schema != nil {
            bodyParamName = param.name ?? "body"
            break
        }
    }

    return (
        bodyArgs,
        RequestBodyEmitConfig(
            bodyParamName: bodyParamName,
            isFormUrlEncoded: isFormUrlEncoded,
            isMultipart: isMultipart,
            isOctetStream: isOctetStream,
            multipartEncodings: multipartEncodings
        )
    )
}

/// Emits request body serialization code for Swagger 2.0 `formData` parameters (either multipart or URL-encoded).
///
/// - Parameters:
///   - formDataParams: Array of `formData` parameter descriptors.
///   - bodyParamName: Optional body parameter name when combined with binary upload.
///   - isOctetStream: Whether the operation also carries an octet-stream body.
/// - Returns: Generated Swift source lines encoding the form data payload.
private func emitFormDataParamsBody(
    formDataParams: [RouteParamDescriptor],
    bodyParamName: String,
    isOctetStream: Bool
) -> String {
    let hasBinary = isOctetStream || formDataParams.contains(where: { $0.isBinary })
    if hasBinary {
        return emitBinaryFormDataBody(formDataParams: formDataParams, bodyParamName: bodyParamName)
    }
    return emitUrlEncodedFormDataBody(formDataParams: formDataParams)
}

/// Emits multipart/form-data body construction for Swagger 2.0 `formData` parameters that include binary file fields.
///
/// - Parameters:
///   - formDataParams: Array of `formData` parameter descriptors.
///   - bodyParamName: Optional body parameter name to append as a file part.
/// - Returns: Generated Swift source lines building the multipart `Data` body.
private func emitBinaryFormDataBody(formDataParams: [RouteParamDescriptor], bodyParamName: String) -> String {
    let q = String(UnicodeScalar(34))
    let bs = String(UnicodeScalar(92))
    var lines: [String] = []
    lines.append("        let boundary = UUID().uuidString")
    lines.append(
        "        request.setValue(\(q)multipart/form-data; boundary=\(bs)(boundary)\(q), forHTTPHeaderField: \(q)Content-Type\(q))"
    )
    lines.append("        var bodyData = Data()")
    for fp in formDataParams where !fp.isBinary {
        lines.append("        if let val = \(fp.swiftName) as Any? {")
        let dispHeader = "--\(bs)(boundary)\(bs)r\(bs)nContent-Disposition: form-data; name=\(bs)\(q)\(fp.name)\(bs)\(q)"
        lines.append(
            "            bodyData.append(Data(\(q)\(dispHeader)\(bs)r\(bs)n\(bs)r\(bs)n\(bs)(val)\(bs)r\(bs)n\(q).utf8))"
        )
        lines.append("        }")
    }
    var fileVars = formDataParams.filter { $0.isBinary }.map { $0.swiftName }
    if !bodyParamName.isEmpty {
        fileVars.append(bodyParamName)
    }
    for fileVar in fileVars {
        lines.append("        if let fileValue = \(fileVar) as Any? {")
        lines.append("            let fileData = (fileValue as? Data) ?? Data(String(describing: fileValue).utf8)")
        let fileDisposition = "Content-Disposition: form-data; name=\(bs)\(q)file\(bs)\(q); filename=\(bs)\(q)file.bin\(bs)\(q)"
        let fileHeader = "--\(bs)(boundary)\(bs)r\(bs)n\(fileDisposition)\(bs)r\(bs)nContent-Type: application/octet-stream\(bs)r\(bs)n\(bs)r\(bs)n"
        lines.append("            bodyData.append(Data(\(q)\(fileHeader)\(q).utf8))")
        lines.append("            bodyData.append(fileData)")
        lines.append("            bodyData.append(Data(\(q)\(bs)r\(bs)n\(q).utf8))")
        lines.append("        }")
    }
    lines.append("        bodyData.append(Data(\(q)--\(bs)(boundary)--\(bs)r\(bs)n\(q).utf8))")
    lines.append("        request.httpBody = bodyData")
    return lines.joined(separator: "\n") + "\n"
}

/// Emits `application/x-www-form-urlencoded` body construction for non-binary Swagger 2.0 `formData` parameters.
///
/// - Parameter formDataParams: Array of `formData` parameter descriptors.
/// - Returns: Generated Swift source lines building the URL-encoded form body.
private func emitUrlEncodedFormDataBody(formDataParams: [RouteParamDescriptor]) -> String {
    let q = String(UnicodeScalar(34))
    let bs = String(UnicodeScalar(92))
    var lines: [String] = []
    lines.append("        request.setValue(\(q)application/x-www-form-urlencoded\(q), forHTTPHeaderField: \(q)Content-Type\(q))")
    lines.append("        var formComponents: [String] = []")
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    lines.append("        let unreserved = CharacterSet(charactersIn: \(q)\(chars)\(q))")
    for fp in formDataParams {
        if fp.isRequired {
            let encExpr = "String(describing: \(fp.swiftName)).addingPercentEncoding(withAllowedCharacters: unreserved)"
            lines.append("        if let encoded = \(encExpr)?.replacingOccurrences(of: \(q)%20\(q), with: \(q)+\(q)) {")
            lines.append("            formComponents.append(\(q)\(fp.name)=\(bs)(encoded)\(q))")
            lines.append("        }")
        } else {
            let encExpr = "String(describing: val).addingPercentEncoding(withAllowedCharacters: unreserved)"
            lines.append(
                "        if let val = \(fp.swiftName), let encoded = \(encExpr)?.replacingOccurrences(of: \(q)%20\(q), with: \(q)+\(q)) {"
            )
            lines.append("            formComponents.append(\(q)\(fp.name)=\(bs)(encoded)\(q))")
            lines.append("        }")
        }
    }
    lines.append("        request.httpBody = formComponents.joined(separator: \(q)&\(q)).data(using: String.Encoding.utf8)")
    return lines.joined(separator: "\n") + "\n"
}

/// Emits request body serialization code for JSON, form-urlencoded, multipart/form-data, or octet-stream bodies.
///
/// - Parameters:
///   - config: The `RequestBodyEmitConfig` describing body serialization options.
///   - operation: The OpenAPI `Operation` descriptor.
/// - Returns: Generated Swift statements populating `request.httpBody`.
func emitStandardRequestBody(
    config: RequestBodyEmitConfig,
    operation: Operation
) -> String {
    if config.isFormUrlEncoded {
        return emitFormUrlEncodedBodyEncoding(bodyParamName: config.bodyParamName)
    } else if config.isMultipart {
        return emitMultipartBodyEncoding(bodyParamName: config.bodyParamName, multipartEncodings: config.multipartEncodings)
    } else if config.isOctetStream {
        return emitOctetStreamBodyEncoding(bodyParamName: config.bodyParamName, operation: operation)
    } else {
        return emitJsonBodyEncoding(bodyParamName: config.bodyParamName, operation: operation)
    }
}

/// Emits `Mirror`-based reflection code that preserves `Data`, `URL`, and `Bool` values in a dictionary encoded from a struct.
///
/// - Parameter bodyParamName: The Swift variable name of the body struct.
/// - Returns: Generated Swift statements updating `dict` via `Mirror`.
private func emitMirrorDictionaryOverride(bodyParamName: String) -> String {
    var output = ""
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
    return output
}

/// Emits `application/x-www-form-urlencoded` body serialization code for a structured request body model.
///
/// - Parameter bodyParamName: The Swift variable name of the form body parameter.
/// - Returns: Generated Swift statements serializing the struct into URL-encoded form components.
private func emitFormUrlEncodedBodyEncoding(bodyParamName: String) -> String {
    var output = ""
    output += "        request.setValue(\"application/x-www-form-urlencoded\", forHTTPHeaderField: \"Content-Type\")\n"
    output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), "
    output += "var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
    output += emitMirrorDictionaryOverride(bodyParamName: bodyParamName)
    output += "            var formComponents: [String] = []\n"
    let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    output += "            let unreserved = CharacterSet(charactersIn: \"\(allowedChars)\")\n"
    output += "            for (key, value) in dict {\n"
    output += "                let valueStr = String(describing: value)\n"
    output += "                if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: unreserved)"
    output += "?.replacingOccurrences(of: \" \", with: \"+\"),\n"
    output += "                   let encodedVal = valueStr.addingPercentEncoding(withAllowedCharacters: unreserved)"
    output += "?.replacingOccurrences(of: \" \", with: \"+\") {\n"
    output += "                    formComponents.append(\"\\(encodedKey)=\\(encodedVal)\")\n"
    output += "                }\n"
    output += "            }\n"
    output += "            let formString = formComponents.joined(separator: \"&\")\n"
    output += "            request.httpBody = formString.data(using: String.Encoding.utf8)\n"
    output += "        }\n"
    return output
}

/// Emits `multipart/form-data` body serialization code for a structured request body model.
///
/// - Parameters:
///   - bodyParamName: The Swift variable name of the multipart body parameter.
///   - multipartEncodings: Optional map of property names to OpenAPI `EncodingObject` descriptors.
/// - Returns: Generated Swift statements encoding each property as a multipart part.
func emitMultipartBodyEncoding(bodyParamName: String, multipartEncodings: [String: EncodingObject]?) -> String {
    var output = ""
    output += "        let boundary = UUID().uuidString\n"
    output += "        request.setValue(\"multipart/form-data; boundary=\\(boundary)\", forHTTPHeaderField: \"Content-Type\")\n"
    output += "        var bodyData = Data()\n"
    output += "        let multipartEncodingTypes: [String: String] = [\n"
    if let encodings = multipartEncodings {
        for (_, enc) in encodings {
            if let cType = enc.contentType {
                output += "            \"\\(key)\": \"\(cType)\",\n"
            }
        }
    }
    output += "        ]\n"
    output += "        if let data = try? JSONEncoder().encode(\(bodyParamName)), "
    output += "var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n"
    output += emitMirrorDictionaryOverride(bodyParamName: bodyParamName)
    output += emitMultipartFieldLoop()
    output += "             bodyData.append(Data(\"--\\(boundary)--\\r\\n\".utf8))\n"
    output += "        }\n"
    output += "        request.httpBody = bodyData\n"
    return output
}

/// Emits the inner loop that serializes each dictionary entry into a `multipart/form-data` part.
///
/// - Returns: Generated Swift `for (key, value) in dict` loop statements.
private func emitMultipartFieldLoop() -> String {
    var output = ""
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
    output += "                     bodyData.append(Data(\"Content-Disposition: form-data;"
        + " name=\\\"\\(key)\\\"\\(filename)\\r\\n\".utf8))\n"
    output += "                     bodyData.append(Data(\"Content-Type: \\(contentType)\\r\\n\\r\\n\".utf8))\n"
    output += "                     bodyData.append(fd)\n"
    output += "                     bodyData.append(Data(\"\\r\\n\".utf8))\n"
    output += "                 }\n"
    output += "             }\n"
    return output
}

/// Emits `application/octet-stream` body assignment statements.
///
/// - Parameters:
///   - bodyParamName: The Swift variable name of the binary data parameter.
///   - operation: The OpenAPI `Operation` descriptor.
/// - Returns: Generated Swift statements assigning `request.httpBody`.
private func emitOctetStreamBodyEncoding(bodyParamName: String, operation: Operation) -> String {
    var output = "        request.setValue(\"application/octet-stream\", forHTTPHeaderField: \"Content-Type\")\n"
    let isBodyRequired = operation.requestBody?.required ?? false
    if isBodyRequired {
        output += "        request.httpBody = \(bodyParamName)\n"
    } else {
        output += "        if let body = \(bodyParamName) {\n"
        output += "            request.httpBody = body\n"
        output += "        }\n"
    }
    return output
}

/// Emits `application/json` body encoding statements.
///
/// - Parameters:
///   - bodyParamName: The Swift variable name of the JSON body parameter.
///   - operation: The OpenAPI `Operation` descriptor.
/// - Returns: Generated Swift statements encoding `request.httpBody` via `JSONEncoder`.
private func emitJsonBodyEncoding(bodyParamName: String, operation: Operation) -> String {
    var output = "        request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n"
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
    var output = ""
    let protocolName = "\(operationId.prefix(1).uppercased())\(operationId.dropFirst())Callbacks"
    output += "/// Callbacks for \(operationId)\n"
    output += "public protocol \(protocolName) {\n"

    let sortedCallbacks = callbacks.sorted { $0.key < $1.key }
    for (callbackName, callbackDict) in sortedCallbacks {
        for (_, pathItem) in callbackDict {
            for (_, op) in pathItem.operationsByMethod {
                let funcName = op.operationId ?? "on\(callbackName.prefix(1).uppercased())\(callbackName.dropFirst())"
                var args: [String] = []
                if let reqBody = op.requestBody,
                   let jsonContent = reqBody.content?["application/json"],
                   let schema = jsonContent.schema {
                    let type = mapType(schema: schema)
                    let isRequired = reqBody.required ?? false
                    let optionalSuffix = isRequired ? "" : "?"
                    args.append("payload: \(type)\(optionalSuffix)")
                }
                let argsString = args.joined(separator: ", ")
                output += "    func \(funcName)(\(argsString)) async throws\n"
            }
        }
    }
    output += "}\n"
    return output
}
