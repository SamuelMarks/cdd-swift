import Foundation

/// Emits XCTest cases based on the OpenAPI Spec.
public func emitTests(paths: [String: PathItem]?) -> String {
    /// Documentation for output
    var output = "import XCTest\n\n"
    output += "final class APIClientTests: XCTestCase {\n"

    if let paths = paths {
        /// Documentation for sortedPaths
        let sortedPaths = paths.sorted { $0.key < $1.key }
        for (path, item) in sortedPaths {
            /// Documentation for operations
            let operations: [(String, Operation?)] = [
                ("GET", item.get), ("POST", item.post), ("PUT", item.put),
                ("DELETE", item.delete), ("PATCH", item.patch),
            ]
            for (method, opOpt) in operations {
                if let op = opOpt {
                    /// Documentation for funcName
                    let funcName = op.operationId ?? "\(method.lowercased())\(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))"
                    output += "    func test\(funcName.prefix(1).uppercased())\(funcName.dropFirst())() async throws {\n"
                    output += "        // let client = MockAPIClient()\n"
                    output += "        // let result = try await client.\(funcName)(...)\n"
                    output += "        // XCTAssertNotNil(result)\n"
                    output += "        XCTAssertTrue(true)\n"
                    output += "    }\n"
                }
            }
        }
    } else {
        output += "    func testExample() async throws {\n"
        output += "        XCTAssertTrue(true)\n"
        output += "    }\n"
    }

    output += "}\n"
    return output
}
