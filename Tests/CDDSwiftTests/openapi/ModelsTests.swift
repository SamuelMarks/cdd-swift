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

    /// Verifies encoding and decoding of `DocsJsonOutput`, `DocsJsonOperation`, `DocsJsonWorkflow`, and `DocsJsonCode`.
    func testDocsJsonModels() throws {
        let code = DocsJsonCode(imports: "import Foundation", wrapper_start: "class Wrapper {", snippet: "print(1)", wrapper_end: "}")
        let operation = DocsJsonOperation(method: "GET", path: "/test", operationId: "testOp", code: code)
        let workflow = DocsJsonWorkflow(workflowId: "wf1", summary: "Run flow", code: code)
        let output = DocsJsonOutput(language: "swift", operations: [operation], webhooks: [operation], workflows: [workflow])

        XCTAssertEqual(output.language, "swift")
        XCTAssertEqual(output.operations.count, 1)
        XCTAssertEqual(output.webhooks?.count, 1)
        XCTAssertEqual(output.workflows?.first?.workflowId, "wf1")
        XCTAssertEqual(output.workflows?.first?.summary, "Run flow")

        let encoder = JSONEncoder()
        let data = try encoder.encode(output)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DocsJsonOutput.self, from: data)

        XCTAssertEqual(decoded.language, "swift")
        XCTAssertEqual(decoded.operations.first?.method, "GET")
        XCTAssertEqual(decoded.webhooks?.first?.path, "/test")
        XCTAssertEqual(decoded.workflows?.first?.workflowId, "wf1")
    }

    /// Verifies `HTTPMethod`, `ParameterLocation`, `ParameterStyle`, `SecuritySchemeType`, `SchemaType`, `OpenAPIFormat`, and
    /// `Schema.updating(...)`.
    func testDomainEnumsAndHelpers() {
        let op = CDDSwift.Operation(operationId: "op1")
        let item = PathItem(get: op, put: op, post: op, delete: op, options: op, head: op, patch: op, trace: op, query: op)
        XCTAssertEqual(item.operationsByMethod.count, 9)
        XCTAssertEqual(item.operationsByMethod.map(\.0), HTTPMethod.allCases)
        XCTAssertTrue(PathItem().operationsByMethod.isEmpty)

        let param = Parameter(name: "id", in: "query", style: "form")
        XCTAssertEqual(param.location, .query)
        XCTAssertEqual(param.parameterStyle, .form)
        XCTAssertNil(Parameter(name: "id").location)
        XCTAssertNil(Parameter(name: "id").parameterStyle)
        let paramWithCF = Parameter(name: "tags", in: "query", collectionFormat: .pipes)
        XCTAssertEqual(paramWithCF.parameterStyle, .pipeDelimited)
        let paramWithCFNoIn = Parameter(name: "tags", collectionFormat: .csv)
        XCTAssertEqual(paramWithCFNoIn.parameterStyle, .form)

        let headerExplicit = Header(style: .spaceDelimited, explode: true)
        XCTAssertEqual(headerExplicit.effectiveStyle, .spaceDelimited)
        XCTAssertEqual(headerExplicit.effectiveExplode, true)
        let headerCF = Header(collectionFormat: .pipes)
        XCTAssertEqual(headerCF.effectiveStyle, .pipeDelimited)
        XCTAssertEqual(headerCF.effectiveExplode, false)
        let headerDefault = Header()
        XCTAssertEqual(headerDefault.effectiveStyle, .simple)
        XCTAssertEqual(headerDefault.effectiveExplode, false)

        let scheme = SecurityScheme(type: "apiKey", name: "X-Key", in: "header")
        XCTAssertEqual(scheme.schemeType, .apiKey)
        XCTAssertEqual(scheme.keyLocation, .header)
        XCTAssertNil(SecurityScheme().schemeType)
        XCTAssertNil(SecurityScheme().keyLocation)

        let schema = Schema(
            type: "string",
            description: "orig",
            format: "uuid",
            maximum: 10,
            minimum: 1,
            maxLength: 20,
            minLength: 2,
            pattern: "^a"
        )
        XCTAssertEqual(schema.schemaType, .string)
        XCTAssertEqual(schema.openAPIFormat, .uuid)
        let updated = schema.updating(description: "new", minimum: 5, maximum: 50, minLength: 3, maxLength: 30, pattern: "^b")
        XCTAssertEqual(updated.description, "new")
        XCTAssertEqual(updated.minimum, 5)
        XCTAssertEqual(updated.maximum, 50)
        XCTAssertEqual(updated.minLength, 3)
        XCTAssertEqual(updated.maxLength, 30)
        XCTAssertEqual(updated.pattern, "^b")
        XCTAssertEqual(schema.updating(), schema)
        XCTAssertNil(Schema().schemaType)
        XCTAssertNil(Schema().openAPIFormat)

        let schemaItem = SchemaItem(type: "integer", format: "int64")
        XCTAssertEqual(schemaItem.schemaType, .integer)
        XCTAssertEqual(schemaItem.openAPIFormat, .int64)
        XCTAssertEqual(schemaItem.format, "int64")
        XCTAssertNil(SchemaItem().schemaType)
        XCTAssertNil(SchemaItem().openAPIFormat)
    }

    /// Verifies JSON round-trip encoding and decoding of all OpenAPI domain enums.
    func testDomainEnumCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for st in SchemaType.allCases + [.custom("x-type"), "string"] {
            let decoded = try decoder.decode(SchemaType.self, from: encoder.encode(st))
            XCTAssertEqual(decoded, st)
            XCTAssertEqual(decoded.rawValue, st.rawValue)
        }
        for fmt in OpenAPIFormat.allCases + [.custom("x-fmt"), "uuid"] {
            let decoded = try decoder.decode(OpenAPIFormat.self, from: encoder.encode(fmt))
            XCTAssertEqual(decoded, fmt)
            XCTAssertEqual(decoded.rawValue, fmt.rawValue)
        }
        for loc in ParameterLocation.allCases + [.custom("x-loc"), "query"] {
            let decoded = try decoder.decode(ParameterLocation.self, from: encoder.encode(loc))
            XCTAssertEqual(decoded, loc)
            XCTAssertEqual(decoded.description, loc.rawValue)
        }
        for sty in ParameterStyle.allCases + [.custom("x-style"), "form"] {
            let decoded = try decoder.decode(ParameterStyle.self, from: encoder.encode(sty))
            XCTAssertEqual(decoded, sty)
            XCTAssertEqual(decoded.description, sty.rawValue)
        }
        for secType in SecuritySchemeType.allCases + [.custom("x-sec"), "http"] {
            let decoded = try decoder.decode(SecuritySchemeType.self, from: encoder.encode(secType))
            XCTAssertEqual(decoded, secType)
            XCTAssertEqual(decoded.description, secType.rawValue)
        }
        for xmlNode in XMLNodeType.allCases + [.custom("x-xml"), "element"] {
            let decoded = try decoder.decode(XMLNodeType.self, from: encoder.encode(xmlNode))
            XCTAssertEqual(decoded, xmlNode)
            XCTAssertEqual(decoded.description, xmlNode.rawValue)
        }
        for sc in [200, "201", "2XX", "default", "x-custom", .range(4)] as [HTTPStatusCode] {
            let decoded = try decoder.decode(HTTPStatusCode.self, from: encoder.encode(sc))
            XCTAssertEqual(decoded, sc)
            XCTAssertEqual(decoded.description, sc.rawValue)
        }
        XCTAssertEqual(try decoder.decode(HTTPStatusCode.self, from: Data("204".utf8)), .status(204))
        for ct in ContentType.allCases + [.custom("application/problem+json"), "application/json"] {
            let decoded = try decoder.decode(ContentType.self, from: encoder.encode(ct))
            XCTAssertEqual(decoded, ct)
            XCTAssertEqual(decoded.description, ct.rawValue)
        }
    }

    /// Verifies `CollectionFormat` Codable round-trip, delimiters, and OpenAPI style/explode mappings.
    func testCollectionFormat() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for cf in CollectionFormat.allCases + [.custom("x-cf"), "csv"] {
            let decoded = try decoder.decode(CollectionFormat.self, from: encoder.encode(cf))
            XCTAssertEqual(decoded, cf)
            XCTAssertEqual(decoded.description, cf.rawValue)
        }
        XCTAssertEqual(CollectionFormat.csv.delimiter, ",")
        XCTAssertEqual(CollectionFormat.ssv.delimiter, " ")
        XCTAssertEqual(CollectionFormat.tsv.delimiter, "\t")
        XCTAssertEqual(CollectionFormat.pipes.delimiter, "|")
        XCTAssertEqual(CollectionFormat.multi.delimiter, ",")
        XCTAssertEqual(CollectionFormat.custom("x").delimiter, ",")
        XCTAssertEqual(CollectionFormat.ssv.openAPIStyle(for: .query), .spaceDelimited)
        XCTAssertEqual(CollectionFormat.tsv.openAPIStyle(for: .query), .custom("tabDelimited"))
        XCTAssertEqual(CollectionFormat.pipes.openAPIStyle(for: .query), .pipeDelimited)
        XCTAssertEqual(CollectionFormat.csv.openAPIStyle(for: .query), .form)
        XCTAssertEqual(CollectionFormat.csv.openAPIStyle(for: .header), .simple)
        XCTAssertTrue(CollectionFormat.multi.openAPIExplode)
        XCTAssertFalse(CollectionFormat.csv.openAPIExplode)
    }
}

/// Test suite verifying full initialization and JSON round-trip serialization of all OpenAPI 3.2.0 and Swagger 2.0 model structs.
final class OpenAPIFullModelsTests: XCTestCase {
    /// Builds a comprehensive `Schema` instance populating all JSON Schema keywords.
    ///
    /// - Parameters:
    ///   - disc: Sample `Discriminator`.
    ///   - xml: Sample `XML`.
    ///   - ext: Sample `ExternalDocumentation`.
    /// - Returns: The populated `Schema`.
    private func makeFullSchema(disc: Discriminator, xml: XML, ext: ExternalDocumentation) -> Schema {
        let si = SchemaItem(type: "string", ref: "R", format: "F")
        return Schema(
            type: "object", properties: [:], additionalProperties: si, items: si, prefixItems: [], required: ["a"],
            ref: "R", title: "T", description: "D", format: "F", default_value: AnyCodable("DV"), const_value: AnyCodable("CV"),
            multipleOf: 2, maximum: 10, exclusiveMaximum: 10, minimum: 1, exclusiveMinimum: 1, maxLength: 10, minLength: 1,
            pattern: "P", maxItems: 10, minItems: 1, uniqueItems: true, contains: si, minContains: 1, maxContains: 2,
            maxProperties: 10, minProperties: 1, dependentRequired: [:], dependentSchemas: [:], propertyNames: si,
            patternProperties: [:], unevaluatedItems: si, unevaluatedProperties: si, enum_values: [AnyCodable("a")],
            contentEncoding: "CE", contentMediaType: "CMT", contentSchema: si, allOf: [], oneOf: [], anyOf: [], not: si,
            if_schema: si, then_schema: si, else_schema: si, id: "ID", anchor: "A", dynamicAnchor: "DA", vocabulary: [:],
            dynamicRef: "DR", defs: [:], discriminator: disc, xml: xml, externalDocs: ext, example: AnyCodable("E"),
            deprecated: true, readOnly: true, writeOnly: true
        )
    }

    /// Builds a comprehensive `Components` and `PathItem` pair for `testAllOpenAPIModelInitializers`.
    ///
    /// - Parameters:
    ///   - server: Sample `Server`.
    ///   - ext: Sample `ExternalDocumentation`.
    ///   - sec: Sample `SecurityScheme`.
    ///   - schema: Sample `Schema`.
    /// - Returns: A tuple of `(Components, PathItem, Parameter, Response)`.
    private func makeFullComponentsAndPath(
        server: Server,
        ext: ExternalDocumentation,
        sec: SecurityScheme,
        schema: Schema
    ) -> (comp: Components, pathItem: PathItem) {
        let ex = Example(
            ref: "R", summary: "S", description: "D", dataValue: AnyCodable("V"),
            serializedValue: "SV", value: AnyCodable("V"), externalValue: "EV"
        )
        let enc = EncodingObject(
            contentType: "CT", headers: [:], encoding: [:], prefixEncoding: [],
            itemEncoding: nil, style: "S", explode: true, allowReserved: true
        )
        XCTAssertNotEqual(enc, EncodingObject(contentType: "OTHER"))
        let mt = MediaType(
            ref: "R", summary: "S", schema: nil, itemSchema: nil, example: AnyCodable("E"),
            examples: ["a": ex], encoding: ["a": enc], prefixEncoding: [enc], itemEncoding: enc
        )
        let h = Header(
            ref: "R", summary: "S", description: "D", required: true, deprecated: true, allowEmptyValue: true,
            style: "S", explode: true, allowReserved: true, schema: nil, example: AnyCodable("E"),
            examples: ["a": ex], content: ["a": mt]
        )
        let link = Link(
            ref: "R", summary: "S", operationRef: "OR", operationId: "OID",
            parameters: ["a": AnyCodable("b")], requestBody: AnyCodable("RB"), description: "D", server: server
        )
        let resp = Response(ref: "R", summary: "S", description: "D", headers: ["a": h], content: ["a": mt], links: ["a": link])
        let param = Parameter(
            ref: "R", summary: "S", name: "N", in: "I", description: "D", required: true, deprecated: true,
            allowEmptyValue: true, style: "S", explode: true, allowReserved: true, schema: nil,
            example: AnyCodable("E"), examples: ["a": ex], content: ["a": mt]
        )
        let rb = RequestBody(ref: "R", summary: "S", description: "D", content: ["a": mt], required: true)
        let op = CDDSwift.Operation(
            tags: ["T"], summary: "S", description: "D", externalDocs: ext, operationId: "OID",
            parameters: [param], requestBody: rb, responses: ["200": resp], callbacks: [:],
            deprecated: true, security: [["a": ["b"]]], servers: [server]
        )
        let pi = PathItem(
            ref: "R", summary: "S", description: "D", get: op, put: op, post: op, delete: op, options: op,
            head: op, patch: op, trace: op, query: op, additionalOperations: ["CUSTOM": op],
            servers: [server], parameters: [param]
        )
        let comp = Components(
            schemas: ["a": schema], responses: ["a": resp], parameters: ["a": param], examples: ["a": ex],
            requestBodies: ["a": rb], headers: ["a": h], securitySchemes: ["a": sec], links: ["a": link],
            callbacks: [:], pathItems: ["a": pi], mediaTypes: ["a": mt]
        )
        return (comp, pi)
    }

    /// Verifies initialization and full JSON round-trip serialization of all OpenAPI 3.2.0 and Swagger 2.0 model structs.
    func testAllOpenAPIModelInitializers() throws {
        let info = Info(
            title: "T", summary: "S", description: "D", termsOfService: "TOS",
            contact: Contact(name: "N", url: "U", email: "E"),
            license: License(name: "L", identifier: "I", url: "U"), version: "1"
        )
        let sv = ServerVariable(enum: ["a"], default: "a", description: "D")
        let s = Server(url: "U", description: "D", name: "N", variables: ["v": sv])
        let ext = ExternalDocumentation(description: "D", url: "U")
        let tag = Tag(name: "T", description: "D", summary: "S", parent: "P", kind: "K", externalDocs: ext)
        let xml = XML(name: "N", namespace: "NS", prefix: "P", attribute: true, wrapped: true, nodeType: .element)
        let disc = Discriminator(propertyName: "P", mapping: ["a": "b"], defaultMapping: "d")
        let oauthFlow = OAuthFlow(authorizationUrl: "A", tokenUrl: "T", refreshUrl: "R", deviceAuthorizationUrl: "DA", scopes: ["a": "b"])
        let oauthFlows = OAuthFlows(
            implicit: oauthFlow, password: oauthFlow, clientCredentials: oauthFlow,
            authorizationCode: oauthFlow, deviceAuthorization: oauthFlow
        )
        let sec = SecurityScheme(
            ref: "R", summary: "S", type: "T", description: "D", name: "N", in: "I", scheme: "S",
            bearerFormat: "BF", flows: oauthFlows, openIdConnectUrl: "O", oauth2MetadataUrl: "M", deprecated: true
        )
        let refObj = Reference(ref: "R", summary: "S", description: "D")
        let decodedRef = try JSONDecoder().decode(Reference.self, from: JSONEncoder().encode(refObj))
        XCTAssertEqual(decodedRef, refObj)

        let sc = makeFullSchema(disc: disc, xml: xml, ext: ext)
        let (comp, pi) = makeFullComponentsAndPath(server: s, ext: ext, sec: sec, schema: sc)

        let doc = OpenAPIDocument(
            openapi: "3.2.0", swagger: "2.0", selfRef: "S", info: info, jsonSchemaDialect: "JSD",
            servers: [s], paths: ["/a": pi], webhooks: ["w": pi], components: comp,
            security: [["a": ["b"]]], tags: [tag], externalDocs: ext, host: "h", basePath: "/v1",
            schemes: ["https"], consumes: ["application/json"], produces: ["application/json"],
            definitions: ["a": sc], parameters: comp.parameters, responses: comp.responses,
            securityDefinitions: ["a": sec]
        )
        let encodedDoc = try JSONEncoder().encode(doc)
        let decodedDoc = try JSONDecoder().decode(OpenAPIDocument.self, from: encodedDoc)
        XCTAssertEqual(decodedDoc, doc)
    }
}
