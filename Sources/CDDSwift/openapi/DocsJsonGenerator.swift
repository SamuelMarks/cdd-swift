import Foundation

public class DocsJsonGenerator {
    
    public static func generate(from document: OpenAPIDocument, includeImports: Bool = true, includeWrapping: Bool = true) -> String {
        var operationsList: [DocsJsonOperation] = []
        
        let baseUrl = document.servers?.first?.url ?? "https://api.example.com"
        
        if let paths = document.paths {
            for (path, pathItem) in paths {
                
                let methods: [(String, Operation?)] = [
                    ("GET", pathItem.get),
                    ("POST", pathItem.post),
                    ("PUT", pathItem.put),
                    ("DELETE", pathItem.delete),
                    ("PATCH", pathItem.patch),
                    ("OPTIONS", pathItem.options),
                    ("HEAD", pathItem.head)
                ]
                
                for (method, operation) in methods {
                    if let op = operation {
                        let opName = op.operationId ?? method.lowercased() + path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                        
                        let importsStr = includeImports ? "import Foundation" : nil
                        
                        let wrapperStartStr = includeWrapping ? "class APIClient {\n    func \(opName)() async throws {" : nil
                        
                        var snippetLines = [String]()
                        
                        let urlString = "\(baseUrl)\(path)"
                        snippetLines.append("let url = URL(string: \"\\(urlString)\")!")
                        snippetLines.append("var request = URLRequest(url: url)")
                        snippetLines.append("request.httpMethod = \"\(method)\"")
                        
                        // Basic payload handling
                        if method == "POST" || method == "PUT" || method == "PATCH" {
                            snippetLines.append("let payload: [String: Any] = [:] // TODO: Add payload")
                            snippetLines.append("request.httpBody = try? JSONSerialization.data(withJSONObject: payload)")
                            snippetLines.append("request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")
                        }
                        
                        snippetLines.append("let (data, response) = try await URLSession.shared.data(for: request)")
                        snippetLines.append("let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0")
                        
                        let indent = includeWrapping ? "        " : ""
                        let snippetStr = snippetLines.map { indent + $0 }.joined(separator: "\n")
                        
                        let wrapperEndStr = includeWrapping ? "    }\n}" : nil
                        
                        let docsJsonCode = DocsJsonCode(
                            imports: importsStr,
                            wrapper_start: wrapperStartStr,
                            snippet: snippetStr,
                            wrapper_end: wrapperEndStr
                        )
                        
                        let docsJsonOp = DocsJsonOperation(
                            method: method,
                            path: path,
                            operationId: op.operationId,
                            code: docsJsonCode
                        )
                        operationsList.append(docsJsonOp)
                    }
                }
            }
        }
        
        // Sort operations for deterministic output
        operationsList.sort { op1, op2 in
            if op1.path == op2.path {
                return op1.method < op2.method
            }
            return op1.path < op2.path
        }
        
        let docsJsonOutput = DocsJsonOutput(language: "swift", operations: operationsList)
        let outputArray = [docsJsonOutput]
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        
        if let data = try? encoder.encode(outputArray), let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        
        return "[]"
    }
}
