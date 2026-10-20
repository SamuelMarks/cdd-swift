/// Unit tests for OpenAPI 3.2.0, Swagger 2.0, and Docs JSON domain models.
@testable import CDDSwift
import XCTest

/// Test suite verifying `OpenAPIDocument`, `DocsJsonOutput`, `Schema`, `Operation`, and domain enums.
final class ModelsTests: XCTestCase {
    /// Verifies encoding and decoding of a basic `OpenAPIDocument`.
    func testOpenAPIDocumentModel() throws {
        let info = Info(title: "Test API", version: "1.0")
        let doc = OpenAPIDocument(openapi: "3.0.0", info: info)

        XCTAssertEqual(doc.openapi, "3.0.0")
        XCTAssertEqual(doc.info.title, "Test API")

        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenAPIDocument.self, from: data)

        XCTAssertEqual(decoded, doc)
    }

    /// Verifies encoding and decoding of `DocsJsonOutput`, `DocsJsonOperation`, and `DocsJsonCode`.
    func testDocsJsonModels() throws {
        let code = DocsJsonCode(imports: "import Foundation", wrapper_start: "class Wrapper {", snippet: "print(1)", wrapper_end: "}")
        let operation = DocsJsonOperation(method: "GET", path: "/test", operationId: "testOp", code: code)
        let output = DocsJsonOutput(language: "swift", operations: [operation])

        XCTAssertEqual(output.language, "swift")
        XCTAssertEqual(output.operations.count, 1)

        let encoder = JSONEncoder()
        let data = try encoder.encode(output)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DocsJsonOutput.self, from: data)

        XCTAssertEqual(decoded.language, "swift")
        XCTAssertEqual(decoded.operations.first?.method, "GET")
    }

    /// Verifies `HTTPMethod`, `ParameterLocation`, `ParameterStyle`, `SecuritySchemeType`, `SchemaType`, and `Schema.updating(...)`.
    func testDomainEnumsAndHelpers() {
        let op = CDDSwift.Operation(operationId: "op1")
        let item = PathItem(get: op, put: op, post: op, delete: op, options: op, head: op, patch: op, trace: op, query: op)
        XCTAssertEqual(item.operationsByMethod.count, 9)
        XCTAssertEqual(item.operationsByMethod.map { $0.0 }, HTTPMethod.allCases)

        let emptyItem = PathItem()
        XCTAssertTrue(emptyItem.operationsByMethod.isEmpty)

        let param = Parameter(name: "id", in: "query", style: "form")
        XCTAssertEqual(param.location, .query)
        XCTAssertEqual(param.parameterStyle, .form)

        let emptyParam = Parameter(name: "id")
        XCTAssertNil(emptyParam.location)
        XCTAssertNil(emptyParam.parameterStyle)

        let scheme = SecurityScheme(type: "apiKey", name: "X-Key", in: "header")
        XCTAssertEqual(scheme.schemeType, .apiKey)
        XCTAssertEqual(scheme.keyLocation, .header)

        let emptyScheme = SecurityScheme()
        XCTAssertNil(emptyScheme.schemeType)
        XCTAssertNil(emptyScheme.keyLocation)

        let schema = Schema(type: "string", description: "orig", maximum: 10, minimum: 1, maxLength: 20, minLength: 2, pattern: "^a")
        XCTAssertEqual(schema.schemaType, .string)
        let updated = schema.updating(description: "new", minimum: 5, maximum: 50, minLength: 3, maxLength: 30, pattern: "^b")
        XCTAssertEqual(updated.description, "new")
        XCTAssertEqual(updated.minimum, 5)
        XCTAssertEqual(updated.maximum, 50)
        XCTAssertEqual(updated.minLength, 3)
        XCTAssertEqual(updated.maxLength, 30)
        XCTAssertEqual(updated.pattern, "^b")

        let unchanged = schema.updating()
        XCTAssertEqual(unchanged, schema)

        let emptySchema = Schema()
        XCTAssertNil(emptySchema.schemaType)

        let schemaItem = SchemaItem(type: "integer", format: "int64")
        XCTAssertEqual(schemaItem.schemaType, .integer)
        XCTAssertEqual(schemaItem.format, "int64")
        XCTAssertNil(SchemaItem().schemaType)
    }

    /// Verifies initialization of all OpenAPI 3.2.0 and Swagger 2.0 model structs.
    func testAllOpenAPIModelInitializers() {
        let info = Info(title: "T", summary: "S", description: "D", termsOfService: "TOS", contact: Contact(name: "N", url: "U", email: "E"), license: License(name: "L", identifier: "I", url: "U"), version: "1")
        let sv = ServerVariable(enum: ["a"], default: "a", description: "D")
        let s = Server(url: "U", description: "D", name: "N", variables: ["v": sv])
        let ext = ExternalDocumentation(description: "D", url: "U")
        let tag = Tag(name: "T", description: "D", summary: "S", parent: "P", kind: "K", externalDocs: ext)
        let xml = XML(name: "N", namespace: "NS", prefix: "P", attribute: true, wrapped: true, nodeType: "element")
        let disc = Discriminator(propertyName: "P", mapping: ["a": "b"], defaultMapping: "d")
        let oauthFlow = OAuthFlow(authorizationUrl: "A", tokenUrl: "T", refreshUrl: "R", deviceAuthorizationUrl: "DA", scopes: ["a": "b"])
        let oauthFlows = OAuthFlows(implicit: oauthFlow, password: oauthFlow, clientCredentials: oauthFlow, authorizationCode: oauthFlow, deviceAuthorization: oauthFlow)
        let sec = SecurityScheme(ref: "R", summary: "S", type: "T", description: "D", name: "N", in: "I", scheme: "S", bearerFormat: "BF", flows: oauthFlows, openIdConnectUrl: "O", oauth2MetadataUrl: "M", deprecated: true)
        let ex = Example(ref: "R", summary: "S", description: "D", dataValue: AnyCodable("V"), serializedValue: "SV", value: AnyCodable("V"), externalValue: "EV")
        let enc = EncodingObject(contentType: "CT", headers: [:], encoding: [:], prefixEncoding: [], itemEncoding: nil, style: "S", explode: true, allowReserved: true)
        XCTAssertEqual(enc, enc)
        let mt = MediaType(ref: "R", summary: "S", schema: nil, itemSchema: nil, example: AnyCodable("E"), examples: ["a": ex], encoding: ["a": enc], prefixEncoding: [enc], itemEncoding: enc)
        let h = Header(ref: "R", summary: "S", description: "D", required: true, deprecated: true, allowEmptyValue: true, style: "S", explode: true, allowReserved: true, schema: nil, example: AnyCodable("E"), examples: ["a": ex], content: ["a": mt])
        let link = Link(ref: "R", summary: "S", operationRef: "OR", operationId: "OID", parameters: ["a": AnyCodable("b")], requestBody: AnyCodable("RB"), description: "D", server: s)
        let resp = Response(ref: "R", summary: "S", description: "D", headers: ["a": h], content: ["a": mt], links: ["a": link])
        let param = Parameter(ref: "R", summary: "S", name: "N", in: "I", description: "D", required: true, deprecated: true, allowEmptyValue: true, style: "S", explode: true, allowReserved: true, schema: nil, example: AnyCodable("E"), examples: ["a": ex], content: ["a": mt])
        let rb = RequestBody(ref: "R", summary: "S", description: "D", content: ["a": mt], required: true)
        let op = CDDSwift.Operation(tags: ["T"], summary: "S", description: "D", externalDocs: ext, operationId: "OID", parameters: [param], requestBody: rb, responses: ["200": resp], callbacks: [:], deprecated: true, security: [["a": ["b"]]], servers: [s])
        let pi = PathItem(ref: "R", summary: "S", description: "D", get: op, put: op, post: op, delete: op, options: op, head: op, patch: op, trace: op, query: op, additionalOperations: ["CUSTOM": op], servers: [s], parameters: [param])
        let si = SchemaItem(type: "string", ref: "R", format: "F")
        let refObj = Reference(ref: "R", summary: "S", description: "D")
        XCTAssertEqual(refObj.ref, "R")
        let sc = Schema(
            type: "object",
            properties: [:],
            additionalProperties: si,
            items: si,
            prefixItems: [],
            required: ["a"],
            ref: "R",
            title: "T",
            description: "D",
            format: "F",
            default_value: AnyCodable("DV"),
            const_value: AnyCodable("CV"),
            multipleOf: 2,
            maximum: 10,
            exclusiveMaximum: 10,
            minimum: 1,
            exclusiveMinimum: 1,
            maxLength: 10,
            minLength: 1,
            pattern: "P",
            maxItems: 10,
            minItems: 1,
            uniqueItems: true,
            contains: si,
            minContains: 1,
            maxContains: 2,
            maxProperties: 10,
            minProperties: 1,
            dependentRequired: [:],
            dependentSchemas: [:],
            propertyNames: si,
            patternProperties: [:],
            unevaluatedItems: si,
            unevaluatedProperties: si,
            enum_values: [AnyCodable("a")],
            contentEncoding: "CE",
            contentMediaType: "CMT",
            contentSchema: si,
            allOf: [],
            oneOf: [],
            anyOf: [],
            not: si,
            if_schema: si,
            then_schema: si,
            else_schema: si,
            id: "ID",
            anchor: "A",
            dynamicAnchor: "DA",
            vocabulary: [:],
            dynamicRef: "DR",
            defs: [:],
            discriminator: disc,
            xml: xml,
            externalDocs: ext,
            example: AnyCodable("E"),
            deprecated: true,
            readOnly: true,
            writeOnly: true
        )
        let comp = Components(schemas: ["a": sc], responses: ["a": resp], parameters: ["a": param], examples: ["a": ex], requestBodies: ["a": rb], headers: ["a": h], securitySchemes: ["a": sec], links: ["a": link], callbacks: [:], pathItems: ["a": pi], mediaTypes: ["a": mt])
        let doc = OpenAPIDocument(
            openapi: "3.2.0",
            swagger: "2.0",
            selfRef: "S",
            info: info,
            jsonSchemaDialect: "JSD",
            servers: [s],
            paths: ["/a": pi],
            webhooks: ["w": pi],
            components: comp,
            security: [["a": ["b"]]],
            tags: [tag],
            externalDocs: ext,
            host: "h",
            basePath: "/v1",
            schemes: ["https"],
            consumes: ["application/json"],
            produces: ["application/json"],
            definitions: ["a": sc],
            parameters: ["a": param],
            responses: ["a": resp],
            securityDefinitions: ["a": sec]
        )
        XCTAssertEqual(doc.openapi, "3.2.0")
    }
}
