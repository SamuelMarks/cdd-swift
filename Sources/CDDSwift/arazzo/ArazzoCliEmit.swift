/// Arazzo 1.1.0 Swift ArgumentParser CLI code emitter.
import Foundation

/// Code emitter generating Swift ArgumentParser CLI subcommands and runners for Arazzo 1.1.0 workflows.
public enum ArazzoCliEmitter {
    /// Sanitizes an input property name into a CLI flag or option argument name.
    ///
    /// - Parameter name: Input schema property name.
    /// - Returns: Kebab-case CLI option name.
    public static func kebabCase(_ name: String) -> String {
        SwiftIdentifierSanitizer.kebabCase(name, fallback: "arg")
    }

    /// Converts an identifier string into a PascalCase Swift command struct name.
    ///
    /// - Parameter name: Input workflow identifier.
    /// - Returns: Swift PascalCase type name.
    public static func pascalCase(_ name: String) -> String {
        let base = SwiftIdentifierSanitizer.sanitizePascalCase(name, fallback: "")
        return base.isEmpty ? "WorkflowCommand" : base + "Command"
    }

    /// Emits a complete Swift source file containing ArgumentParser commands for each workflow in the specification.
    ///
    /// - Parameters:
    ///   - specification: The parsed Arazzo 1.1.0 specification.
    ///   - rootCommandName: Command name for the root CLI tool. Defaults to `"workflow"`.
    /// - Returns: Generated Swift source code string.
    public static func emitWorkflowCLI(from specification: ArazzoSpecification, rootCommandName: String = "workflow") -> String {
        var output = ""
        output += "import ArgumentParser\n"
        output += "import Foundation\n\n"

        output += emitRootCommand(specification: specification, rootCommandName: rootCommandName)
        output += "\n\n"

        for workflow in specification.workflows {
            output += emitWorkflowSubcommand(workflow: workflow)
            output += "\n\n"
        }

        output += emitOutputFormatterHelper()
        return output
    }

    /// Emits the root ArgumentParser command dispatching to individual workflow subcommands.
    ///
    /// - Parameters:
    ///   - specification: The Arazzo specification.
    ///   - rootCommandName: Name of the root command.
    /// - Returns: Swift source code for root command.
    private static func emitRootCommand(specification: ArazzoSpecification, rootCommandName: String) -> String {
        let subcommands = specification.workflows.map { pascalCase($0.workflowId) + ".self" }
        var code = ""
        code += "@main\n"
        code += "/// Root entry point command dispatching Arazzo workflow runs.\n"
        code += "public struct WorkflowCLI: AsyncParsableCommand {\n"
        code += "    /// The CommandConfiguration for the root CLI.\n"
        code += "    public static let configuration = CommandConfiguration(\n"
        code += "        commandName: \"" + rootCommandName + "\",\n"
        code += "        abstract: \"" + specification.info.title + " Workflows CLI\",\n"
        code += "        version: \"" + specification.info.version + "\",\n"
        code += "        subcommands: [" + subcommands.joined(separator: ", ") + "]\n"
        code += "    )\n\n"
        code += "    /// Initializes the command.\n"
        code += "    public init() {}\n"
        code += "}\n"
        return code
    }

    /// Emits an ArgumentParser command for an individual Arazzo workflow.
    ///
    /// - Parameter workflow: The workflow to emit a command for.
    /// - Returns: Swift command struct definition.
    private static func emitWorkflowSubcommand(workflow: ArazzoWorkflow) -> String {
        let structName = pascalCase(workflow.workflowId)
        let cmdName = kebabCase(workflow.workflowId)
        let summary = workflow.summary ?? ("Executes workflow " + workflow.workflowId)
        let baseName = ArazzoSdkEmitter.pascalCase(workflow.workflowId)
        let clientMethod = ArazzoSdkEmitter.sanitizeIdentifier(workflow.workflowId)

        var code = ""
        code += "/// CLI command executing workflow `" + workflow.workflowId + "`.\n"
        code += "public struct " + structName + ": AsyncParsableCommand {\n"
        code += "    /// The CommandConfiguration for this workflow.\n"
        code += "    public static let configuration = CommandConfiguration(\n"
        code += "        commandName: \"" + cmdName + "\",\n"
        code += "        abstract: \"" + summary + "\"\n"
        code += "    )\n\n"
        code += emitWorkflowOptionProperties(workflow: workflow)

        code += "    /// Initializes the workflow command.\n"
        code += "    public init() {}\n\n"

        code += "    /// Executes the workflow CLI command.\n"
        code += "    public mutating func run() async throws {\n"
        code += "        print(\"🚀 Executing workflow: " + workflow.workflowId + "...\")\n"
        code += "        let startTime = Date()\n"
        code += "        let client = WorkflowsClient()\n"

        if let schema = workflow.inputs, let props = schema.properties, !props.isEmpty {
            let initArgs = props.sorted(by: { $0.key < $1.key }).map { key, _ in
                let propId = ArazzoSdkEmitter.sanitizeIdentifier(key)
                return propId + ": " + propId
            }.joined(separator: ", ")
            code += "        let inputs = " + baseName + "Inputs(" + initArgs + ")\n"
        } else {
            code += "        let inputs = " + baseName + "Inputs()\n"
        }

        code += "        do {\n"
        code += "            let result = try await client." + clientMethod + "(inputs: inputs)\n"
        code += "            let duration = Date().timeIntervalSince(startTime)\n"
        code += "            print(\"✅ Workflow " + workflow.workflowId + " completed in \" + String(format: \"%.2fs\", duration))\n"
        code += "            WorkflowOutputFormatter.printOutputs(result.values, format: format)\n"
        code += "        } catch {\n"
        code += "            print(\"❌ Workflow failed: \" + error.localizedDescription)\n"
        code += "            throw error\n"
        code += "        }\n"
        code += "    }\n"
        code += "}\n"
        return code
    }

    /// Emits `@Option` and `@Flag` properties for a workflow CLI subcommand.
    ///
    /// - Parameter workflow: The workflow whose input schema is inspected.
    /// - Returns: Generated Swift property declarations.
    private static func emitWorkflowOptionProperties(workflow: ArazzoWorkflow) -> String {
        var code = ""
        if let schema = workflow.inputs, let props = schema.properties, !props.isEmpty {
            for (key, propSchema) in props.sorted(by: { $0.key < $1.key }) {
                let propId = ArazzoSdkEmitter.sanitizeIdentifier(key)
                let flagName = kebabCase(key)
                if propSchema.type == "boolean" {
                    code += "    /// Option flag for `" + key + "` parameter.\n"
                    code += "    @Flag(name: .customLong(\"" + flagName + "\"), help: \"Enable " + key + "\")\n"
                    code += "    public var " + propId + ": Bool = false\n\n"
                } else {
                    let type = propSchema.type == "integer" ? "Int" : (propSchema.type == "number" ? "Double" : "String")
                    code += "    /// Option value for `" + key + "` parameter.\n"
                    code += "    @Option(name: .customLong(\"" + flagName + "\"), help: \"The " + key + " value\")\n"
                    code += "    public var " + propId + ": " + type + "?\n\n"
                }
            }
        }

        code += "    /// Output format style: json, yaml, or table.\n"
        code += "    @Option(name: .customLong(\"format\"), help: \"Output format style: json, yaml, or table\")\n"
        code += "    public var format: String = \"json\"\n\n"

        code += "    /// Maximum retry attempts override.\n"
        code += "    @Option(name: .customLong(\"retry-limit\"), help: \"Maximum retry attempts override\")\n"
        code += "    public var retryLimit: Int?\n\n"

        code += "    /// Enable verbose progress and step output logs.\n"
        code += "    @Flag(name: .customLong(\"verbose\"), help: \"Enable verbose progress and step output logs\")\n"
        code += "    public var verbose: Bool = false\n\n"
        return code
    }

    /// Emits helper formatter class supporting `--format json|yaml|table`.
    ///
    /// - Returns: Swift helper definition.
    private static func emitOutputFormatterHelper() -> String {
        var code = ""
        code += "/// Helper formatting workflow stdout output variables into JSON, YAML, or ASCII table.\n"
        code += "public enum WorkflowOutputFormatter {\n"
        code += "    /// Prints dictionary outputs formatted according to requested style.\n"
        code += "    ///\n"
        code += "    /// - Parameters:\n"
        code += "    ///   - outputs: Key-value output dictionary.\n"
        code += "    ///   - format: Desired output style (json, yaml, table).\n"
        code += "    public static func printOutputs(_ outputs: [String: AnyCodable], format: String) {\n"
        code += "        switch format.lowercased() {\n"
        code += "        case \"table\":\n"
        code += "            print(\"----------------------------------------\")\n"
        code += "            print(\"OUTPUT KEY               | VALUE\")\n"
        code += "            print(\"----------------------------------------\")\n"
        code += "            for (k, v) in outputs.sorted(by: { $0.key < $1.key }) {\n"
        code += "                print(k.padding(toLength: 24, withPad: \" \", startingAt: 0) + \"| \" + String(describing: v.value))\n"
        code += "            }\n"
        code += "            print(\"----------------------------------------\")\n"
        code += "        case \"yaml\":\n"
        code += "            for (k, v) in outputs.sorted(by: { $0.key < $1.key }) {\n"
        code += "                print(k + \": \" + String(describing: v.value))\n"
        code += "            }\n"
        code += "        default:\n"
        code += "            let encoder = JSONEncoder()\n"
        code += "            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]\n"
        code += "            if let data = try? encoder.encode(outputs),\n"
        code += "               let str = String(data: data, encoding: .utf8) {\n"
        code += "                print(str)\n"
        code += "            } else {\n"
        code += "                print(String(describing: outputs))\n"
        code += "            }\n"
        code += "        }\n"
        code += "    }\n"
        code += "}\n"
        return code
    }
}
