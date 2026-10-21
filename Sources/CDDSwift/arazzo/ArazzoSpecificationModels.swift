/// Root specification, workflow, and reusable component models for Arazzo 1.1.0 documents.
import Foundation

/// Represents an executable multi-step workflow in an Arazzo specification.
public struct ArazzoWorkflow: Codable, Sendable, Equatable {
    /// Unique identifier for the workflow.
    public let workflowId: String
    /// Short summary of the workflow.
    public let summary: String?
    /// Detailed description of the workflow.
    public let description: String?
    /// JSON Schema defining required and optional input arguments for the workflow.
    public let inputs: Schema?
    /// List of prerequisite workflow IDs that must execute prior to this workflow.
    public let dependsOn: [String]?
    /// Ordered array of steps composing the workflow pipeline.
    public let steps: [ArazzoStep]
    /// Workflow-level success branch handlers.
    public let successActions: [ArazzoSuccessAction]?
    /// Workflow-level failure recovery policies.
    public let failureActions: [ArazzoFailureAction]?
    /// Strongly typed return value mappings.
    public let outputs: [String: AnyCodable]?
    /// Common parameter defaults injected into steps.
    public let parameters: [ArazzoParameter]?

    /// Initializes a new `ArazzoWorkflow`.
    ///
    /// - Parameters:
    ///   - workflowId: Unique workflow identifier.
    ///   - summary: Short summary string.
    ///   - description: Markdown documentation string.
    ///   - inputs: Method input schema.
    ///   - dependsOn: Prerequisite workflow IDs.
    ///   - steps: Workflow step pipeline.
    ///   - successActions: Workflow success handlers.
    ///   - failureActions: Workflow failure handlers.
    ///   - outputs: Output variable mappings.
    ///   - parameters: Shared parameters.
    public init(
        workflowId: String,
        summary: String? = nil,
        description: String? = nil,
        inputs: Schema? = nil,
        dependsOn: [String]? = nil,
        steps: [ArazzoStep],
        successActions: [ArazzoSuccessAction]? = nil,
        failureActions: [ArazzoFailureAction]? = nil,
        outputs: [String: AnyCodable]? = nil,
        parameters: [ArazzoParameter]? = nil
    ) {
        self.workflowId = workflowId
        self.summary = summary
        self.description = description
        self.inputs = inputs
        self.dependsOn = dependsOn
        self.steps = steps
        self.successActions = successActions
        self.failureActions = failureActions
        self.outputs = outputs
        self.parameters = parameters
    }
}

/// Reusable definitions container within an Arazzo document.
public struct ArazzoComponents: Codable, Sendable, Equatable {
    /// Shared input schema DTOs.
    public let inputs: [String: Schema]?
    /// Shared parameter templates.
    public let parameters: [String: ArazzoParameter]?
    /// Shared success action handlers.
    public let successActions: [String: ArazzoSuccessAction]?
    /// Shared failure action handlers.
    public let failureActions: [String: ArazzoFailureAction]?

    /// Initializes a new `ArazzoComponents` registry.
    ///
    /// - Parameters:
    ///   - inputs: Reusable input schemas.
    ///   - parameters: Reusable parameters.
    ///   - successActions: Reusable success actions.
    ///   - failureActions: Reusable failure actions.
    public init(
        inputs: [String: Schema]? = nil,
        parameters: [String: ArazzoParameter]? = nil,
        successActions: [String: ArazzoSuccessAction]? = nil,
        failureActions: [String: ArazzoFailureAction]? = nil
    ) {
        self.inputs = inputs
        self.parameters = parameters
        self.successActions = successActions
        self.failureActions = failureActions
    }
}

/// The root specification object representing an Arazzo 1.1.0 document.
public struct ArazzoSpecification: Codable, Sendable, Equatable {
    /// The semantic version string (`1.1.0`).
    public let arazzo: String
    /// Canonical self URI for relative reference resolution.
    public let selfRef: String?
    /// Document metadata and descriptive information.
    public let info: ArazzoInfo
    /// Specifications referenced by operations in workflows.
    public let sourceDescriptions: [ArazzoSourceDescription]
    /// Executable workflow definitions.
    public let workflows: [ArazzoWorkflow]
    /// Reusable component registry.
    public let components: ArazzoComponents?

    /// The CodingKeys for ArazzoSpecification.
    enum CodingKeys: String, CodingKey {
        /// Key for the `arazzo` specification version field.
        case arazzo
        /// Key for the `$self` canonical document URI field.
        case selfRef = "$self"
        /// Key for the `info` metadata object.
        case info
        /// Key for the `sourceDescriptions` list.
        case sourceDescriptions
        /// Key for the `workflows` list.
        case workflows
        /// Key for the `components` registry object.
        case components
    }

    /// Initializes a new `ArazzoSpecification` root document.
    ///
    /// - Parameters:
    ///   - arazzo: Specification version string (defaults to `"1.1.0"`).
    ///   - selfRef: Canonical self URI.
    ///   - info: Metadata info header.
    ///   - sourceDescriptions: Linked target specification sources.
    ///   - workflows: Array of executable workflows.
    ///   - components: Reusable definitions registry.
    public init(
        arazzo: String = "1.1.0",
        selfRef: String? = nil,
        info: ArazzoInfo,
        sourceDescriptions: [ArazzoSourceDescription],
        workflows: [ArazzoWorkflow],
        components: ArazzoComponents? = nil
    ) {
        self.arazzo = arazzo
        self.selfRef = selfRef
        self.info = info
        self.sourceDescriptions = sourceDescriptions
        self.workflows = workflows
        self.components = components
    }
}
