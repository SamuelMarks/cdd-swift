import ArgumentParser
import Foundation
import CDDSwift

@main
struct CDDSwiftCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cdd-swift",
        abstract: "A utility to convert between OpenAPI and Swift.",
        subcommands: [GenerateSwift.self, GenerateOpenAPI.self, ParseSwift.self, MergeSwift.self]
    )
}

struct MergeSwift: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Merge generated Swift code from an OpenAPI document into an existing Swift file.")
    
    @Argument(help: "Path to the input OpenAPI JSON file.")
    var inputPath: String
    
    @Argument(help: "Path to the existing Swift file to merge into.")
    var destinationPath: String
    
    mutating func run() async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let data = try Data(contentsOf: inputURL)
        
        do {
            let json = String(data: data, encoding: .utf8) ?? ""
            let document = try OpenAPIParser.parse(json: json)
            let generatedCode = OpenAPIToSwiftGenerator.generate(from: document)
            
            let destURL = URL(fileURLWithPath: destinationPath)
            let existingSource = try String(contentsOf: destURL, encoding: .utf8)
            
            let mergedSource = SwiftCodeMerger.merge(generatedCode: generatedCode, into: existingSource)
            
            try mergedSource.write(to: destURL, atomically: true, encoding: .utf8)
            print("✅ Successfully merged OpenAPI code into \(destinationPath)")
        } catch {
            print("❌ Failed to process: \(error)")
            throw error
        }
    }
}

struct ParseSwift: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Parse a Swift file to extract Codable models and generate OpenAPI JSON.")
    
    @Argument(help: "Path to the input Swift file.")
    var inputPath: String
    
    @Option(name: .shortAndLong, help: "Path to the output JSON file. Prints to stdout if not provided.")
    var outputPath: String?
    
    mutating func run() async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let sourceCode = try String(contentsOf: inputURL, encoding: .utf8)
        
        let parser = SwiftASTParser()
        let schemas = try parser.parseModels(from: sourceCode)
        
        let builder = OpenAPIDocumentBuilder(title: "Parsed API", version: "1.0.0")
        for (name, schema) in schemas {
            _ = builder.addSchema(name, schema: schema)
        }
        
        let jsonString = try builder.serialize()
        
        if let outputPath = outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try jsonString.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}

struct GenerateSwift: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate Swift code from an OpenAPI document.")
    
    @Argument(help: "Path to the input OpenAPI JSON file.")
    var inputPath: String
    
    @Option(name: .shortAndLong, help: "Path to the output Swift file. Prints to stdout if not provided.")
    var outputPath: String?
    
    mutating func run() async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let data = try Data(contentsOf: inputURL)
        
        do {
            let json = String(data: data, encoding: .utf8) ?? ""
            let document = try OpenAPIParser.parse(json: json)
            let swiftCode = OpenAPIToSwiftGenerator.generate(from: document)
            
            if let outputPath = outputPath {
                let outputURL = URL(fileURLWithPath: outputPath)
                try swiftCode.write(to: outputURL, atomically: true, encoding: .utf8)
                print("✅ Swift code successfully written to \(outputPath)")
            } else {
                print(swiftCode)
            }
        } catch {
            print("❌ Failed to parse OpenAPI Document: \(error)")
            throw error
        }
    }
}

struct GenerateOpenAPI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate an example OpenAPI JSON document from Swift builder.")
    
    @Option(name: .shortAndLong, help: "Path to the output JSON file. Prints to stdout if not provided.")
    var outputPath: String?
    
    mutating func run() async throws {
        let builder = OpenAPIDocumentBuilder(title: "Sample CDD API", version: "1.0.0")
            .addPath("/users", item: PathItem(
                get: Operation(
                    summary: "Get all users",
                    operationId: "getUsers",
                    responses: ["200": Response(description: "A list of users", content: ["application/json": MediaType(schema: Schema(type: "array", items: SchemaItem(ref: "#/components/schemas/User")))])]
                )
            ))
            .addSchema("User", schema: Schema(
                type: "object",
                properties: [
                    "id": Schema(type: "string"),
                    "name": Schema(type: "string")
                ],
                required: ["id", "name"]
            ))
        
        let jsonString = try builder.serialize()
        
        if let outputPath = outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try jsonString.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ OpenAPI JSON successfully written to \(outputPath)")
        } else {
            print(jsonString)
        }
    }
}
