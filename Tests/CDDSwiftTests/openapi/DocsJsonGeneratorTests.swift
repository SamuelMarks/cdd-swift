/// Unit tests for `DocsJsonGenerator` snippet generation and options.
@testable import CDDSwift
import XCTest

/// Test suite verifying `DocsJsonGenerator` across server configurations and wrapping/import flags.
final class DocsJsonGeneratorTests: XCTestCase {
    /// Verifies generating Docs JSON with full imports and wrapping enabled.
    func testDocsJsonGenerationFull() throws {
        let document = OpenAPIDocumentBuilder(title: "Sample API", version: "1.0.0")
            .addPath("/test", item: PathItem(
                get: Operation(operationId: "getTest"),
                post: Operation(operationId: "postTest")
            ))
            .build()

        let fullJsonStr = DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: true)
        let fullData = try XCTUnwrap(fullJsonStr.data(using: .utf8))
        let fullOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: fullData)

        XCTAssertEqual(fullOutputs.count, 1)
        XCTAssertEqual(fullOutputs[0].language, "swift")
        XCTAssertEqual(fullOutputs[0].operations.count, 2)
        XCTAssertNil(fullOutputs[0].webhooks)
        XCTAssertNil(fullOutputs[0].workflows)

        let fullCode = fullOutputs[0].operations[0].code
        XCTAssertEqual(fullCode.imports, ["import Foundation", "import GeneratedAPI"].joined(separator: "\n"))
        XCTAssertEqual(
            fullCode.wrapper_start,
            [
                "@main",
                "struct Example {",
                "    static func main() async throws {",
                "        let client = APIClient(baseURL: URL(string: \"https://api.example.com\")!)"
            ].joined(separator: "\n")
        )
        XCTAssertEqual(
            fullCode.snippet,
            ["        let response = try await client.getTest()", "        print(response)"].joined(separator: "\n")
        )
        XCTAssertEqual(fullCode.wrapper_end, ["    }", "}"].joined(separator: "\n"))
        XCTAssertFalse(fullCode.snippet.contains("URLSession"))
    }

    /// Verifies `includeImports: false` and `includeWrapping: false` combinations and default arguments.
    func testDocsJsonGenerationFlagVariants() throws {
        let document = OpenAPIDocumentBuilder(title: "Sample API", version: "1.0.0")
            .addPath("/test", item: PathItem(get: Operation(operationId: "getTest")))
            .build()

        let noImportsOutputs = try JSONDecoder().decode(
            [DocsJsonOutput].self,
            from: Data(DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: true).utf8)
        )
        let noImportsCode = noImportsOutputs[0].operations[0].code
        XCTAssertNil(noImportsCode.imports)
        XCTAssertNotNil(noImportsCode.wrapper_start)
        XCTAssertNotNil(noImportsCode.wrapper_end)

        let noWrappingOutputs = try JSONDecoder().decode(
            [DocsJsonOutput].self,
            from: Data(DocsJsonGenerator.generate(from: document, includeImports: true, includeWrapping: false).utf8)
        )
        let noWrappingCode = noWrappingOutputs[0].operations[0].code
        XCTAssertEqual(noWrappingCode.imports, ["import Foundation", "import GeneratedAPI"].joined(separator: "\n"))
        XCTAssertNil(noWrappingCode.wrapper_start)
        XCTAssertNil(noWrappingCode.wrapper_end)
        XCTAssertEqual(noWrappingCode.snippet, ["let response = try await client.getTest()", "print(response)"].joined(separator: "\n"))

        let minOutputs = try JSONDecoder().decode(
            [DocsJsonOutput].self,
            from: Data(DocsJsonGenerator.generate(from: document, includeImports: false, includeWrapping: false).utf8)
        )
        let minCode = minOutputs[0].operations[0].code
        XCTAssertNil(minCode.imports)
        XCTAssertNil(minCode.wrapper_start)
        XCTAssertNil(minCode.wrapper_end)
        XCTAssertEqual(minCode.snippet, ["let response = try await client.getTest()", "print(response)"].joined(separator: "\n"))

        let defaultOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(DocsJsonGenerator.generate(from: document).utf8))
        XCTAssertEqual(defaultOutputs[0].operations.count, 1)

        let mixed1 = DocsJsonGenerator.generate(from: document, includeImports: false)
        let mixed2 = DocsJsonGenerator.generate(from: document, includeWrapping: false)
        XCTAssertNotEqual(mixed1, mixed2)
    }

    /// Verifies generating Docs JSON for custom server URLs, anonymous operations, and empty paths.
    func testDocsJsonCustomServerAndEmptyPaths() throws {
        let docWithServer = OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "test", version: "1"),
            servers: [Server(url: "https://custom.url")],
            paths: ["/anon/{id}": PathItem(get: Operation(operationId: nil))]
        )
        let serverJsonStr = DocsJsonGenerator.generate(from: docWithServer)
        let serverOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(serverJsonStr.utf8))
        XCTAssertEqual(serverOutputs.count, 1)
        XCTAssertEqual(serverOutputs[0].operations.count, 1)
        XCTAssertNil(serverOutputs[0].operations[0].operationId)
        XCTAssertEqual(serverOutputs[0].operations[0].path, "/anon/{id}")
        XCTAssertTrue(serverOutputs[0].operations[0].code.wrapper_start?.contains("https://custom.url") == true)
        XCTAssertTrue(serverOutputs[0].operations[0].code.snippet.contains("client.get_anon_id()"))

        let docNilPaths = OpenAPIDocument(openapi: "3.2.0", info: Info(title: "test", version: "1"), paths: nil)
        let nilPathsJsonStr = DocsJsonGenerator.generate(from: docNilPaths)
        let nilPathsOutputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(nilPathsJsonStr.utf8))
        XCTAssertEqual(nilPathsOutputs.count, 1)
        XCTAssertTrue(nilPathsOutputs[0].operations.isEmpty)
    }
}

extension DocsJsonGeneratorTests {
    /// Verifies parameterized Swift SDK method calls across query, path, header, and JSON body parameters.
    func testDocsJsonParameterizedCalls() throws {
        let createOp = Operation(
            operationId: "createPet",
            parameters: [
                Parameter(name: "pet-id", in: "path", required: true, schema: Schema(type: "integer")),
                Parameter(name: "tag", in: "query", schema: Schema(type: "string"), example: AnyCodable("dog")),
                Parameter(ref: "#/components/parameters/limitParam"),
                Parameter()
            ],
            requestBody: RequestBody(
                content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/Pet"))],
                required: true
            )
        )
        let swaggerBodyOp = Operation(
            operationId: "legacyCreate",
            parameters: [
                Parameter(name: "payload", in: "body", schema: Schema(type: "object")),
                Parameter(in: "body", schema: Schema(type: "string"))
            ],
            requestBody: RequestBody(content: ["text/plain": MediaType()])
        )

        let doc = OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Pets API", version: "1.0.0"),
            paths: [
                "/pets/{pet-id}": PathItem(post: createOp, delete: swaggerBodyOp),
                "/health": PathItem(get: Operation(operationId: "healthCheck"))
            ]
        )

        let jsonStr = DocsJsonGenerator.generate(from: doc, includeImports: false, includeWrapping: false)
        let outputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(jsonStr.utf8))
        let opsById = Dictionary(uniqueKeysWithValues: outputs[0].operations.compactMap { op in
            op.operationId.map { ($0, op.code.snippet) }
        })

        let expectedArgs = #"pet_id: 1, tag: "dog", limitParam: "test_string", unknown: "test_string", body: Pet()"#
        XCTAssertEqual(
            opsById["createPet"],
            ["let response = try await client.createPet(\(expectedArgs))", "print(response)"].joined(separator: "\n")
        )
        XCTAssertEqual(
            opsById["legacyCreate"],
            [#"let response = try await client.legacyCreate(payload: [:], body: "test_string")"#, "print(response)"].joined(separator: "\n")
        )
    }

    /// Verifies form-urlencoded, multipart/form-data, and octet-stream request body calls in `DocsJsonGenerator`.
    func testDocsJsonMediaTypeRequestBodies() throws {
        let formOp = Operation(
            operationId: "submitForm",
            requestBody: RequestBody(content: ["application/x-www-form-urlencoded": MediaType(schema: Schema(type: "object"))])
        )
        let multiOp = Operation(
            operationId: "uploadMultipart",
            requestBody: RequestBody(content: ["multipart/form-data": MediaType(schema: Schema(type: "string"))])
        )
        let octetOp = Operation(
            operationId: "uploadBinary",
            requestBody: RequestBody(content: ["application/octet-stream": MediaType(schema: Schema(type: "string", format: "binary"))])
        )
        let doc = OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Media API", version: "1.0.0"),
            paths: ["/upload": PathItem(put: formOp, options: octetOp, patch: multiOp)]
        )
        let jsonStr = DocsJsonGenerator.generate(from: doc, includeImports: false, includeWrapping: false)
        let outputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(jsonStr.utf8))
        let opsById = Dictionary(uniqueKeysWithValues: outputs[0].operations.compactMap { op in
            op.operationId.map { ($0, op.code.snippet) }
        })
        XCTAssertEqual(
            opsById["submitForm"],
            ["let response = try await client.submitForm(formData: [:])", "print(response)"].joined(separator: "\n")
        )
        XCTAssertEqual(
            opsById["uploadMultipart"],
            [#"let response = try await client.uploadMultipart(multipartData: "test_string")"#, "print(response)"].joined(separator: "\n")
        )
        XCTAssertEqual(
            opsById["uploadBinary"],
            [#"let response = try await client.uploadBinary(fileData: Data("test_data".utf8))"#, "print(response)"].joined(separator: "\n")
        )
    }

    /// Verifies OpenAPI `webhooks` and Arazzo `workflows` snippet generation in `DocsJsonGenerator`.
    func testDocsJsonWebhooksAndWorkflows() throws {
        let doc = OpenAPIDocument(
            openapi: "3.2.0",
            info: Info(title: "Webhook API", version: "1.0.0"),
            servers: [Server(url: "https://hooks.example.com")],
            paths: [:],
            webhooks: [
                "newPet": PathItem(
                    put: Operation(operationId: nil),
                    post: Operation(
                        operationId: "onNewPet",
                        requestBody: RequestBody(content: ["application/json": MediaType(schema: Schema(ref: "#/components/schemas/Pet"))])
                    )
                ),
                "deletedPet": PathItem(post: Operation(operationId: "onDeletedPet"))
            ]
        )

        let workflowWithInputs = ArazzoWorkflow(
            workflowId: "loginAndFetch",
            summary: "Logs in and fetches profile",
            inputs: Schema(type: "object", properties: ["username": Schema(type: "string"), "retryCount": Schema(type: "integer")]),
            steps: [ArazzoStep(stepId: "s1", operationId: "login")]
        )
        let workflowEmptyInputs = ArazzoWorkflow(workflowId: "pingFlow", steps: [ArazzoStep(stepId: "s1", operationId: "ping")])
        let arazzo = ArazzoSpecification(
            info: ArazzoInfo(title: "Flows", version: "1.0.0"),
            sourceDescriptions: [ArazzoSourceDescription(name: "api", url: "https://flow.example.com", type: .openapi)],
            workflows: [workflowWithInputs, workflowEmptyInputs]
        )

        let combinedStr = DocsJsonGenerator.generate(from: doc, arazzo: arazzo, includeImports: true, includeWrapping: true)
        let combined = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(combinedStr.utf8))
        let webhooks = try XCTUnwrap(combined[0].webhooks)
        XCTAssertEqual(webhooks.count, 3)
        let webhookSnippets = webhooks.map(\.code.snippet)
        XCTAssertTrue(webhookSnippets.contains(where: { $0.contains("client.onNewPet(body: Pet())") }))
        XCTAssertTrue(webhookSnippets.contains(where: { $0.contains("client.onNewPet()") }))

        let workflows = try XCTUnwrap(combined[0].workflows)
        XCTAssertEqual(workflows.count, 2)
        XCTAssertEqual(workflows[0].workflowId, "loginAndFetch")
        XCTAssertEqual(workflows[0].summary, "Logs in and fetches profile")
        XCTAssertTrue(workflows[0].code.wrapper_start?.contains("let workflows = WorkflowsClient(client: client)") == true)
        XCTAssertTrue(
            workflows[0].code.snippet.contains(
                #"let outputs = try await workflows.loginAndFetch(inputs: LoginAndFetchInputs(retryCount: 1, username: "test_string"))"#
            )
        )
        XCTAssertTrue(workflows[1].code.snippet.contains("let outputs = try await workflows.pingFlow(inputs: PingFlowInputs())"))
    }

    /// Verifies standalone Arazzo workflow snippet generation without imports or wrapping.
    func testDocsJsonStandaloneArazzoWorkflows() throws {
        let workflowEmptyInputs = ArazzoWorkflow(workflowId: "pingFlow", steps: [ArazzoStep(stepId: "s1", operationId: "ping")])
        let standaloneArazzoStr = DocsJsonGenerator.generate(
            from: ArazzoSpecification(
                info: ArazzoInfo(title: "Standalone", version: "1.0.0"),
                sourceDescriptions: [],
                workflows: [workflowEmptyInputs]
            ),
            includeImports: false,
            includeWrapping: false
        )
        let standalone = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(standaloneArazzoStr.utf8))
        let standaloneWf = try XCTUnwrap(standalone[0].workflows?.first)
        XCTAssertNil(standaloneWf.code.imports)
        XCTAssertNil(standaloneWf.code.wrapper_start)
        XCTAssertEqual(
            standaloneWf.code.snippet,
            ["let outputs = try await workflows.pingFlow(inputs: PingFlowInputs())", "print(outputs)"].joined(separator: "\n")
        )
    }

    /// Verifies Swagger 2.0 `host`/`basePath`/`schemes` base URL fallback, `additionalOperations`, and `PathItem.parameters` merging.
    func testDocsJsonSwaggerHostAdditionalOperationsAndPathParameters() throws {
        let swaggerDoc = OpenAPIDocument(
            swagger: "2.0",
            info: Info(title: "Legacy API", version: "1.0.0"),
            paths: [
                "/items/{id}": PathItem(
                    get: Operation(
                        operationId: "getItem",
                        parameters: [Parameter(name: "id", in: "path", required: true, schema: Schema(type: "integer"))]
                    ),
                    additionalOperations: [
                        "PURGE": Operation(
                            operationId: "purgeItem",
                            parameters: [Parameter(ref: "#/components/parameters/SharedRef")]
                        ),
                        "COPY": Operation(operationId: "copyItem")
                    ],
                    parameters: [
                        Parameter(name: "id", in: "path", required: true, schema: Schema(type: "string")),
                        Parameter(name: "tenant", in: "header", required: true, schema: Schema(type: "string")),
                        Parameter()
                    ]
                )
            ],
            host: "legacy.example.com",
            basePath: "/v1",
            schemes: ["http"]
        )
        let jsonStr = DocsJsonGenerator.generate(from: swaggerDoc)
        let outputs = try JSONDecoder().decode([DocsJsonOutput].self, from: Data(jsonStr.utf8))
        XCTAssertEqual(outputs[0].operations.count, 3)
        XCTAssertTrue(outputs[0].operations[0].code.wrapper_start?.contains("http://legacy.example.com/v1") == true)
        XCTAssertTrue(
            outputs[0].operations[0].code.snippet.contains(
                #"let response = try await client.getItem(tenant: "test_string", unknown: "test_string", id: 1)"#
            )
        )
        XCTAssertEqual(outputs[0].operations[1].method, "copy")
        XCTAssertEqual(outputs[0].operations[2].method, "purge")
        let expectedPurgeCall = #"let response = try await client.purgeItem("#
            + #"id: "test_string", tenant: "test_string", unknown: "test_string", SharedRef: "test_string")"#
        XCTAssertTrue(outputs[0].operations[2].code.snippet.contains(expectedPurgeCall))

        let defaultSchemeDoc = OpenAPIDocument(
            swagger: "2.0",
            info: Info(title: "Default Scheme", version: "1.0.0"),
            paths: ["/ping": PathItem(get: Operation(operationId: "ping"))],
            host: "secure.example.com"
        )
        let defaultSchemeOutputs = try JSONDecoder().decode(
            [DocsJsonOutput].self,
            from: Data(DocsJsonGenerator.generate(from: defaultSchemeDoc).utf8)
        )
        XCTAssertTrue(defaultSchemeOutputs[0].operations[0].code.wrapper_start?.contains("https://secure.example.com") == true)
    }
}
