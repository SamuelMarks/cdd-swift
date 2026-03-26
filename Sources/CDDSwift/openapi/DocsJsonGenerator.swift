import Foundation

public class DocsJsonGenerator {
    public static func generate(from document: OpenAPIDocument, includeImports: Bool = true, includeWrapping: Bool = true) -> String {
        var endpoints: [String: [String: String]] = [:]

        let baseUrl = document.servers?.first?.url ?? "https://api.example.com"

        if let paths = document.paths {
            for (path, pathItem) in paths {
                var pathMap: [String: String] = [:]
                
                let methods: [(String, Operation?)] = [
                    ("get", pathItem.get),
                    ("post", pathItem.post),
                    ("put", pathItem.put),
                    ("delete", pathItem.delete),
                    ("patch", pathItem.patch),
                    ("options", pathItem.options),
                    ("head", pathItem.head),
                    ("trace", pathItem.trace)
                ]

                for (method, operation) in methods {
                    if let op = operation {
                        let opName = op.operationId ?? method + path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

                        var lines = [String]()
                        
                        if includeImports {
                            lines.append("import Foundation\n")
                        }

                        if includeWrapping {
                            lines.append("class APIClient {")
                            lines.append("    func \(opName)() async throws {")
                        }
                        
                        let indent = includeWrapping ? "        " : ""

                        let urlString = "\(baseUrl)\(path)"
                        lines.append("\(indent)let url = URL(string: \"\(urlString)\")!")
                        lines.append("\(indent)var request = URLRequest(url: url)")
                        lines.append("\(indent)request.httpMethod = \"\(method.uppercased())\"")

                        if method == "post" || method == "put" || method == "patch" {
                            lines.append("\(indent)let payload: [String: Any] = [:] // TODO: Add payload")
                            lines.append("\(indent)request.httpBody = try? JSONSerialization.data(withJSONObject: payload)")
                            lines.append("\(indent)request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")
                        }

                        lines.append("\(indent)let (data, response) = try await URLSession.shared.data(for: request)")
                        lines.append("\(indent)let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0")

                        if includeWrapping {
                            lines.append("    }")
                            lines.append("}")
                        }
                        
                        pathMap[method] = lines.joined(separator: "\n")
                    }
                }
                if !pathMap.isEmpty {
                    endpoints[path] = pathMap
                }
            }
        }

        let root: [String: Any] = ["endpoints": endpoints]

        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes]),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }

        return "{}"
    }
}
