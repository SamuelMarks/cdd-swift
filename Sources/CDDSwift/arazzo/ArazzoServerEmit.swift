/// Server-side synthetic workflow driver and healthcheck probe emitter for Arazzo 1.1.0 specifications.
import Foundation

/// Code emitter generating server-side synthetic workflow drivers and healthcheck probe orchestrators for Vapor and Hummingbird backends.
public enum ArazzoServerEmitter {
    /// Emits a server-side workflow orchestrator and synthetic healthcheck probe controller from an `ArazzoSpecification`.
    ///
    /// - Parameters:
    ///   - specification: The parsed Arazzo 1.1.0 specification.
    ///   - className: Name of the generated server probe orchestrator class. Defaults to `"ServerWorkflowOrchestrator"`.
    /// - Returns: Generated Swift server orchestrator source code.
    public static func emitServerOrchestrator(from specification: ArazzoSpecification,
                                              className: String = "ServerWorkflowOrchestrator") -> String {
        let nl = String(UnicodeScalar(10))
        let q = String(UnicodeScalar(34))
        var lines: [String] = emitProbeReportStructLines()
        lines.append("")
        lines.append("/// Server-side synthetic workflow driver and healthcheck probe orchestrator for `" + specification.info.title + "`.")
        lines.append("public final class " + className + ": Sendable {")
        lines.append("    /// Underlying workflow client used to drive synthetic transactions.")
        lines.append("    public let workflowsClient: WorkflowsClient")
        lines.append("")
        lines.append("    /// Initializes the server workflow probe orchestrator.")
        lines.append("    ///")
        lines.append("    /// - Parameter workflowsClient: The workflow client instance.")
        lines.append("    public init(workflowsClient: WorkflowsClient = WorkflowsClient()) {")
        lines.append("        self.workflowsClient = workflowsClient")
        lines.append("    }")
        lines.append("")
        lines.append("    /// Executes all registered synthetic workflow probes and returns their diagnostic health reports.")
        lines.append("    ///")
        lines.append("    /// - Returns: Array of `WorkflowProbeReport` results.")
        lines.append("    public func runAllProbes() async -> [WorkflowProbeReport] {")
        lines.append("        var reports: [WorkflowProbeReport] = []")
        for workflow in specification.workflows {
            let probeMethod = "probe" + ArazzoSdkEmitter.pascalCase(workflow.workflowId)
            lines.append("        reports.append(await " + probeMethod + "())")
        }
        lines.append("        return reports")
        lines.append("    }")

        for workflow in specification.workflows {
            let probeMethod = "probe" + ArazzoSdkEmitter.pascalCase(workflow.workflowId)
            let clientMethod = ArazzoSdkEmitter.sanitizeIdentifier(workflow.workflowId)
            let baseName = ArazzoSdkEmitter.pascalCase(workflow.workflowId)
            lines.append("")
            lines.append("    /// Runs synthetic probe for workflow `" + workflow.workflowId + "`.")
            lines.append("    ///")
            lines.append("    /// - Returns: A `WorkflowProbeReport` summarizing probe status.")
            lines.append("    public func " + probeMethod + "() async -> WorkflowProbeReport {")
            lines.append("        do {")
            lines.append("            let res = try await workflowsClient." + clientMethod + "(inputs: " + baseName + "Inputs())")
            lines
                .append("            return WorkflowProbeReport(workflowId: " + q + workflow
                    .workflowId + q + ", healthy: true, executedSteps: " + String(workflow.steps.count) + ", outputs: res.values)")
            lines.append("        } catch {")
            lines
                .append("            return WorkflowProbeReport(workflowId: " + q + workflow
                    .workflowId + q + ", healthy: false, executedSteps: 0, outputs: [:])")
            lines.append("        }")
            lines.append("    }")
        }

        lines.append("}")
        return lines.joined(separator: nl) + nl
    }

    /// Emits the header and `WorkflowProbeReport` struct declaration lines.
    ///
    /// - Returns: Array of Swift source lines defining `WorkflowProbeReport`.
    private static func emitProbeReportStructLines() -> [String] {
        return [
            "import Foundation",
            "",
            "/// Diagnostic status report for a synthetic workflow healthcheck probe.",
            "public struct WorkflowProbeReport: Codable, Sendable, Equatable {",
            "    /// The identifier of the executed workflow.",
            "    public let workflowId: String",
            "    /// Indicates whether all steps in the workflow succeeded.",
            "    public let healthy: Bool",
            "    /// Number of steps executed during the probe.",
            "    public let executedSteps: Int",
            "    /// Captured workflow output values.",
            "    public let outputs: [String: AnyCodable]",
            "",
            "    /// Initializes a new `WorkflowProbeReport`.",
            "    public init(workflowId: String, healthy: Bool, executedSteps: Int, outputs: [String: AnyCodable]) {",
            "        self.workflowId = workflowId",
            "        self.healthy = healthy",
            "        self.executedSteps = executedSteps",
            "        self.outputs = outputs",
            "    }",
            "}"
        ]
    }
}
