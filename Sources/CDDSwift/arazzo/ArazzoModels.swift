/// Data models representing Arazzo 1.1.0 workflow specifications, steps, criteria, and actions.
import Foundation

/// Defines the source type for target APIs linked in an Arazzo document.
public enum ArazzoSourceType: String, Codable, Sendable, Equatable {
    /// OpenAPI document reference.
    case openapi
    /// AsyncAPI document reference.
    case asyncapi
    /// Referenced external Arazzo document.
    case arazzo
}

/// Defines parameter placement locations supported by Arazzo 1.1.0.
public enum ArazzoParameterLocation: String, Codable, Sendable, Equatable {
    /// Path variable replacement.
    case path
    /// URL query parameter.
    case query
    /// HTTP request header.
    case header
    /// Cookie header value.
    case cookie
}

/// Defines the condition evaluation dialect for Arazzo criteria.
public enum ArazzoCriterionType: String, Codable, Sendable, Equatable {
    /// Simple equality or standard comparison.
    case simple
    /// Regular expression pattern matching.
    case regex
    /// RFC 9535 JSONPath expression.
    case jsonpath
    /// W3C XPath expression.
    case xpath
}

/// Defines flow primitive actions triggered upon successful step execution.
public enum ArazzoSuccessActionType: String, Codable, Sendable, Equatable {
    /// Concludes the workflow or sequence.
    case end
    /// Directs execution flow to jump to a specific step or workflow.
    case goto
}

/// Defines recovery and flow actions triggered upon step execution failure.
public enum ArazzoFailureActionType: String, Codable, Sendable, Equatable {
    /// Terminates execution reporting a failure.
    case end
    /// Retries the current step under specified backoff rules.
    case retry
    /// Jumps to an alternative recovery step or workflow.
    case goto
}

/// Defines asynchronous message operations in Arazzo workflows.
public enum ArazzoAsyncAction: String, Codable, Sendable, Equatable {
    /// Publishes a message to a channel.
    case send
    /// Waits for and receives a message from a channel.
    case receive
}

/// Defines dialect selectors for payload replacements.
public enum ArazzoTargetSelectorType: String, Codable, Sendable, Equatable {
    /// RFC 6901 JSON Pointer.
    case jsonpointer
    /// RFC 9535 JSONPath.
    case jsonpath
    /// W3C XPath query.
    case xpath
}

/// Metadata and documentation for an Arazzo specification document.
public struct ArazzoInfo: Codable, Sendable, Equatable {
    /// The title of the workflow suite.
    public let title: String
    /// A short summary of the workflow suite purpose.
    public let summary: String?
    /// Extended Markdown documentation for the workflow suite.
    public let description: String?
    /// The version of the workflow document.
    public let version: String

    /// Initializes a new `ArazzoInfo` metadata object.
    ///
    /// - Parameters:
    ///   - title: The title of the workflow suite.
    ///   - summary: A short summary of the workflow suite purpose.
    ///   - description: Extended Markdown documentation.
    ///   - version: The version of the workflow document.
    public init(title: String, summary: String? = nil, description: String? = nil, version: String) {
        self.title = title
        self.summary = summary
        self.description = description
        self.version = version
    }
}

/// Defines an external specification source (OpenAPI, AsyncAPI, or Arazzo) utilized by workflows.
public struct ArazzoSourceDescription: Codable, Sendable, Equatable {
    /// A unique local identifier for the source description.
    public let name: String
    /// The location URL or file path of the source specification.
    public let url: String
    /// The type of the source specification (`openapi`, `asyncapi`, or `arazzo`).
    public let type: ArazzoSourceType

    /// Initializes a new `ArazzoSourceDescription`.
    ///
    /// - Parameters:
    ///   - name: A unique local identifier.
    ///   - url: Location URL or relative path.
    ///   - type: Specification type.
    public init(name: String, url: String, type: ArazzoSourceType) {
        self.name = name
        self.url = url
        self.type = type
    }
}

/// Represents an operation argument or context parameter in an Arazzo workflow or step.
public struct ArazzoParameter: Codable, Sendable, Equatable {
    /// The name of the parameter.
    public let name: String
    /// The location where the parameter must be injected (`path`, `query`, `header`, `cookie`).
    public let `in`: ArazzoParameterLocation
    /// The value or dynamic expression for the parameter.
    public let value: AnyCodable

    /// Initializes a new `ArazzoParameter`.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - in: The parameter location.
    ///   - value: The parameter value or dynamic expression.
    public init(name: String, in: ArazzoParameterLocation, value: AnyCodable) {
        self.name = name
        self.in = `in`
        self.value = value
    }
}

/// An assertion condition evaluated against runtime response data or execution state.
public struct ArazzoCriterion: Codable, Sendable, Equatable {
    /// The context expression evaluated (e.g. `$statusCode` or `$response.body`).
    public let context: String
    /// The condition or expected match expression.
    public let condition: String
    /// The condition syntax dialect (`simple`, `regex`, `jsonpath`, `xpath`).
    public let type: ArazzoCriterionType?

    /// Initializes a new `ArazzoCriterion`.
    ///
    /// - Parameters:
    ///   - context: The evaluation context expression.
    ///   - condition: The condition expression.
    ///   - type: The condition dialect.
    public init(context: String, condition: String, type: ArazzoCriterionType? = nil) {
        self.context = context
        self.condition = condition
        self.type = type
    }
}

/// State transition triggered when a step satisfies its success criteria.
public struct ArazzoSuccessAction: Codable, Sendable, Equatable {
    /// The human-readable name of the action.
    public let name: String
    /// The action primitive type (`end` or `goto`).
    public let type: ArazzoSuccessActionType
    /// Target workflow ID to jump to when type is `goto`.
    public let workflowId: String?
    /// Target step ID within current workflow to jump to when type is `goto`.
    public let stepId: String?
    /// Parameters passed to the target workflow.
    public let parameters: [ArazzoParameter]?
    /// Guard conditions required before triggering this action.
    public let criteria: [ArazzoCriterion]?

    /// Initializes a new `ArazzoSuccessAction`.
    ///
    /// - Parameters:
    ///   - name: The action name.
    ///   - type: The action primitive type.
    ///   - workflowId: Optional target workflow ID.
    ///   - stepId: Optional target step ID.
    ///   - parameters: Optional forwarded parameters.
    ///   - criteria: Optional guard conditions.
    public init(
        name: String,
        type: ArazzoSuccessActionType,
        workflowId: String? = nil,
        stepId: String? = nil,
        parameters: [ArazzoParameter]? = nil,
        criteria: [ArazzoCriterion]? = nil
    ) {
        self.name = name
        self.type = type
        self.workflowId = workflowId
        self.stepId = stepId
        self.parameters = parameters
        self.criteria = criteria
    }
}

/// Failure recovery policy triggered when a step fails assertion checks or transport calls.
public struct ArazzoFailureAction: Codable, Sendable, Equatable {
    /// The human-readable name of the failure action.
    public let name: String
    /// The failure action primitive (`end`, `retry`, or `goto`).
    public let type: ArazzoFailureActionType
    /// Target recovery workflow ID when type is `goto`.
    public let workflowId: String?
    /// Target fallback step ID when type is `goto`.
    public let stepId: String?
    /// Parameters passed to recovery workflow.
    public let parameters: [ArazzoParameter]?
    /// Backoff delay in seconds before attempting retry.
    public let retryAfter: Double?
    /// Maximum retry attempts before giving up.
    public let retryLimit: Int?
    /// Error condition guards triggering this action.
    public let criteria: [ArazzoCriterion]?

    /// Initializes a new `ArazzoFailureAction`.
    ///
    /// - Parameters:
    ///   - name: The action name.
    ///   - type: The action type.
    ///   - workflowId: Target workflow ID.
    ///   - stepId: Fallback step ID.
    ///   - parameters: Parameters passed to target.
    ///   - retryAfter: Retry backoff delay in seconds.
    ///   - retryLimit: Maximum retry attempts.
    ///   - criteria: Error condition filters.
    public init(
        name: String,
        type: ArazzoFailureActionType,
        workflowId: String? = nil,
        stepId: String? = nil,
        parameters: [ArazzoParameter]? = nil,
        retryAfter: Double? = nil,
        retryLimit: Int? = nil,
        criteria: [ArazzoCriterion]? = nil
    ) {
        self.name = name
        self.type = type
        self.workflowId = workflowId
        self.stepId = stepId
        self.parameters = parameters
        self.retryAfter = retryAfter
        self.retryLimit = retryLimit
        self.criteria = criteria
    }
}

/// Modifies a targeted node in a request body prior to sending.
public struct ArazzoPayloadReplacement: Codable, Sendable, Equatable {
    /// Pointer or selector targeting the field to replace.
    public let target: String
    /// Dialect used for the target selector.
    public let targetSelectorType: ArazzoTargetSelectorType?
    /// The replacement value or runtime expression.
    public let value: AnyCodable

    /// Initializes a new `ArazzoPayloadReplacement`.
    ///
    /// - Parameters:
    ///   - target: Target property selector.
    ///   - targetSelectorType: Target selector dialect.
    ///   - value: Replacement value.
    public init(target: String, targetSelectorType: ArazzoTargetSelectorType? = nil, value: AnyCodable) {
        self.target = target
        self.targetSelectorType = targetSelectorType
        self.value = value
    }
}

/// Payload specification for an HTTP request in an Arazzo step.
public struct ArazzoRequestBody: Codable, Sendable, Equatable {
    /// The content MIME type for the request.
    public let contentType: String?
    /// The raw or structured payload template.
    public let payload: AnyCodable?
    /// In-place payload modification rules.
    public let replacements: [ArazzoPayloadReplacement]?

    /// Initializes a new `ArazzoRequestBody`.
    ///
    /// - Parameters:
    ///   - contentType: The HTTP Content-Type.
    ///   - payload: The base payload template.
    ///   - replacements: In-place field replacement rules.
    public init(contentType: String? = nil, payload: AnyCodable? = nil, replacements: [ArazzoPayloadReplacement]? = nil) {
        self.contentType = contentType
        self.payload = payload
        self.replacements = replacements
    }
}

/// Represents an individual invocation step in an Arazzo workflow.
public struct ArazzoStep: Codable, Sendable, Equatable {
    /// Unique identifier for the step within its workflow.
    public let stepId: String
    /// Human-readable description of what the step executes.
    public let description: String?
    /// Target operation identifier from a linked OpenAPI specification.
    public let operationId: String?
    /// JSON Pointer path to an operation within a linked OpenAPI document.
    public let operationPath: String?
    /// Channel path in an AsyncAPI source description.
    public let channelPath: String?
    /// Identifier of a nested or sibling workflow invoked by this step.
    public let workflowId: String?
    /// Parameters mapped for this step call.
    public let parameters: [ArazzoParameter]?
    /// Request body payload definition for this step.
    public let requestBody: ArazzoRequestBody?
    /// Assertions verifying step completion.
    public let successCriteria: [ArazzoCriterion]?
    /// State transitions executed when assertions pass.
    public let onSuccess: [ArazzoSuccessAction]?
    /// Recovery actions executed when assertions or transport fail.
    public let onFailure: [ArazzoFailureAction]?
    /// Extracted output variables captured into workflow state.
    public let outputs: [String: AnyCodable]?
    /// Execution timeout limit in milliseconds.
    public let timeout: Int?
    /// Correlation tracking identifier for async messaging.
    public let correlationId: String?
    /// Message action type (`send` or `receive`).
    public let action: ArazzoAsyncAction?
    /// Step prerequisite dependencies.
    public let dependsOn: [String]?

    /// Initializes a new `ArazzoStep`.
    ///
    /// - Parameters:
    ///   - stepId: Unique step identifier.
    ///   - description: Step documentation label.
    ///   - operationId: Target OpenAPI operationId.
    ///   - operationPath: Target OpenAPI JSON Pointer.
    ///   - channelPath: Target AsyncAPI channel.
    ///   - workflowId: Sub-workflow identifier.
    ///   - parameters: Step parameter mappings.
    ///   - requestBody: Request body template.
    ///   - successCriteria: Assertion conditions.
    ///   - onSuccess: Success branch transitions.
    ///   - onFailure: Failure recovery actions.
    ///   - outputs: Output variable mappings.
    ///   - timeout: Execution timeout in milliseconds.
    ///   - correlationId: Message correlation identifier.
    ///   - action: Async message flow direction.
    ///   - dependsOn: Prerequisite step IDs.
    public init(
        stepId: String,
        description: String? = nil,
        operationId: String? = nil,
        operationPath: String? = nil,
        channelPath: String? = nil,
        workflowId: String? = nil,
        parameters: [ArazzoParameter]? = nil,
        requestBody: ArazzoRequestBody? = nil,
        successCriteria: [ArazzoCriterion]? = nil,
        onSuccess: [ArazzoSuccessAction]? = nil,
        onFailure: [ArazzoFailureAction]? = nil,
        outputs: [String: AnyCodable]? = nil,
        timeout: Int? = nil,
        correlationId: String? = nil,
        action: ArazzoAsyncAction? = nil,
        dependsOn: [String]? = nil
    ) {
        self.stepId = stepId
        self.description = description
        self.operationId = operationId
        self.operationPath = operationPath
        self.channelPath = channelPath
        self.workflowId = workflowId
        self.parameters = parameters
        self.requestBody = requestBody
        self.successCriteria = successCriteria
        self.onSuccess = onSuccess
        self.onFailure = onFailure
        self.outputs = outputs
        self.timeout = timeout
        self.correlationId = correlationId
        self.action = action
        self.dependsOn = dependsOn
    }
}

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
