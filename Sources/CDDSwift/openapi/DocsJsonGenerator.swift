import Foundation

/// Generator for producing JSON-formatted API documentation.
public enum DocsJsonGenerator {
    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument) -> String {
        return generate(from: document, includeImports: true, includeWrapping: true)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeImports: Whether to include Foundation imports in the generated code snippet.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeImports: Bool) -> String {
        return generate(from: document, includeImports: includeImports, includeWrapping: true)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeWrapping: Whether to wrap the snippet in a class/function.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeWrapping: Bool) -> String {
        return generate(from: document, includeImports: true, includeWrapping: includeWrapping)
    }

    /// Generates JSON documentation from an OpenAPI document.
    ///
    /// - Parameters:
    ///   - document: The parsed `OpenAPIDocument`.
    ///   - includeImports: Whether to include Foundation imports in the generated code snippet.
    ///   - includeWrapping: Whether to wrap the snippet in a class/function.
    /// - Returns: A JSON string representing an array of `DocsJsonOutput` objects.
    public static func generate(from document: OpenAPIDocument, includeImports: Bool, includeWrapping: Bool) -> String {
        let baseUrl = document.servers?.first?.url ?? "https://api.example.com"
        var operations = [DocsJsonOperation]()

        for (path, pathItem) in document.paths ?? [:] {
            let methods: [(String, Operation?)] = [
                ("get", pathItem.get),
                ("post", pathItem.post),
                ("put", pathItem.put),
                ("delete", pathItem.delete),
                ("patch", pathItem.patch),
                ("options", pathItem.options),
                ("head", pathItem.head),
                ("trace", pathItem.trace),
            ]

            for (method, operation) in methods {
                guard let op = operation else { continue }

                let opName = op.operationId ?? method + path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

                var imports: String? = nil
                if includeImports {
                    imports = "import Foundation"
                }

                var wrapperStart: String? = nil
                var wrapperEnd: String? = nil
                if includeWrapping {
                    wrapperStart = "class APIClient {\n    func \(opName)() async throws {"
                    wrapperEnd = "    }\n}"
                }

                let indent = includeWrapping ? "        " : ""

                var snippetLines = [String]()
                let urlString = "\(baseUrl)\(path)"
                snippetLines.append("\(indent)let url = URL(string: \"\(urlString)\")!")
                snippetLines.append("\(indent)var request = URLRequest(url: url)")
                snippetLines.append("\(indent)request.httpMethod = \"\(method.uppercased())\"")

                if method == "post" || method == "put" || method == "patch" {
                    snippetLines.append("\(indent)let payload: [String: Any] = [:] // TODO: Add payload")
                    snippetLines.append("\(indent)request.httpBody = try? JSONSerialization.data(withJSONObject: payload)")
                    snippetLines.append("\(indent)request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")
                }

                snippetLines.append("\(indent)let (data, response) = try await URLSession.shared.data(for: request)")
                snippetLines.append("\(indent)let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0")

                let code = DocsJsonCode(
                    imports: imports,
                    wrapper_start: wrapperStart,
                    snippet: snippetLines.joined(separator: "\n"),
                    wrapper_end: wrapperEnd
                )

                let jsonOp = DocsJsonOperation(
                    method: method,
                    path: path,
                    operationId: op.operationId,
                    code: code
                )
                operations.append(jsonOp)
            }
        }

        let output = DocsJsonOutput(language: "swift", operations: operations)
        let root = [output]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

        // This force unwrap is safe as the objects are easily encodable.
        let data = try! encoder.encode(root)
        return String(data: data, encoding: .utf8)!
    }
}
