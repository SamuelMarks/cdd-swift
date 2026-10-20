/// Model Context Protocol (MCP) content, logging, prompt, root, completion, and sampling models.
import Foundation

// MARK: - Core Types

/// Opaque pagination cursor token used across paginated MCP requests and responses.
public typealias Cursor = String
/// Alias for a JSON-RPC request identifier (`JSONRPCId`).
public typealias RequestId = JSONRPCId

/// Metadata annotations describing target audience and relative priority for MCP content or resources.
public struct Annotations: Codable, Equatable, Sendable {
    /// Target roles (`user` or `assistant`) for which the annotated item is intended.
    public let audience: [Role]?
    /// Relative importance score ranging from `0.0` (least important) to `1.0` (most important).
    public let priority: Double?

    /// Initializes `Annotations`.
    ///
    /// - Parameters:
    ///   - audience: Optional array of intended `Role` recipients.
    ///   - priority: Optional importance score in `0.0 ... 1.0`.
    public init(audience: [Role]? = nil, priority: Double? = nil) {
        self.audience = audience
        self.priority = priority
    }
}

/// Wrapper struct carrying optional `Annotations` metadata.
public struct Annotated: Codable, Equatable, Sendable {
    /// Optional audience and priority annotations.
    public let annotations: Annotations?

    /// Initializes an `Annotated` value.
    ///
    /// - Parameter annotations: Optional `Annotations` metadata.
    public init(annotations: Annotations? = nil) {
        self.annotations = annotations
    }
}

/// Conversational participant role in MCP prompts and sampling messages.
public enum Role: String, Codable, Equatable, Sendable {
    /// Human user participant role.
    case user
    /// AI assistant participant role.
    case assistant
}

// MARK: - Notifications

/// Parameters for a `notifications/cancelled` notification aborting an in-flight request.
public struct CancelledNotificationParams: Codable, Equatable, Sendable {
    /// The `RequestId` of the in-flight request to cancel.
    public let requestId: RequestId
    /// Optional human-readable explanation for why the request was cancelled.
    public let reason: String?

    /// Initializes `CancelledNotificationParams`.
    ///
    /// - Parameters:
    ///   - requestId: The identifier of the request being cancelled.
    ///   - reason: Optional cancellation reason string.
    public init(requestId: RequestId, reason: String? = nil) {
        self.requestId = requestId
        self.reason = reason
    }
}

/// Parameters for a `notifications/progress` notification reporting incremental progress.
public struct ProgressNotificationParams: Codable, Equatable, Sendable {
    /// The `ProgressToken` originally provided in the request's `_meta`.
    public let progressToken: ProgressToken
    /// Current numeric progress value completed so far.
    public let progress: Double
    /// Optional total expected numeric progress value.
    public let total: Double?

    /// Initializes `ProgressNotificationParams`.
    ///
    /// - Parameters:
    ///   - progressToken: The correlating `ProgressToken`.
    ///   - progress: Current completed progress amount.
    ///   - total: Optional total progress target.
    public init(progressToken: ProgressToken, progress: Double, total: Double? = nil) {
        self.progressToken = progressToken
        self.progress = progress
        self.total = total
    }
}

/// Typealias for a client-originated JSON-RPC notification carrying an `AnyCodable` payload.
public typealias ClientNotification = JSONRPCNotification<AnyCodable>
/// Typealias for a server-originated JSON-RPC notification carrying an `AnyCodable` payload.
public typealias ServerNotification = JSONRPCNotification<AnyCodable>

// MARK: - Requests & Results

/// Typealias for a client-originated JSON-RPC request carrying an `AnyCodable` payload.
public typealias ClientRequest = JSONRPCRequest<AnyCodable>
/// Typealias for a client-originated JSON-RPC response carrying an `AnyCodable` payload.
public typealias ClientResult = JSONRPCResponse<AnyCodable>

/// Typealias for a server-originated JSON-RPC request carrying an `AnyCodable` payload.
public typealias ServerRequest = JSONRPCRequest<AnyCodable>
/// Typealias for a server-originated JSON-RPC response carrying an `AnyCodable` payload.
public typealias ServerResult = JSONRPCResponse<AnyCodable>

/// Base parameters structure for paginated MCP list requests.
public struct PaginatedRequestParams: Codable, Equatable, Sendable {
    /// Optional pagination cursor from a previous page response.
    public let cursor: Cursor?

    /// Initializes `PaginatedRequestParams`.
    ///
    /// - Parameter cursor: Optional pagination cursor string.
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

/// Base result structure for paginated MCP list responses.
public struct PaginatedResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Optional cursor for fetching the next page of results.
    public let nextCursor: Cursor?

    /// Initializes a `PaginatedResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - nextCursor: Optional cursor for the next page.
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil) {
        self._meta = _meta
        self.nextCursor = nextCursor
    }
}

/// Parameters for an MCP `ping` liveness request.
public struct PingRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?

    /// Initializes `PingRequestParams`.
    ///
    /// - Parameter _meta: Optional request metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Content Types

/// Plain or formatted text content block used in prompt messages and tool results.
public struct TextContent: Codable, Equatable, Sendable {
    /// Discriminator tag, always `"text"`.
    public var type = "text"
    /// The text payload.
    public let text: String
    /// Optional audience and priority annotations.
    public let annotations: Annotations?

    /// Initializes a `TextContent` block.
    ///
    /// - Parameters:
    ///   - text: The UTF-8 text content.
    ///   - annotations: Optional `Annotations` metadata.
    public init(text: String, annotations: Annotations? = nil) {
        self.text = text
        self.annotations = annotations
    }
}

/// Base64-encoded image content block used in prompt messages and tool results.
public struct ImageContent: Codable, Equatable, Sendable {
    /// Discriminator tag, always `"image"`.
    public var type = "image"
    /// Base64-encoded image bytes.
    public let data: String
    /// MIME type of the image (e.g. `"image/png"`, `"image/jpeg"`).
    public let mimeType: String
    /// Optional audience and priority annotations.
    public let annotations: Annotations?

    /// Initializes an `ImageContent` block.
    ///
    /// - Parameters:
    ///   - data: Base64-encoded image data string.
    ///   - mimeType: Image MIME type string.
    ///   - annotations: Optional `Annotations` metadata.
    public init(data: String, mimeType: String, annotations: Annotations? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

/// Content block embedding a server `ResourceContents` item directly inside a message or tool result.
public struct EmbeddedResource: Codable, Equatable, Sendable {
    /// Discriminator tag, always `"resource"`.
    public var type = "resource"
    /// The embedded text or binary resource contents.
    public let resource: ResourceContents
    /// Optional audience and priority annotations.
    public let annotations: Annotations?

    /// Initializes an `EmbeddedResource` content block.
    ///
    /// - Parameters:
    ///   - resource: The `ResourceContents` payload.
    ///   - annotations: Optional `Annotations` metadata.
    public init(resource: ResourceContents, annotations: Annotations? = nil) {
        self.resource = resource
        self.annotations = annotations
    }
}

// MARK: - Logging

/// Syslog-style severity levels for MCP server log messages.
public enum LoggingLevel: String, Codable, Equatable, Sendable {
    /// Detailed debugging information.
    case debug
    /// General informational messages.
    case info
    /// Normal but significant condition.
    case notice
    /// Warning condition.
    case warning
    /// Error condition.
    case error
    /// Critical condition.
    case critical
    /// Action must be taken immediately.
    case alert
    /// System is unusable.
    case emergency
}

/// Parameters for a `logging/setLevel` request configuring the minimum server log severity.
public struct SetLevelRequestParams: Codable, Equatable, Sendable {
    /// Minimum `LoggingLevel` the server should emit to the client.
    public let level: LoggingLevel

    /// Initializes `SetLevelRequestParams`.
    ///
    /// - Parameter level: The minimum `LoggingLevel` to enable.
    public init(level: LoggingLevel) {
        self.level = level
    }
}

/// Parameters for a `notifications/message` log notification sent by the server.
public struct LoggingMessageNotificationParams: Codable, Equatable, Sendable {
    /// Severity level of the log entry.
    public let level: LoggingLevel
    /// Optional name of the logger or subsystem emitting the message.
    public let logger: String?
    /// Arbitrary JSON-serializable log payload.
    public let data: AnyCodable

    /// Initializes `LoggingMessageNotificationParams`.
    ///
    /// - Parameters:
    ///   - level: Severity `LoggingLevel` of the message.
    ///   - logger: Optional logger subsystem name.
    ///   - data: Structured or string log payload wrapped in `AnyCodable`.
    public init(level: LoggingLevel, logger: String? = nil, data: AnyCodable) {
        self.level = level
        self.logger = logger
        self.data = data
    }
}

// MARK: - Prompts

/// Describes a template argument accepted by an MCP `Prompt`.
public struct PromptArgument: Codable, Equatable, Sendable {
    /// Name of the prompt argument.
    public let name: String
    /// Optional human-readable description of the argument.
    public let description: String?
    /// Whether this argument must be provided when instantiating the prompt.
    public let required: Bool?

    /// Initializes a `PromptArgument`.
    ///
    /// - Parameters:
    ///   - name: The argument identifier name.
    ///   - description: Optional explanation of the argument.
    ///   - required: Whether the argument is mandatory.
    public init(name: String, description: String? = nil, required: Bool? = nil) {
        self.name = name
        self.description = description
        self.required = required
    }
}

/// A reusable prompt template exposed by an MCP server.
public struct Prompt: Codable, Equatable, Sendable {
    /// Unique identifier name of the prompt template.
    public let name: String
    /// Optional human-readable description of what the prompt does.
    public let description: String?
    /// Optional list of template arguments used to customize the prompt.
    public let arguments: [PromptArgument]?

    /// Initializes a `Prompt` descriptor.
    ///
    /// - Parameters:
    ///   - name: Unique prompt name.
    ///   - description: Optional description of the prompt.
    ///   - arguments: Optional array of `PromptArgument` definitions.
    public init(name: String, description: String? = nil, arguments: [PromptArgument]? = nil) {
        self.name = name
        self.description = description
        self.arguments = arguments
    }
}

/// A single message within a resolved MCP prompt template.
public struct PromptMessage: Codable, Equatable, Sendable {
    /// Speaker role (`user` or `assistant`) for the message.
    public let role: Role
    /// Content payload (text, image, or embedded resource) of the message.
    public let content: PromptMessageContent

    /// Initializes a `PromptMessage`.
    ///
    /// - Parameters:
    ///   - role: The `Role` of the message author.
    ///   - content: The `PromptMessageContent` payload.
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

/// Union of content block types allowed inside a `PromptMessage` or `SamplingMessage`.
public enum PromptMessageContent: Codable, Equatable, Sendable {
    /// Text content block.
    case text(TextContent)
    /// Base64 image content block.
    case image(ImageContent)
    /// Embedded server resource content block.
    case resource(EmbeddedResource)

    /// Decodes `PromptMessageContent` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the payload does not match text, image, or resource content.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(TextContent.self) {
            self = .text(text)
        } else if let img = try? container.decode(ImageContent.self) {
            self = .image(img)
        } else if let res = try? container.decode(EmbeddedResource.self) {
            self = .resource(res)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid PromptMessageContent")
        }
    }

    /// Encodes `PromptMessageContent` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying content block cannot be encoded.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(t): try container.encode(t)
        case let .image(i): try container.encode(i)
        case let .resource(r): try container.encode(r)
        }
    }
}

/// Reference identifying a named MCP prompt template for argument auto-completion.
public struct PromptReference: Codable, Equatable, Sendable {
    /// Discriminator tag, always `"ref/prompt"`.
    public var type = "ref/prompt"
    /// Name of the referenced prompt template.
    public let name: String

    /// Initializes a `PromptReference`.
    ///
    /// - Parameter name: The target prompt name.
    public init(name: String) {
        self.name = name
    }
}

/// Parameters for a `prompts/get` request instantiating a named prompt template.
public struct GetPromptRequestParams: Codable, Equatable, Sendable {
    /// Name of the prompt template to retrieve.
    public let name: String
    /// Optional dictionary of template argument values keyed by argument name.
    public let arguments: [String: String]?

    /// Initializes `GetPromptRequestParams`.
    ///
    /// - Parameters:
    ///   - name: The prompt template name.
    ///   - arguments: Optional map of string arguments for template interpolation.
    public init(name: String, arguments: [String: String]? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// Result returned by the server in response to a `prompts/get` request.
public struct GetPromptResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Optional description of the instantiated prompt.
    public let description: String?
    /// Sequence of `PromptMessage` items comprising the prompt.
    public let messages: [PromptMessage]

    /// Initializes a `GetPromptResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - description: Optional prompt description.
    ///   - messages: Array of rendered `PromptMessage` items.
    public init(_meta: Meta? = nil, description: String? = nil, messages: [PromptMessage]) {
        self._meta = _meta
        self.description = description
        self.messages = messages
    }
}

/// Parameters for a paginated `prompts/list` request.
public struct ListPromptsRequestParams: Codable, Equatable, Sendable {
    /// Optional pagination cursor from a previous `ListPromptsResult`.
    public let cursor: Cursor?

    /// Initializes `ListPromptsRequestParams`.
    ///
    /// - Parameter cursor: Optional pagination cursor string.
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

/// Result returned by the server in response to a `prompts/list` request.
public struct ListPromptsResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Optional cursor for fetching the next page of prompts.
    public let nextCursor: Cursor?
    /// Array of available `Prompt` definitions.
    public let prompts: [Prompt]

    /// Initializes a `ListPromptsResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - nextCursor: Optional pagination cursor for the next page.
    ///   - prompts: Array of `Prompt` definitions.
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil, prompts: [Prompt]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.prompts = prompts
    }
}

/// Parameters for a `notifications/prompts/list_changed` notification.
public struct PromptListChangedNotificationParams: Codable, Equatable, Sendable {
    /// Optional notification metadata.
    public let _meta: Meta?

    /// Initializes `PromptListChangedNotificationParams`.
    ///
    /// - Parameter _meta: Optional notification metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Roots

/// Represents a filesystem or workspace root URI exposed by an MCP client to a server.
public struct Root: Codable, Equatable, Sendable {
    /// Canonical URI of the root (typically a `file://` URI).
    public let uri: String
    /// Optional human-readable display name for the root.
    public let name: String?

    /// Initializes a `Root` descriptor.
    ///
    /// - Parameters:
    ///   - uri: The root URI string.
    ///   - name: Optional display name for the workspace root.
    public init(uri: String, name: String? = nil) {
        self.uri = uri
        self.name = name
    }
}

/// Parameters for a server-initiated `roots/list` request querying client workspace roots.
public struct ListRootsRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?

    /// Initializes `ListRootsRequestParams`.
    ///
    /// - Parameter _meta: Optional request metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Result returned by the client in response to a `roots/list` request.
public struct ListRootsResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Array of `Root` descriptors exposed by the client.
    public let roots: [Root]

    /// Initializes a `ListRootsResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - roots: Array of `Root` descriptors.
    public init(_meta: Meta? = nil, roots: [Root]) {
        self._meta = _meta
        self.roots = roots
    }
}

/// Parameters for a `notifications/roots/list_changed` notification sent by the client.
public struct RootsListChangedNotificationParams: Codable, Equatable, Sendable {
    /// Optional notification metadata.
    public let _meta: Meta?

    /// Initializes `RootsListChangedNotificationParams`.
    ///
    /// - Parameter _meta: Optional notification metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Completion

/// Parameters for a `completion/complete` request requesting argument auto-completion suggestions.
public struct CompleteRequestParams: Codable, Equatable, Sendable {
    /// Reference to the prompt or resource template being completed.
    public let ref: CompleteReference
    /// The argument name and partial value to complete.
    public let argument: CompleteArgument

    /// Initializes `CompleteRequestParams`.
    ///
    /// - Parameters:
    ///   - ref: The `CompleteReference` identifying the prompt or resource.
    ///   - argument: The `CompleteArgument` containing the partial input.
    public init(ref: CompleteReference, argument: CompleteArgument) {
        self.ref = ref
        self.argument = argument
    }

    /// Describes the argument name and current partial text for a completion request.
    public struct CompleteArgument: Codable, Equatable, Sendable {
        /// Name of the argument being completed.
        public let name: String
        /// Current partial string value entered by the user.
        public let value: String

        /// Initializes a `CompleteArgument`.
        ///
        /// - Parameters:
        ///   - name: The argument name.
        ///   - value: The partial argument value string.
        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}

/// Reference to either a `PromptReference` or a `ResourceReference` in a completion request.
public enum CompleteReference: Codable, Equatable, Sendable {
    /// Reference to a named prompt template.
    case prompt(PromptReference)
    /// Reference to a resource or resource template URI.
    case resource(ResourceReference)

    /// Decodes a `CompleteReference` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the payload is neither a prompt reference nor a resource reference.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let p = try? container.decode(PromptReference.self) {
            self = .prompt(p)
        } else if let r = try? container.decode(ResourceReference.self) {
            self = .resource(r)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid CompleteReference")
        }
    }

    /// Encodes a `CompleteReference` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying reference cannot be encoded.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .prompt(p): try container.encode(p)
        case let .resource(r): try container.encode(r)
        }
    }
}

/// Reference identifying a resource or resource template URI for auto-completion.
public struct ResourceReference: Codable, Equatable, Sendable {
    /// Discriminator tag, always `"ref/resource"`.
    public var type = "ref/resource"
    /// Target resource URI or RFC 6570 URI template string.
    public let uri: String

    /// Initializes a `ResourceReference`.
    ///
    /// - Parameter uri: The resource URI or URI template string.
    public init(uri: String) {
        self.uri = uri
    }
}

/// Result returned by the server in response to a `completion/complete` request.
public struct CompleteResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Completion candidates and pagination metadata.
    public let completion: Completion

    /// Initializes a `CompleteResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - completion: The `Completion` payload.
    public init(_meta: Meta? = nil, completion: Completion) {
        self._meta = _meta
        self.completion = completion
    }

    /// Container holding auto-completion candidate strings and total count metadata.
    public struct Completion: Codable, Equatable, Sendable {
        /// Suggested completion values (up to 100 items).
        public let values: [String]
        /// Optional total number of matching completion candidates available.
        public let total: Int?
        /// Whether additional completion candidates exist beyond `values`.
        public let hasMore: Bool?

        /// Initializes a `Completion` payload.
        ///
        /// - Parameters:
        ///   - values: Array of suggested completion strings.
        ///   - total: Optional total number of matches.
        ///   - hasMore: Optional flag indicating more suggestions exist.
        public init(values: [String], total: Int? = nil, hasMore: Bool? = nil) {
            self.values = values
            self.total = total
            self.hasMore = hasMore
        }
    }
}

// MARK: - Sampling

/// A message included in a server-initiated `sampling/createMessage` LLM sampling request.
public struct SamplingMessage: Codable, Equatable, Sendable {
    /// Participant role (`user` or `assistant`).
    public let role: Role
    /// Content block of the message.
    public let content: PromptMessageContent

    /// Initializes a `SamplingMessage`.
    ///
    /// - Parameters:
    ///   - role: The `Role` of the speaker.
    ///   - content: The `PromptMessageContent` payload.
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

/// Hint suggesting a preferred LLM model name or family for sampling.
public struct ModelHint: Codable, Equatable, Sendable {
    /// Model name or substring hint (e.g. `"claude-3-5-sonnet"`).
    public let name: String

    /// Initializes a `ModelHint`.
    ///
    /// - Parameter name: Model identifier or family substring.
    public init(name: String) {
        self.name = name
    }
}

/// Server preferences guiding the client's model selection during `sampling/createMessage`.
public struct ModelPreferences: Codable, Equatable, Sendable {
    /// Ordered list of model name hints preferred by the server.
    public let hints: [ModelHint]?
    /// Relative importance of minimizing cost (`0.0 ... 1.0`).
    public let costPriority: Double?
    /// Relative importance of minimizing latency (`0.0 ... 1.0`).
    public let speedPriority: Double?
    /// Relative importance of reasoning/capability quality (`0.0 ... 1.0`).
    public let intelligencePriority: Double?

    /// Initializes `ModelPreferences`.
    ///
    /// - Parameters:
    ///   - hints: Optional array of `ModelHint` items.
    ///   - costPriority: Optional cost priority in `0.0 ... 1.0`.
    ///   - speedPriority: Optional latency priority in `0.0 ... 1.0`.
    ///   - intelligencePriority: Optional capability priority in `0.0 ... 1.0`.
    public init(hints: [ModelHint]? = nil, costPriority: Double? = nil, speedPriority: Double? = nil, intelligencePriority: Double? = nil) {
        self.hints = hints
        self.costPriority = costPriority
        self.speedPriority = speedPriority
        self.intelligencePriority = intelligencePriority
    }
}

/// Parameters for a server-initiated `sampling/createMessage` request asking the client to sample an LLM.
public struct CreateMessageRequestParams: Codable, Equatable, Sendable {
    /// Conversation history messages to provide to the model.
    public let messages: [SamplingMessage]
    /// Optional preferences for selecting the target model.
    public let modelPreferences: ModelPreferences?
    /// Optional system prompt instructions.
    public let systemPrompt: String?
    /// Optional context inclusion mode (`"none"`, `"thisServer"`, `"allServers"`).
    public let includeContext: String?
    /// Optional sampling temperature.
    public let temperature: Double?
    /// Maximum number of tokens to generate.
    public let maxTokens: Int
    /// Optional sequences that stop token generation when encountered.
    public let stopSequences: [String]?
    /// Optional provider-specific metadata parameters.
    public let metadata: [String: AnyCodable]?

    /// Initializes `CreateMessageRequestParams`.
    ///
    /// - Parameters:
    ///   - messages: Conversation messages to sample from.
    ///   - modelPreferences: Optional `ModelPreferences`.
    ///   - systemPrompt: Optional system prompt string.
    ///   - includeContext: Optional MCP context inclusion setting.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Maximum output tokens to sample.
    ///   - stopSequences: Optional stop sequence strings.
    ///   - metadata: Optional provider metadata dictionary.
    public init(messages: [SamplingMessage], modelPreferences: ModelPreferences? = nil, systemPrompt: String? = nil, includeContext: String? = nil, temperature: Double? = nil, maxTokens: Int, stopSequences: [String]? = nil, metadata: [String: AnyCodable]? = nil) {
        self.messages = messages
        self.modelPreferences = modelPreferences
        self.systemPrompt = systemPrompt
        self.includeContext = includeContext
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.metadata = metadata
    }
}

/// Result returned by the client in response to a `sampling/createMessage` request.
public struct CreateMessageResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Role of the generated message (typically `.assistant`).
    public let role: Role
    /// Generated content payload.
    public let content: PromptMessageContent
    /// Identifier of the model that generated the completion.
    public let model: String
    /// Optional reason why generation stopped (e.g. `"endTurn"`, `"maxTokens"`, `"stopSequence"`).
    public let stopReason: String?

    /// Initializes a `CreateMessageResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - role: Speaker `Role` of the sampled message.
    ///   - content: Generated `PromptMessageContent`.
    ///   - model: Name of the model used.
    ///   - stopReason: Optional generation stop reason string.
    public init(_meta: Meta? = nil, role: Role, content: PromptMessageContent, model: String, stopReason: String? = nil) {
        self._meta = _meta
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
    }
}
