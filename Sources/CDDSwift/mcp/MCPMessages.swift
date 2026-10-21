/// Model Context Protocol (MCP) initialization, capability, and base message models.
import Foundation

/// A progress token used to associate progress notifications with an in-flight request.
public enum ProgressToken: Codable, Equatable, Hashable, Sendable {
    /// String-backed progress token.
    case string(String)
    /// Integer-backed progress token.
    case integer(Int)

    /// Decodes a `ProgressToken` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the token is neither a string nor an integer.
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

    /// Encodes this `ProgressToken` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying token value cannot be encoded.
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

/// Metadata associated with MCP requests, notifications, and results.
public struct Meta: Codable, Equatable, Sendable {
    /// Optional token used to report out-of-band progress updates.
    public let progressToken: ProgressToken?

    /// Initializes a `Meta` container.
    ///
    /// - Parameter progressToken: Optional progress token for tracking request progress.
    public init(progressToken: ProgressToken? = nil) {
        self.progressToken = progressToken
    }
}

/// Base parameters structure for MCP requests.
public struct RequestParams: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the request.
    public let _meta: Meta?

    /// Initializes `RequestParams`.
    ///
    /// - Parameter _meta: Optional protocol metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Base parameters structure for MCP notifications.
public struct NotificationParams: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the notification.
    public let _meta: Meta?

    /// Initializes `NotificationParams`.
    ///
    /// - Parameter _meta: Optional protocol metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Base result structure for MCP responses.
public struct Result: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the result.
    public let _meta: Meta?

    /// Initializes a `Result`.
    ///
    /// - Parameter _meta: Optional protocol metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// An empty MCP result payload indicating successful execution with no return fields.
public struct EmptyResult: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the empty result.
    public let _meta: Meta?

    /// Initializes an `EmptyResult`.
    ///
    /// - Parameter _meta: Optional protocol metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Describes the name and semantic version of an MCP client or server implementation.
public struct Implementation: Codable, Equatable, Sendable {
    /// Display name of the MCP implementation.
    public let name: String
    /// Semantic version string of the MCP implementation.
    public let version: String

    /// Initializes an `Implementation` descriptor.
    ///
    /// - Parameters:
    ///   - name: The implementation name.
    ///   - version: The implementation version string.
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Capabilities that an MCP client may support during session negotiation.
public struct ClientCapabilities: Codable, Equatable, Sendable {
    /// Non-standard experimental capabilities keyed by feature identifier.
    public let experimental: [String: AnyCodable]?
    /// Capability for exposing filesystem or workspace roots to the server.
    public let roots: RootsCapability?
    /// Capability for supporting server-initiated LLM sampling requests.
    public let sampling: SamplingCapability?

    /// Configuration for the client's `roots` capability.
    public struct RootsCapability: Codable, Equatable, Sendable {
        /// Whether the client emits notifications when the list of roots changes.
        public let listChanged: Bool?

        /// Initializes a `RootsCapability`.
        ///
        /// - Parameter listChanged: Whether root list change notifications are supported.
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    /// Configuration indicating the client supports LLM message sampling.
    public struct SamplingCapability: Codable, Equatable, Sendable {
        /// Initializes an empty `SamplingCapability`.
        public init() {}
    }

    /// Initializes `ClientCapabilities`.
    ///
    /// - Parameters:
    ///   - experimental: Optional dictionary of experimental feature flags.
    ///   - roots: Optional workspace roots capability descriptor.
    ///   - sampling: Optional LLM sampling capability descriptor.
    public init(experimental: [String: AnyCodable]? = nil, roots: RootsCapability? = nil, sampling: SamplingCapability? = nil) {
        self.experimental = experimental
        self.roots = roots
        self.sampling = sampling
    }
}

/// Capabilities that an MCP server may support during session negotiation.
public struct ServerCapabilities: Codable, Equatable, Sendable {
    /// Non-standard experimental capabilities keyed by feature identifier.
    public let experimental: [String: AnyCodable]?
    /// Capability for emitting structured log messages to the client.
    public let logging: LoggingCapability?
    /// Capability for serving reusable prompt templates.
    public let prompts: PromptsCapability?
    /// Capability for serving readable resources and resource subscriptions.
    public let resources: ResourcesCapability?
    /// Capability for exposing callable tools.
    public let tools: ToolsCapability?

    /// Configuration indicating the server supports structured log notifications.
    public struct LoggingCapability: Codable, Equatable, Sendable {
        /// Initializes a `LoggingCapability`.
        public init() {}
    }

    /// Configuration for the server's `prompts` capability.
    public struct PromptsCapability: Codable, Equatable, Sendable {
        /// Whether the server emits notifications when the available prompt list changes.
        public let listChanged: Bool?

        /// Initializes a `PromptsCapability`.
        ///
        /// - Parameter listChanged: Whether prompt list change notifications are supported.
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    /// Configuration for the server's `resources` capability.
    public struct ResourcesCapability: Codable, Equatable, Sendable {
        /// Whether the server emits notifications when the resource list changes.
        public let listChanged: Bool?
        /// Whether clients can subscribe to individual resource update notifications.
        public let subscribe: Bool?

        /// Initializes a `ResourcesCapability`.
        ///
        /// - Parameters:
        ///   - listChanged: Whether resource list change notifications are supported.
        ///   - subscribe: Whether per-resource subscriptions are supported.
        public init(listChanged: Bool? = nil, subscribe: Bool? = nil) {
            self.listChanged = listChanged
            self.subscribe = subscribe
        }
    }

    /// Configuration for the server's `tools` capability.
    public struct ToolsCapability: Codable, Equatable, Sendable {
        /// Whether the server emits notifications when the registered tool list changes.
        public let listChanged: Bool?

        /// Initializes a `ToolsCapability`.
        ///
        /// - Parameter listChanged: Whether tool list change notifications are supported.
        public init(listChanged: Bool? = nil) {
            self.listChanged = listChanged
        }
    }

    /// Initializes `ServerCapabilities`.
    ///
    /// - Parameters:
    ///   - experimental: Optional experimental feature map.
    ///   - logging: Optional logging capability configuration.
    ///   - prompts: Optional prompt template capability configuration.
    ///   - resources: Optional resource capability configuration.
    ///   - tools: Optional tool execution capability configuration.
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

/// Parameters sent by the client in an `initialize` request to begin an MCP session.
public struct InitializeRequestParams: Codable, Equatable, Sendable {
    /// The latest Model Context Protocol version supported by the client.
    public let protocolVersion: String
    /// The capabilities supported by the client.
    public let capabilities: ClientCapabilities
    /// Name and version metadata for the client application.
    public let clientInfo: Implementation

    /// Initializes `InitializeRequestParams`.
    ///
    /// - Parameters:
    ///   - protocolVersion: The requested MCP protocol version string.
    ///   - capabilities: Client capability configuration.
    ///   - clientInfo: Client implementation name and version.
    public init(protocolVersion: String, capabilities: ClientCapabilities, clientInfo: Implementation) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

/// Result returned by the server in response to an `initialize` request.
public struct InitializeResult: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the response.
    public let _meta: Meta?
    /// The Model Context Protocol version selected by the server for the session.
    public let protocolVersion: String
    /// The capabilities supported by the server.
    public let capabilities: ServerCapabilities
    /// Name and version metadata for the server implementation.
    public let serverInfo: Implementation
    /// Optional human- or LLM-readable usage instructions for interacting with the server.
    public let instructions: String?

    /// Initializes an `InitializeResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional protocol metadata.
    ///   - protocolVersion: Negotiated MCP protocol version string.
    ///   - capabilities: Server capability configuration.
    ///   - serverInfo: Server implementation name and version.
    ///   - instructions: Optional server usage instructions.
    public init(
        _meta: Meta? = nil,
        protocolVersion: String,
        capabilities: ServerCapabilities,
        serverInfo: Implementation,
        instructions: String? = nil
    ) {
        self._meta = _meta
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
        self.instructions = instructions
    }
}

/// Parameters accompanying the `notifications/initialized` notification sent by the client after initialization.
public struct InitializedNotificationParams: Codable, Equatable, Sendable {
    /// Optional protocol metadata attached to the notification.
    public let _meta: Meta?

    /// Initializes `InitializedNotificationParams`.
    ///
    /// - Parameter _meta: Optional protocol metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}
