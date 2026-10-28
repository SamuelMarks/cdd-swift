/// Model Context Protocol (MCP) argument auto-completion and LLM sampling models.

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
    public init(
        hints: [ModelHint]? = nil,
        costPriority: Double? = nil,
        speedPriority: Double? = nil,
        intelligencePriority: Double? = nil
    ) {
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
    public init(
        messages: [SamplingMessage],
        modelPreferences: ModelPreferences? = nil,
        systemPrompt: String? = nil,
        includeContext: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int,
        stopSequences: [String]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
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
    public init(
        _meta: Meta? = nil,
        role: Role,
        content: PromptMessageContent,
        model: String,
        stopReason: String? = nil
    ) {
        self._meta = _meta
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
    }
}
