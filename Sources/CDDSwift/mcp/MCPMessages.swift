import Foundation

/// A progress token, used to associate progress notifications with the original request.
public enum ProgressToken: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case integer(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringToken = try? container.decode(String.self) {
            self = .string(stringToken)
        } else if let intToken = try? container.decode(Int.self) {
            self = .integer(intToken)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "ProgressToken must be a string or integer")
        }
    }

    /// Documentation for encode
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(str):
            try container.encode(str)
        case let .integer(int):
            try container.encode(int)
        }
    }
}

/// Metadata associated with requests, notifications, and results.
public struct Meta: Codable, Equatable, Sendable {
    public let progressToken: ProgressToken?

    public init(progressToken: ProgressToken? = nil) {
        self.progressToken = progressToken
    }
}

/// Base parameters for requests.
public struct RequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Base parameters for notifications.
public struct NotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Base result for responses.
public struct Result: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// An empty result.
public struct EmptyResult: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Describes the name and version of an implementation of the protocol.
public struct Implementation: Codable, Equatable, Sendable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Capabilities a client may support.
public struct ClientCapabilities: Codable, Equatable, Sendable {
    public let experimental: [String: AnyCodable]?
    public let roots: RootsCapability?
    public let sampling: SamplingCapability?

    /// Documentation for RootsCapability
    public struct RootsCapability: Codable, Equatable, Sendable {
        public let listChanged: Bool?
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    /// Documentation for SamplingCapability
    public struct SamplingCapability: Codable, Equatable, Sendable {
        public init() {}
    }

    public init(experimental: [String: AnyCodable]? = nil, roots: RootsCapability? = nil, sampling: SamplingCapability? = nil) {
        self.experimental = experimental
        self.roots = roots
        self.sampling = sampling
    }
}

/// Capabilities a server may support.
public struct ServerCapabilities: Codable, Equatable, Sendable {
    public let experimental: [String: AnyCodable]?
    public let logging: LoggingCapability?
    public let prompts: PromptsCapability?
    public let resources: ResourcesCapability?
    public let tools: ToolsCapability?

    /// Documentation for LoggingCapability
    public struct LoggingCapability: Codable, Equatable, Sendable {
        public init() {}
    }

    /// Documentation for PromptsCapability
    public struct PromptsCapability: Codable, Equatable, Sendable {
        public let listChanged: Bool?
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    /// Documentation for ResourcesCapability
    public struct ResourcesCapability: Codable, Equatable, Sendable {
        public let listChanged: Bool?
        public let subscribe: Bool?
        public init(listChanged: Bool? = nil, subscribe: Bool? = nil) {
            self.listChanged = listChanged
            self.subscribe = subscribe
        }
    }

    /// Documentation for ToolsCapability
    public struct ToolsCapability: Codable, Equatable, Sendable {
        public let listChanged: Bool?
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    public init(
        experimental: [String: AnyCodable]? = nil,
        logging: LoggingCapability? = nil,
        prompts: PromptsCapability? = nil,
        resources: ResourcesCapability? = nil,
        tools: ToolsCapability? = nil
    ) {
        self.experimental = experimental
        self.logging = logging
        self.prompts = prompts
        self.resources = resources
        self.tools = tools
    }
}

/// InitializeRequest
public struct InitializeRequestParams: Codable, Equatable, Sendable {
    public let protocolVersion: String
    public let capabilities: ClientCapabilities
    public let clientInfo: Implementation

    public init(protocolVersion: String, capabilities: ClientCapabilities, clientInfo: Implementation) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

/// InitializeResult
public struct InitializeResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let protocolVersion: String
    public let capabilities: ServerCapabilities
    public let serverInfo: Implementation
    public let instructions: String?

    public init(_meta: Meta? = nil, protocolVersion: String, capabilities: ServerCapabilities, serverInfo: Implementation, instructions: String? = nil) {
        self._meta = _meta
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
        self.instructions = instructions
    }
}

/// InitializedNotificationParams
public struct InitializedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}
