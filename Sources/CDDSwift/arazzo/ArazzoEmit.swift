/// JSON and YAML serializer and parser for Arazzo 1.1.0 specifications.

/// Parses and serializes Arazzo 1.1.0 documents between JSON/YAML text and strongly typed `ArazzoSpecification` models.
public enum ArazzoEmitter {
    /// Parses a JSON string into an `ArazzoSpecification`.
    ///
    /// - Parameter json: Raw Arazzo 1.1.0 JSON string.
    /// - Returns: Decoded `ArazzoSpecification`.
    /// - Throws: `CDDError.arazzoValidationError` or `DecodingError` if invalid.
    public static func parse(json: String) throws -> ArazzoSpecification {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let spec = try decoder.decode(ArazzoSpecification.self, from: data)
        guard spec.arazzo.hasPrefix("1.1.") || spec.arazzo == "1.0.0" || spec.arazzo == "1.0.1" else {
            throw CDDError.arazzoValidationError("Unsupported Arazzo version: \(spec.arazzo)")
        }
        return spec
    }

    /// Serializes an `ArazzoSpecification` to a formatted JSON string with deterministic key sorting.
    ///
    /// - Parameter specification: The `ArazzoSpecification` to serialize.
    /// - Returns: Formatted JSON string.
    /// - Throws: Encoding error if serialization fails.
    public static func emitJSON(from specification: ArazzoSpecification) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(specification)
        return String(decoding: data, as: UTF8.self)
    }

    /// Escapes backslashes, double quotes, and newlines for double-quoted YAML scalar values.
    ///
    /// - Parameter value: Raw string value.
    /// - Returns: Escaped YAML string content.
    public static func escapeYAML(_ value: String) -> String {
        let bs = String(UnicodeScalar(92))
        let q = String(UnicodeScalar(34))
        let nl = String(UnicodeScalar(10))
        return value
            .replacingOccurrences(of: bs, with: bs + bs)
            .replacingOccurrences(of: q, with: bs + q)
            .replacingOccurrences(of: nl, with: bs + "n")
    }

    /// Formats a double-quoted escaped YAML scalar value.
    ///
    /// - Parameter value: Raw string value to quote and escape.
    /// - Returns: Quoted and escaped YAML scalar string.
    private static func quotedYAML(_ value: String) -> String {
        let q = String(UnicodeScalar(34))
        return q + escapeYAML(value) + q
    }

    /// Serializes an `ArazzoSpecification` to a clean YAML string representation.
    ///
    /// - Parameter specification: The `ArazzoSpecification` to serialize.
    /// - Returns: Formatted YAML string.
    public static func emitYAML(from specification: ArazzoSpecification) -> String {
        let nl = String(UnicodeScalar(10))
        var lines = emitYAMLHeaderAndSources(for: specification)
        lines.append("workflows:")
        for wf in specification.workflows {
            lines.append(contentsOf: emitYAMLWorkflow(wf))
        }
        lines.append(contentsOf: emitYAMLComponents(specification.components))
        return lines.joined(separator: nl) + nl
    }

    /// Emits the top-level `arazzo`, `$self`, `info`, and `sourceDescriptions` YAML lines.
    ///
    /// - Parameter specification: The `ArazzoSpecification` to serialize.
    /// - Returns: Array of YAML lines.
    private static func emitYAMLHeaderAndSources(for specification: ArazzoSpecification) -> [String] {
        var lines: [String] = []
        lines.append("arazzo: " + quotedYAML(specification.arazzo))
        if let selfRef = specification.selfRef {
            lines.append("$self: " + quotedYAML(selfRef))
        }
        lines.append("info:")
        lines.append("  title: " + quotedYAML(specification.info.title))
        if let summary = specification.info.summary {
            lines.append("  summary: " + quotedYAML(summary))
        }
        if let description = specification.info.description {
            lines.append("  description: " + quotedYAML(description))
        }
        lines.append("  version: " + quotedYAML(specification.info.version))

        lines.append("sourceDescriptions:")
        for src in specification.sourceDescriptions {
            lines.append("  - name: " + quotedYAML(src.name))
            lines.append("    url: " + quotedYAML(src.url))
            lines.append("    type: " + quotedYAML(src.type.rawValue))
        }
        return lines
    }

    /// Emits the YAML lines for a single `ArazzoWorkflow`.
    ///
    /// - Parameter wf: The `ArazzoWorkflow` to serialize.
    /// - Returns: Array of indented YAML lines.
    private static func emitYAMLWorkflow(_ wf: ArazzoWorkflow) -> [String] {
        var lines: [String] = []
        lines.append("  - workflowId: " + quotedYAML(wf.workflowId))
        if let summary = wf.summary {
            lines.append("    summary: " + quotedYAML(summary))
        }
        if let description = wf.description {
            lines.append("    description: " + quotedYAML(description))
        }
        if let dependsOn = wf.dependsOn, !dependsOn.isEmpty {
            lines.append("    dependsOn:")
            for dep in dependsOn {
                lines.append("      - " + quotedYAML(dep))
            }
        }
        lines.append("    steps:")
        for step in wf.steps {
            lines.append(contentsOf: emitYAMLStep(step))
        }
        if let outputs = wf.outputs, !outputs.isEmpty {
            lines.append("    outputs:")
            for k in outputs.keys.sorted() {
                if let v = outputs[k] {
                    lines.append("      " + k + ": " + quotedYAML(v.description))
                }
            }
        }
        return lines
    }

    /// Emits the YAML lines for a single `ArazzoStep`.
    ///
    /// - Parameter step: The `ArazzoStep` to serialize.
    /// - Returns: Array of indented YAML lines.
    private static func emitYAMLStep(_ step: ArazzoStep) -> [String] {
        var lines: [String] = []
        lines.append("      - stepId: " + quotedYAML(step.stepId))
        if let opId = step.operationId {
            lines.append("        operationId: " + quotedYAML(opId))
        }
        if let opPath = step.operationPath {
            lines.append("        operationPath: " + quotedYAML(opPath))
        }
        if let wfId = step.workflowId {
            lines.append("        workflowId: " + quotedYAML(wfId))
        }
        if let params = step.parameters, !params.isEmpty {
            lines.append("        parameters:")
            for param in params {
                lines.append("          - name: " + quotedYAML(param.name))
                lines.append("            value: " + quotedYAML(param.value.description))
            }
        }
        lines.append(contentsOf: emitYAMLStepCriteriaAndActions(step))
        return lines
    }

    /// Emits `successCriteria`, `onSuccess`, `onFailure`, and `outputs` YAML lines for an `ArazzoStep`.
    ///
    /// - Parameter step: The `ArazzoStep` to serialize.
    /// - Returns: Array of indented YAML lines.
    private static func emitYAMLStepCriteriaAndActions(_ step: ArazzoStep) -> [String] {
        var lines: [String] = []
        if let criteria = step.successCriteria, !criteria.isEmpty {
            lines.append("        successCriteria:")
            for crit in criteria {
                lines.append("          - context: " + quotedYAML(crit.context))
                lines.append("            condition: " + quotedYAML(crit.condition))
            }
        }
        if let onSuccess = step.onSuccess, !onSuccess.isEmpty {
            lines.append("        onSuccess:")
            for act in onSuccess {
                lines.append("          - name: " + quotedYAML(act.name))
                lines.append("            type: " + quotedYAML(act.type.rawValue))
            }
        }
        if let onFailure = step.onFailure, !onFailure.isEmpty {
            lines.append("        onFailure:")
            for act in onFailure {
                lines.append("          - name: " + quotedYAML(act.name))
                lines.append("            type: " + quotedYAML(act.type.rawValue))
            }
        }
        if let outputs = step.outputs, !outputs.isEmpty {
            lines.append("        outputs:")
            for k in outputs.keys.sorted() {
                if let v = outputs[k] {
                    lines.append("          " + k + ": " + quotedYAML(v.description))
                }
            }
        }
        return lines
    }

    /// Emits the optional `components` section of an `ArazzoSpecification` in YAML.
    ///
    /// - Parameter components: Optional `ArazzoComponents`.
    /// - Returns: Array of YAML lines.
    private static func emitYAMLComponents(_ components: ArazzoComponents?) -> [String] {
        guard let components, let params = components.parameters, !params.isEmpty else {
            return []
        }
        var lines: [String] = ["components:", "  parameters:"]
        for k in params.keys.sorted() {
            if let p = params[k] {
                lines.append("    " + k + ":")
                lines.append("      name: " + quotedYAML(p.name))
            }
        }
        return lines
    }
}
