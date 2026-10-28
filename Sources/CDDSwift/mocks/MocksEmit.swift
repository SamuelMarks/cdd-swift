/// Swift mock API client code emitter for OpenAPI paths.

/// Emits Mock API client code.
///
/// - Parameter paths: Optional map of OpenAPI path templates to `PathItem` definitions.
/// - Returns: Generated `MockAPIClient` Swift class source code.
public func emitMockClient(paths: [String: PathItem]?) -> String {
    var output = "public class MockAPIClient {\n"
    output += "    public init() {}\n"

    if let paths {
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            for (httpMethod, op) in item.operationsByMethod {
                output += emitMockMethod(path: path, method: httpMethod.rawValue.uppercased(), op: op)
            }
        }
    }

    output += "}\n"
    return output
}

/// Emits a single mock method inside `MockAPIClient` for an OpenAPI operation.
///
/// - Parameters:
///   - path: The URL path template string.
///   - method: The uppercase HTTP method name.
///   - op: The OpenAPI `Operation` descriptor.
/// - Returns: Generated Swift method declaration for `MockAPIClient`.
private func emitMockMethod(path: String, method: String, op: Operation) -> String {
    let sanitizedPath = path
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "{", with: "")
        .replacingOccurrences(of: "}", with: "")
    let funcName = op.operationId ?? "\(method.lowercased())\(sanitizedPath)"
    let returnType = inferMockReturnType(from: op.responses)
    let args = collectMockMethodArgs(for: op)
    let argsString = args.joined(separator: ", ")

    var output = "    public func \(funcName)(\(argsString)) async throws -> \(returnType) {\n"
    if returnType != "Void" {
        output += "        fatalError(\"Mock \(funcName) not implemented\")\n"
    }
    output += "    }\n"
    return output
}

/// Infers the Swift return type for a mock method from its `200`, `201`, or `default` JSON response schema.
///
/// - Parameter responses: Optional dictionary of OpenAPI `Response` objects.
/// - Returns: The mapped Swift return type string (defaults to `"Void"`).
private func inferMockReturnType(from responses: [String: Response]?) -> String {
    guard let responses,
          let okResponse = responses["200"] ?? responses["201"] ?? responses["default"],
          let jsonContent = okResponse.content?["application/json"],
          let schema = jsonContent.schema
    else {
        return "Void"
    }
    return mapType(schema: schema)
}

/// Collects the formatted Swift parameter signature strings for a mock client method.
///
/// - Parameter op: The OpenAPI `Operation` descriptor.
/// - Returns: Array of `"name: Type = nil"` parameter strings.
private func collectMockMethodArgs(for op: Operation) -> [String] {
    var args: [String] = []
    if let params = op.parameters {
        for param in params {
            let pName = param.name ?? (param.ref?.components(separatedBy: "/").last ?? "unknown")
            let safePName = pName.replacingOccurrences(of: "-", with: "_")
            let type = param.schema.map { mapType(schema: $0) } ?? "String"
            let isRequired = param.required ?? false
            let optionalSuffix = isRequired ? "" : "?"
            args.append("\(safePName): \(type)\(optionalSuffix)\(isRequired ? "" : " = nil")")
        }
    }
    if let reqBody = op.requestBody {
        let isRequired = reqBody.required ?? false
        let suffix = (isRequired ? "" : "?") + (isRequired ? "" : " = nil")
        if let schema = reqBody.content?["application/json"]?.schema {
            args.append("body: \(mapType(schema: schema))\(suffix)")
        } else if let schema = reqBody.content?["application/x-www-form-urlencoded"]?.schema {
            args.append("formData: \(mapType(schema: schema))\(suffix)")
        } else if let schema = reqBody.content?["multipart/form-data"]?.schema {
            args.append("multipartData: \(mapType(schema: schema))\(suffix)")
        }
    }
    return args
}
