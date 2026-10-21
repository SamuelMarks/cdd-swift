/// Model Context Protocol (MCP) resource, resource template, content, and subscription models.
import Foundation

/// A known resource that the MCP server is capable of reading.
public struct Resource: Codable, Equatable, Sendable {
    /// Canonical URI identifying this resource.
    public let uri: String
    /// Human-readable display name of the resource.
    public let name: String
    /// Optional human-readable description of what the resource represents.
    public let description: String?
    /// Optional MIME type of the resource content, if known.
    public let mimeType: String?
    /// Optional size of the raw resource content in bytes.
    public let size: Int?
    /// Optional audience and priority annotations for the resource.
    public let annotations: Annotations?

    /// Initializes a `Resource` descriptor.
    ///
    /// - Parameters:
    ///   - uri: The canonical resource URI.
    ///   - name: Human-readable resource name.
    ///   - description: Optional resource description.
    ///   - mimeType: Optional MIME type string.
    ///   - size: Optional byte size of the resource.
    ///   - annotations: Optional `Annotations` metadata.
    public init(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil,
        annotations: Annotations? = nil
    ) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.annotations = annotations
    }
}

/// A RFC 6570 URI template describing parameterized resources available on the MCP server.
public struct ResourceTemplate: Codable, Equatable, Sendable {
    /// RFC 6570 URI template string used to construct concrete resource URIs.
    public let uriTemplate: String
    /// Human-readable display name for this template category.
    public let name: String
    /// Optional description of how the template should be used.
    public let description: String?
    /// Optional MIME type shared by all resources matching this template.
    public let mimeType: String?
    /// Optional audience and priority annotations for the template.
    public let annotations: Annotations?

    /// Initializes a `ResourceTemplate`.
    ///
    /// - Parameters:
    ///   - uriTemplate: RFC 6570 URI template string.
    ///   - name: Display name for the resource template.
    ///   - description: Optional description of the template.
    ///   - mimeType: Optional MIME type for resolved resources.
    ///   - annotations: Optional `Annotations` metadata.
    public init(uriTemplate: String, name: String, description: String? = nil, mimeType: String? = nil, annotations: Annotations? = nil) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

/// Parameters for a paginated `resources/list` request.
public struct ListResourcesRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// Opaque pagination cursor from a previous `ListResourcesResult`.
    public let cursor: String?

    /// Initializes `ListResourcesRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - cursor: Optional pagination cursor string.
    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// Result returned by the server in response to a `resources/list` request.
public struct ListResourcesResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Opaque pagination cursor for fetching the next page of resources, if more exist.
    public let nextCursor: String?
    /// Array of available `Resource` descriptors.
    public let resources: [Resource]

    /// Initializes a `ListResourcesResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - nextCursor: Optional pagination cursor for the next page.
    ///   - resources: Array of `Resource` definitions.
    public init(_meta: Meta? = nil, nextCursor: String? = nil, resources: [Resource]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resources = resources
    }
}

/// Parameters for a paginated `resources/templates/list` request.
public struct ListResourceTemplatesRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// Opaque pagination cursor from a previous `ListResourceTemplatesResult`.
    public let cursor: String?

    /// Initializes `ListResourceTemplatesRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - cursor: Optional pagination cursor string.
    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// Result returned by the server in response to a `resources/templates/list` request.
public struct ListResourceTemplatesResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// Opaque pagination cursor for fetching the next page of templates, if more exist.
    public let nextCursor: String?
    /// Array of available `ResourceTemplate` definitions.
    public let resourceTemplates: [ResourceTemplate]

    /// Initializes a `ListResourceTemplatesResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - nextCursor: Optional pagination cursor for the next page.
    ///   - resourceTemplates: Array of `ResourceTemplate` definitions.
    public init(_meta: Meta? = nil, nextCursor: String? = nil, resourceTemplates: [ResourceTemplate]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resourceTemplates = resourceTemplates
    }
}

/// Parameters for a `resources/read` request fetching the contents of a specific resource URI.
public struct ReadResourceRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// The URI of the resource to read.
    public let uri: String

    /// Initializes `ReadResourceRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - uri: Target resource URI string.
    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Represents either UTF-8 text or base64-encoded binary contents of an MCP resource.
public enum ResourceContents: Codable, Equatable, Sendable {
    /// Textual resource contents.
    case text(TextResourceContents)
    /// Base64-encoded binary resource contents.
    case blob(BlobResourceContents)

    /// Decodes `ResourceContents` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the payload matches neither `TextResourceContents` nor `BlobResourceContents`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(TextResourceContents.self) {
            self = .text(text)
        } else if let blob = try? container.decode(BlobResourceContents.self) {
            self = .blob(blob)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "ResourceContents must be either text or blob")
        }
    }

    /// Encodes `ResourceContents` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying text or blob resource cannot be encoded.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text):
            try container.encode(text)
        case let .blob(blob):
            try container.encode(blob)
        }
    }
}

/// Textual content payload for an MCP resource.
public struct TextResourceContents: Codable, Equatable, Sendable {
    /// The URI of the resource.
    public let uri: String
    /// Optional MIME type of the text content.
    public let mimeType: String?
    /// The UTF-8 text body of the resource.
    public let text: String

    /// Initializes `TextResourceContents`.
    ///
    /// - Parameters:
    ///   - uri: The resource URI.
    ///   - mimeType: Optional MIME type string.
    ///   - text: The textual content of the resource.
    public init(uri: String, mimeType: String? = nil, text: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
    }
}

/// Base64-encoded binary content payload for an MCP resource.
public struct BlobResourceContents: Codable, Equatable, Sendable {
    /// The URI of the resource.
    public let uri: String
    /// Optional MIME type of the binary content.
    public let mimeType: String?
    /// Base64-encoded string representing the binary data of the resource.
    public let blob: String

    /// Initializes `BlobResourceContents`.
    ///
    /// - Parameters:
    ///   - uri: The resource URI.
    ///   - mimeType: Optional MIME type string.
    ///   - blob: Base64-encoded binary data string.
    public init(uri: String, mimeType: String? = nil, blob: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.blob = blob
    }
}

/// Result returned by the server in response to a `resources/read` request.
public struct ReadResourceResult: Codable, Equatable, Sendable {
    /// Optional response metadata.
    public let _meta: Meta?
    /// The list of text or binary content items resolved for the requested URI.
    public let contents: [ResourceContents]

    /// Initializes a `ReadResourceResult`.
    ///
    /// - Parameters:
    ///   - _meta: Optional response metadata.
    ///   - contents: Array of `ResourceContents` items.
    public init(_meta: Meta? = nil, contents: [ResourceContents]) {
        self._meta = _meta
        self.contents = contents
    }
}

/// Parameters for a `notifications/resources/list_changed` notification.
public struct ResourceListChangedNotificationParams: Codable, Equatable, Sendable {
    /// Optional notification metadata.
    public let _meta: Meta?

    /// Initializes `ResourceListChangedNotificationParams`.
    ///
    /// - Parameter _meta: Optional notification metadata.
    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Parameters for a `notifications/resources/updated` notification indicating a subscribed resource changed.
public struct ResourceUpdatedNotificationParams: Codable, Equatable, Sendable {
    /// Optional notification metadata.
    public let _meta: Meta?
    /// The canonical URI of the resource that was updated.
    public let uri: String

    /// Initializes `ResourceUpdatedNotificationParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional notification metadata.
    ///   - uri: The updated resource URI.
    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Parameters for a `resources/subscribe` request registering for resource update notifications.
public struct SubscribeRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// The URI of the resource to subscribe to.
    public let uri: String

    /// Initializes `SubscribeRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - uri: Target resource URI to subscribe to.
    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Parameters for a `resources/unsubscribe` request cancelling a prior resource subscription.
public struct UnsubscribeRequestParams: Codable, Equatable, Sendable {
    /// Optional request metadata.
    public let _meta: Meta?
    /// The URI of the resource to unsubscribe from.
    public let uri: String

    /// Initializes `UnsubscribeRequestParams`.
    ///
    /// - Parameters:
    ///   - _meta: Optional request metadata.
    ///   - uri: Target resource URI to unsubscribe from.
    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}
