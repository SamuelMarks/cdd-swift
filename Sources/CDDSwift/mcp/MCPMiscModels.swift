import Foundation

// MARK: - Core Types

/// Documentation for Cursor
public typealias Cursor = String
/// Documentation for RequestId
public typealias RequestId = JSONRPCId

/// Documentation for Annotations
public struct Annotations: Codable, Equatable, Sendable {
    /// Documentation for audience
    public let audience: [Role]?
    /// Documentation for priority
    public let priority: Double?

    /// Documentation for init
    public init(audience: [Role]? = nil, priority: Double? = nil) {
        self.audience = audience
        self.priority = priority
    }
}

/// Documentation for Annotated
public struct Annotated: Codable, Equatable, Sendable {
    public let annotations: Annotations?
    public init(annotations: Annotations? = nil) {
        self.annotations = annotations
    }
}

/// Documentation for Role
public enum Role: String, Codable, Equatable, Sendable {
    case user
    case assistant
}

// MARK: - Notifications

/// Documentation for CancelledNotificationParams
public struct CancelledNotificationParams: Codable, Equatable, Sendable {
    public let requestId: RequestId
    public let reason: String?
    public init(requestId: RequestId, reason: String? = nil) {
        self.requestId = requestId
        self.reason = reason
    }
}

/// Documentation for ProgressNotificationParams
public struct ProgressNotificationParams: Codable, Equatable, Sendable {
    public let progressToken: ProgressToken
    public let progress: Double
    public let total: Double?
    public init(progressToken: ProgressToken, progress: Double, total: Double? = nil) {
        self.progressToken = progressToken
        self.progress = progress
        self.total = total
    }
}

/// Documentation for ClientNotification
public typealias ClientNotification = JSONRPCNotification<AnyCodable>
/// Documentation for ServerNotification
public typealias ServerNotification = JSONRPCNotification<AnyCodable>

// MARK: - Requests & Results

/// Documentation for ClientRequest
public typealias ClientRequest = JSONRPCRequest<AnyCodable>
/// Documentation for ClientResult
public typealias ClientResult = JSONRPCResponse<AnyCodable>

/// Documentation for ServerRequest
public typealias ServerRequest = JSONRPCRequest<AnyCodable>
/// Documentation for ServerResult
public typealias ServerResult = JSONRPCResponse<AnyCodable>

/// Documentation for PaginatedRequestParams
public struct PaginatedRequestParams: Codable, Equatable, Sendable {
    public let cursor: Cursor?
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

/// Documentation for PaginatedResult
public struct PaginatedResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let nextCursor: Cursor?
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil) {
        self._meta = _meta
        self.nextCursor = nextCursor
    }
}

/// Documentation for PingRequestParams
public struct PingRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Content Types

/// Documentation for TextContent
public struct TextContent: Codable, Equatable, Sendable {
    public var type = "text"
    public let text: String
    public let annotations: Annotations?
    public init(text: String, annotations: Annotations? = nil) {
        self.text = text
        self.annotations = annotations
    }
}

/// Documentation for ImageContent
public struct ImageContent: Codable, Equatable, Sendable {
    public var type = "image"
    public let data: String
    public let mimeType: String
    public let annotations: Annotations?
    public init(data: String, mimeType: String, annotations: Annotations? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

/// Documentation for EmbeddedResource
public struct EmbeddedResource: Codable, Equatable, Sendable {
    public var type = "resource"
    public let resource: ResourceContents
    public let annotations: Annotations?
    public init(resource: ResourceContents, annotations: Annotations? = nil) {
        self.resource = resource
        self.annotations = annotations
    }
}

// MARK: - Logging

/// Documentation for LoggingLevel
public enum LoggingLevel: String, Codable, Equatable, Sendable {
    case debug, info, notice, warning, error, critical, alert, emergency
}

/// Documentation for SetLevelRequestParams
public struct SetLevelRequestParams: Codable, Equatable, Sendable {
    public let level: LoggingLevel
    public init(level: LoggingLevel) {
        self.level = level
    }
}

/// Documentation for LoggingMessageNotificationParams
public struct LoggingMessageNotificationParams: Codable, Equatable, Sendable {
    public let level: LoggingLevel
    public let logger: String?
    public let data: AnyCodable
    public init(level: LoggingLevel, logger: String? = nil, data: AnyCodable) {
        self.level = level
        self.logger = logger
        self.data = data
    }
}

// MARK: - Prompts

/// Documentation for PromptArgument
public struct PromptArgument: Codable, Equatable, Sendable {
    public let name: String
    public let description: String?
    public let required: Bool?
    public init(name: String, description: String? = nil, required: Bool? = nil) {
        self.name = name
        self.description = description
        self.required = required
    }
}

/// Documentation for Prompt
public struct Prompt: Codable, Equatable, Sendable {
    public let name: String
    public let description: String?
    public let arguments: [PromptArgument]?
    public init(name: String, description: String? = nil, arguments: [PromptArgument]? = nil) {
        self.name = name
        self.description = description
        self.arguments = arguments
    }
}

/// Documentation for PromptMessage
public struct PromptMessage: Codable, Equatable, Sendable {
    public let role: Role
    public let content: PromptMessageContent
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

/// Documentation for PromptMessageContent
public enum PromptMessageContent: Codable, Equatable, Sendable {
    case text(TextContent)
    case image(ImageContent)
    case resource(EmbeddedResource)

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

    /// Documentation for encode
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(t): try container.encode(t)
        case let .image(i): try container.encode(i)
        case let .resource(r): try container.encode(r)
        }
    }
}

/// Documentation for PromptReference
public struct PromptReference: Codable, Equatable, Sendable {
    public var type = "ref/prompt"
    public let name: String
    public init(name: String) {
        self.name = name
    }
}

/// Documentation for GetPromptRequestParams
public struct GetPromptRequestParams: Codable, Equatable, Sendable {
    public let name: String
    public let arguments: [String: String]?
    public init(name: String, arguments: [String: String]? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// Documentation for GetPromptResult
public struct GetPromptResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let description: String?
    public let messages: [PromptMessage]
    public init(_meta: Meta? = nil, description: String? = nil, messages: [PromptMessage]) {
        self._meta = _meta
        self.description = description
        self.messages = messages
    }
}

/// Documentation for ListPromptsRequestParams
public struct ListPromptsRequestParams: Codable, Equatable, Sendable {
    public let cursor: Cursor?
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

/// Documentation for ListPromptsResult
public struct ListPromptsResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let nextCursor: Cursor?
    public let prompts: [Prompt]
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil, prompts: [Prompt]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.prompts = prompts
    }
}

/// Documentation for PromptListChangedNotificationParams
public struct PromptListChangedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Roots

/// Documentation for Root
public struct Root: Codable, Equatable, Sendable {
    public let uri: String
    public let name: String?
    public init(uri: String, name: String? = nil) {
        self.uri = uri
        self.name = name
    }
}

/// Documentation for ListRootsRequestParams
public struct ListRootsRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Documentation for ListRootsResult
public struct ListRootsResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let roots: [Root]
    public init(_meta: Meta? = nil, roots: [Root]) {
        self._meta = _meta
        self.roots = roots
    }
}

/// Documentation for RootsListChangedNotificationParams
public struct RootsListChangedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Completion

/// Documentation for CompleteRequestParams
public struct CompleteRequestParams: Codable, Equatable, Sendable {
    public let ref: CompleteReference
    public let argument: CompleteArgument

    public init(ref: CompleteReference, argument: CompleteArgument) {
        self.ref = ref
        self.argument = argument
    }

    /// Documentation for CompleteArgument
    public struct CompleteArgument: Codable, Equatable, Sendable {
        public let name: String
        public let value: String
        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}

/// Documentation for CompleteReference
public enum CompleteReference: Codable, Equatable, Sendable {
    case prompt(PromptReference)
    case resource(ResourceReference)

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

    /// Documentation for encode
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .prompt(p): try container.encode(p)
        case let .resource(r): try container.encode(r)
        }
    }
}

/// Documentation for ResourceReference
public struct ResourceReference: Codable, Equatable, Sendable {
    public var type = "ref/resource"
    public let uri: String
    public init(uri: String) {
        self.uri = uri
    }
}

/// Documentation for CompleteResult
public struct CompleteResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let completion: Completion

    public init(_meta: Meta? = nil, completion: Completion) {
        self._meta = _meta
        self.completion = completion
    }

    /// Documentation for Completion
    public struct Completion: Codable, Equatable, Sendable {
        public let values: [String]
        public let total: Int?
        public let hasMore: Bool?
        public init(values: [String], total: Int? = nil, hasMore: Bool? = nil) {
            self.values = values
            self.total = total
            self.hasMore = hasMore
        }
    }
}

// MARK: - Sampling

/// Documentation for SamplingMessage
public struct SamplingMessage: Codable, Equatable, Sendable {
    public let role: Role
    public let content: PromptMessageContent
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

/// Documentation for ModelHint
public struct ModelHint: Codable, Equatable, Sendable {
    public let name: String
    public init(name: String) {
        self.name = name
    }
}

/// Documentation for ModelPreferences
public struct ModelPreferences: Codable, Equatable, Sendable {
    public let hints: [ModelHint]?
    public let costPriority: Double?
    public let speedPriority: Double?
    public let intelligencePriority: Double?

    public init(hints: [ModelHint]? = nil, costPriority: Double? = nil, speedPriority: Double? = nil, intelligencePriority: Double? = nil) {
        self.hints = hints
        self.costPriority = costPriority
        self.speedPriority = speedPriority
        self.intelligencePriority = intelligencePriority
    }
}

/// Documentation for CreateMessageRequestParams
public struct CreateMessageRequestParams: Codable, Equatable, Sendable {
    public let messages: [SamplingMessage]
    public let modelPreferences: ModelPreferences?
    public let systemPrompt: String?
    public let includeContext: String?
    public let temperature: Double?
    public let maxTokens: Int
    public let stopSequences: [String]?
    public let metadata: [String: AnyCodable]?

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

/// Documentation for CreateMessageResult
public struct CreateMessageResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let role: Role
    public let content: PromptMessageContent
    public let model: String
    public let stopReason: String?

    public init(_meta: Meta? = nil, role: Role, content: PromptMessageContent, model: String, stopReason: String? = nil) {
        self._meta = _meta
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
    }
}
