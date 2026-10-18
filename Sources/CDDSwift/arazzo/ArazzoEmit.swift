import Foundation

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

    /// Serializes an `ArazzoSpecification` to a clean YAML string representation.
    ///
    /// - Parameter specification: The `ArazzoSpecification` to serialize.
    /// - Returns: Formatted YAML string.
    public static func emitYAML(from specification: ArazzoSpecification) -> String {
        let nl = String(UnicodeScalar(10))
        let q = String(UnicodeScalar(34))
        var lines: [String] = []
        lines.append("arazzo: " + q + specification.arazzo + q)
        if let selfRef = specification.selfRef {
            lines.append("$self: " + q + selfRef + q)
        }
        lines.append("info:")
        lines.append("  title: " + q + specification.info.title + q)
        if let summary = specification.info.summary {
            lines.append("  summary: " + q + summary + q)
        }
        if let description = specification.info.description {
            lines.append("  description: " + q + description + q)
        }
        lines.append("  version: " + q + specification.info.version + q)

        lines.append("sourceDescriptions:")
        for src in specification.sourceDescriptions {
            lines.append("  - name: " + q + src.name + q)
            lines.append("    url: " + q + src.url + q)
            lines.append("    type: " + q + src.type.rawValue + q)
        }

        lines.append("workflows:")
        for wf in specification.workflows {
            lines.append("  - workflowId: " + q + wf.workflowId + q)
            if let summary = wf.summary {
                lines.append("    summary: " + q + summary + q)
            }
            lines.append("    steps:")
            for step in wf.steps {
                lines.append("      - stepId: " + q + step.stepId + q)
                if let opId = step.operationId {
                    lines.append("        operationId: " + q + opId + q)
                }
            }
        }
        return lines.joined(separator: nl) + nl
    }
}
