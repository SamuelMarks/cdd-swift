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
