import Foundation

// MARK: - Core Types

public typealias Cursor = String
public typealias RequestId = JSONRPCId

public struct Annotated: Codable, Equatable {
    public let annotations: [String: AnyCodable]?
    public init(annotations: [String: AnyCodable]? = nil) {
        self.annotations = annotations
    }
}

public enum Role: String, Codable, Equatable {
    case user
    case assistant
}

// MARK: - Notifications

public struct CancelledNotificationParams: Codable, Equatable {
    public let requestId: RequestId
    public let reason: String?
    public init(requestId: RequestId, reason: String? = nil) {
        self.requestId = requestId
        self.reason = reason
    }
}

public struct ProgressNotificationParams: Codable, Equatable {
    public let progressToken: ProgressToken
    public let progress: Double
    public let total: Double?
    public init(progressToken: ProgressToken, progress: Double, total: Double? = nil) {
        self.progressToken = progressToken
        self.progress = progress
        self.total = total
    }
}

public typealias ClientNotification = JSONRPCNotification<AnyCodable>
public typealias ServerNotification = JSONRPCNotification<AnyCodable>

// MARK: - Requests & Results

public typealias ClientRequest = JSONRPCRequest<AnyCodable>
public typealias ClientResult = JSONRPCResponse<AnyCodable>

public typealias ServerRequest = JSONRPCRequest<AnyCodable>
public typealias ServerResult = JSONRPCResponse<AnyCodable>

public struct PaginatedRequestParams: Codable, Equatable {
    public let cursor: Cursor?
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

public struct PaginatedResult: Codable, Equatable {
    public let _meta: Meta?
    public let nextCursor: Cursor?
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil) {
        self._meta = _meta
        self.nextCursor = nextCursor
    }
}

public struct PingRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Content Types

public struct TextContent: Codable, Equatable {
    public var type = "text"
    public let text: String
    public let annotations: [String: AnyCodable]?
    public init(text: String, annotations: [String: AnyCodable]? = nil) {
        self.text = text
        self.annotations = annotations
    }
}

public struct ImageContent: Codable, Equatable {
    public var type = "image"
    public let data: String
    public let mimeType: String
    public let annotations: [String: AnyCodable]?
    public init(data: String, mimeType: String, annotations: [String: AnyCodable]? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

public struct EmbeddedResource: Codable, Equatable {
    public var type = "resource"
    public let resource: ResourceContents
    public let annotations: [String: AnyCodable]?
    public init(resource: ResourceContents, annotations: [String: AnyCodable]? = nil) {
        self.resource = resource
        self.annotations = annotations
    }
}

// MARK: - Logging

public enum LoggingLevel: String, Codable, Equatable {
    case debug, info, notice, warning, error, critical, alert, emergency
}

public struct SetLevelRequestParams: Codable, Equatable {
    public let level: LoggingLevel
    public init(level: LoggingLevel) {
        self.level = level
    }
}

public struct LoggingMessageNotificationParams: Codable, Equatable {
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

public struct PromptArgument: Codable, Equatable {
    public let name: String
    public let description: String?
    public let required: Bool?
    public init(name: String, description: String? = nil, required: Bool? = nil) {
        self.name = name
        self.description = description
        self.required = required
    }
}

public struct Prompt: Codable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [PromptArgument]?
    public init(name: String, description: String? = nil, arguments: [PromptArgument]? = nil) {
        self.name = name
        self.description = description
        self.arguments = arguments
    }
}

public struct PromptMessage: Codable, Equatable {
    public let role: Role
    public let content: PromptMessageContent
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

public enum PromptMessageContent: Codable, Equatable {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let t): try container.encode(t)
        case .image(let i): try container.encode(i)
        case .resource(let r): try container.encode(r)
        }
    }
}

public struct PromptReference: Codable, Equatable {
    public var type = "ref/prompt"
    public let name: String
    public init(name: String) {
        self.name = name
    }
}

public struct GetPromptRequestParams: Codable, Equatable {
    public let name: String
    public let arguments: [String: String]?
    public init(name: String, arguments: [String: String]? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

public struct GetPromptResult: Codable, Equatable {
    public let _meta: Meta?
    public let description: String?
    public let messages: [PromptMessage]
    public init(_meta: Meta? = nil, description: String? = nil, messages: [PromptMessage]) {
        self._meta = _meta
        self.description = description
        self.messages = messages
    }
}

public struct ListPromptsRequestParams: Codable, Equatable {
    public let cursor: Cursor?
    public init(cursor: Cursor? = nil) {
        self.cursor = cursor
    }
}

public struct ListPromptsResult: Codable, Equatable {
    public let _meta: Meta?
    public let nextCursor: Cursor?
    public let prompts: [Prompt]
    public init(_meta: Meta? = nil, nextCursor: Cursor? = nil, prompts: [Prompt]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.prompts = prompts
    }
}

public struct PromptListChangedNotificationParams: Codable, Equatable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Roots

public struct Root: Codable, Equatable {
    public let uri: String
    public let name: String?
    public init(uri: String, name: String? = nil) {
        self.uri = uri
        self.name = name
    }
}

public struct ListRootsRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

public struct ListRootsResult: Codable, Equatable {
    public let _meta: Meta?
    public let roots: [Root]
    public init(_meta: Meta? = nil, roots: [Root]) {
        self._meta = _meta
        self.roots = roots
    }
}

public struct RootsListChangedNotificationParams: Codable, Equatable {
    public let _meta: Meta?
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

// MARK: - Completion

public struct CompleteRequestParams: Codable, Equatable {
    public let ref: CompleteReference
    public let argument: CompleteArgument
    
    public init(ref: CompleteReference, argument: CompleteArgument) {
        self.ref = ref
        self.argument = argument
    }
    
    public struct CompleteArgument: Codable, Equatable {
        public let name: String
        public let value: String
        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}

public enum CompleteReference: Codable, Equatable {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .prompt(let p): try container.encode(p)
        case .resource(let r): try container.encode(r)
        }
    }
}

public struct ResourceReference: Codable, Equatable {
    public var type = "ref/resource"
    public let uri: String
    public init(uri: String) {
        self.uri = uri
    }
}

public struct CompleteResult: Codable, Equatable {
    public let _meta: Meta?
    public let completion: Completion
    
    public init(_meta: Meta? = nil, completion: Completion) {
        self._meta = _meta
        self.completion = completion
    }
    
    public struct Completion: Codable, Equatable {
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

public struct SamplingMessage: Codable, Equatable {
    public let role: Role
    public let content: PromptMessageContent
    public init(role: Role, content: PromptMessageContent) {
        self.role = role
        self.content = content
    }
}

public struct ModelHint: Codable, Equatable {
    public let name: String
    public init(name: String) {
        self.name = name
    }
}

public struct ModelPreferences: Codable, Equatable {
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

public struct CreateMessageRequestParams: Codable, Equatable {
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

public struct CreateMessageResult: Codable, Equatable {
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
