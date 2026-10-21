/// Model Context Protocol (MCP) prompt template and workspace root domain models.
import Foundation

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
