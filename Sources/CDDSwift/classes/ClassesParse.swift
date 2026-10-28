/// SwiftSyntax visitor extracting Codable structs, enums, and typealiases into OpenAPI schemas.
import SwiftParser
import SwiftSyntax

/// Holds extracted enum cases and associated-value schemas for an enum declaration.
private struct ExtractedEnumElements {
    /// Raw string values for standard enum cases.
    let stringCases: [String]
    /// Associated-value schemas for `oneOf` union enum cases.
    let oneOfSchemas: [Schema]
    /// Indicates whether any case in the enum had associated values.
    let hasAssociatedValues: Bool
}

/// Model visitor to extract Codable structs into OpenAPI Schemas.
public class ModelVisitor: SyntaxVisitor {
    /// Lookup table mapping Swift primitive type names to OpenAPI `Schema` values.
    private static let primitiveSchemaMap: [String: Schema] = [
        "String": Schema(type: "string"),
        "Int": Schema(type: "integer", format: "int32"),
        "Int64": Schema(type: "integer", format: "int64"),
        "Double": Schema(type: "number", format: "double"),
        "Float": Schema(type: "number", format: "float"),
        "Bool": Schema(type: "boolean"),
        "Date": Schema(type: "string", format: "date-time"),
        "UUID": Schema(type: "string", format: "uuid"),
        "Data": Schema(type: "string", format: "binary"),
        "AnyCodable": Schema(type: "object")
    ]

    /// Dictionary of extracted schemas mapped by name.
    public var schemas: [String: Schema] = [:]

    /// Initializes the `ModelVisitor` with a syntax tree traversal mode.
    ///
    /// - Parameter viewMode: The `SyntaxTreeViewMode` used when walking syntax nodes.
    override public init(viewMode: SyntaxTreeViewMode) { super.init(viewMode: viewMode) }

    /// Visits and parses `enum` declarations into string-backed or `oneOf` OpenAPI schemas.
    ///
    /// - Parameter node: The `EnumDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the enum cases.
    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let enumName = node.name.text
        guard hasInheritedType(node.inheritanceClause, matching: ["Codable", "Encodable", "Decodable", "String"]) else {
            return .skipChildren
        }

        let extracted = extractEnumElements(from: node.memberBlock.members)
        let enumDescription = parseDocstring(from: Syntax(node))

        if extracted.hasAssociatedValues {
            schemas[enumName] = Schema(
                description: enumDescription,
                oneOf: extracted.oneOfSchemas.isEmpty ? nil : extracted.oneOfSchemas
            )
        } else {
            schemas[enumName] = Schema(
                type: "string",
                description: enumDescription,
                enum_values: extracted.stringCases.map { AnyCodable($0) }
            )
        }
        return .skipChildren
    }

    /// Extracts string case raw values and associated-value `oneOf` schemas from an enum's member block.
    ///
    /// - Parameter members: The `MemberBlockItemListSyntax` of the enum declaration.
    /// - Returns: An `ExtractedEnumElements` instance.
    private func extractEnumElements(from members: MemberBlockItemListSyntax) -> ExtractedEnumElements {
        var stringCases: [String] = []
        var oneOfSchemas: [Schema] = []
        var hasAssociatedValues = false

        for member in members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                if let assocValue = element.parameterClause {
                    hasAssociatedValues = true
                    if let firstParam = assocValue.parameters.first {
                        let (schema, _) = parseType(firstParam.type)
                        oneOfSchemas.append(schema)
                    }
                } else {
                    stringCases.append(extractEnumCaseStringValue(from: element))
                }
            }
        }
        return ExtractedEnumElements(
            stringCases: stringCases,
            oneOfSchemas: oneOfSchemas,
            hasAssociatedValues: hasAssociatedValues
        )
    }

    /// Extracts the raw string value (or case identifier fallback) from an `EnumCaseElementSyntax`.
    ///
    /// - Parameter element: The enum case element syntax node.
    /// - Returns: The resolved string literal or case identifier name.
    private func extractEnumCaseStringValue(from element: EnumCaseElementSyntax) -> String {
        if let rawValue = element.rawValue,
           let stringLiteral = rawValue.value.as(StringLiteralExprSyntax.self),
           let seg = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return seg.content.text
        }
        return element.name.text
    }

    /// Visits and parses `struct` declarations into object OpenAPI schemas.
    ///
    /// - Parameter node: The `StructDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after extracting the struct properties.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let structName = node.name.text
        guard hasInheritedType(node.inheritanceClause, matching: ["Codable", "Encodable", "Decodable"]) else {
            return .skipChildren
        }

        var properties: [String: Schema] = [:]
        var required: [String] = []
        let structDescription = parseDocstring(from: Syntax(node))

        for member in node.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            let propDescription = parseDocstring(from: Syntax(varDecl))
            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnnotation = binding.typeAnnotation
                else {
                    continue
                }
                let propName = pattern.identifier.text
                let (baseSchema, isOptional) = parseType(typeAnnotation.type)
                let propSchema = applyPropertyAttributes(
                    to: baseSchema,
                    description: propDescription,
                    attributes: varDecl.attributes
                )
                properties[propName] = propSchema
                if !isOptional {
                    required.append(propName)
                }
            }
        }

        schemas[structName] = Schema(
            type: "object",
            properties: properties.isEmpty ? nil : properties,
            required: required.isEmpty ? nil : required,
            description: structDescription
        )
        return .skipChildren
    }

    /// Checks whether an `InheritanceClauseSyntax` contains any of the specified type names.
    ///
    /// - Parameters:
    ///   - clause: Optional `InheritanceClauseSyntax` from a struct or enum declaration.
    ///   - targetTypes: Set of protocol or raw type names to match.
    /// - Returns: `true` if at least one inherited type matches `targetTypes`.
    private func hasInheritedType(_ clause: InheritanceClauseSyntax?, matching targetTypes: Set<String>) -> Bool {
        guard let clause else { return false }
        for inherited in clause.inheritedTypes where targetTypes.contains(inherited.type.trimmedDescription) {
            return true
        }
        return false
    }

    /// Applies docstring description and validation property wrapper attributes (`@Minimum`, `@Maximum`, `@MinLength`, `@MaxLength`,
    /// `@Pattern`) to a property `Schema`.
    ///
    /// - Parameters:
    ///   - schema: The base property `Schema`.
    ///   - description: Optional docstring description for the property.
    ///   - attributes: The `AttributeListSyntax` attached to the `VariableDeclSyntax`.
    /// - Returns: The updated `Schema` with any extracted constraints applied.
    private func applyPropertyAttributes(
        to schema: Schema,
        description: String?,
        attributes: AttributeListSyntax
    ) -> Schema {
        var min: Double?
        var max: Double?
        var minLen: Int?
        var maxLen: Int?
        var patternStr: String?

        for attr in attributes {
            guard let customAttr = attr.as(AttributeSyntax.self),
                  let args = customAttr.arguments?.as(LabeledExprListSyntax.self),
                  let firstArg = args.first
            else {
                continue
            }
            let attrName = customAttr.attributeName.trimmedDescription
            let exprText = firstArg.expression.trimmedDescription
            switch attrName {
            case "Minimum": min = Double(exprText)
            case "Maximum": max = Double(exprText)
            case "MinLength": minLen = Int(exprText)
            case "MaxLength": maxLen = Int(exprText)
            case "Pattern":
                if let strLit = firstArg.expression.as(StringLiteralExprSyntax.self),
                   let seg = strLit.segments.first?.as(StringSegmentSyntax.self) {
                    patternStr = seg.content.text
                }
            default: break
            }
        }

        guard description != nil || min != nil || max != nil || minLen != nil || maxLen != nil || patternStr != nil else {
            return schema
        }
        return schema.updating(
            description: description,
            minimum: min,
            maximum: max,
            minLength: minLen,
            maxLength: maxLen,
            pattern: patternStr
        )
    }

    /// Visits and parses `typealias` declarations into OpenAPI schemas.
    ///
    /// - Parameter node: The `TypeAliasDeclSyntax` node being visited.
    /// - Returns: `.skipChildren` after recording the typealias schema.
    override public func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let (schema, _) = parseType(node.initializer.value)

        let description = parseDocstring(from: Syntax(node))
        var finalSchema = schema
        if let desc = description {
            finalSchema = schema.updating(description: desc)
        }

        schemas[name] = finalSchema
        return .skipChildren
    }

    /// Parses a Swift type into an OpenAPI Schema.
    ///
    /// - Parameter type: The `TypeSyntax` node to inspect.
    /// - Returns: A tuple of the inferred `Schema` and a boolean indicating whether the type is optional.
    public func parseType(_ type: TypeSyntax) -> (Schema, Bool) {
        if let optType = type.as(OptionalTypeSyntax.self) {
            let (schema, _) = parseType(optType.wrappedType)
            return (schema, true)
        }
        if let identType = type.as(IdentifierTypeSyntax.self) {
            return (mapPrimitive(identType.name.text), false)
        }
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let (itemSchema, _) = parseType(arrayType.element)
            return (Schema(type: "array", items: toSchemaItem(itemSchema)), false)
        }
        if let dictType = type.as(DictionaryTypeSyntax.self) {
            let (valueSchema, _) = parseType(dictType.value)
            return (Schema(type: "object", additionalProperties: toSchemaItem(valueSchema)), false)
        }
        if let tupleType = type.as(TupleTypeSyntax.self) {
            let prefixItems = tupleType.elements.map { parseType($0.type).0 }
            return (Schema(type: "array", prefixItems: prefixItems.isEmpty ? nil : prefixItems), false)
        }
        return (Schema(type: "string"), false)
    }

    /// Converts an inferred element `Schema` into a `SchemaItem` for array `items` or object `additionalProperties`.
    ///
    /// - Parameter schema: The element or value `Schema`.
    /// - Returns: A `SchemaItem` preserving either `$ref` or `(type, format)`.
    private func toSchemaItem(_ schema: Schema) -> SchemaItem {
        if let ref = schema.ref {
            return SchemaItem(ref: ref)
        }
        return SchemaItem(type: schema.type, format: schema.format)
    }

    /// Maps a primitive Swift type to an OpenAPI Schema.
    ///
    /// - Parameter name: The Swift type identifier string.
    /// - Returns: The mapped OpenAPI `Schema`.
    public func mapPrimitive(_ name: String) -> Schema {
        Self.primitiveSchemaMap[name] ?? Schema(ref: "#/components/schemas/\(name)")
    }
}
