import Foundation

/// Documentation for Resource
public struct Resource: Codable, Equatable, Sendable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    public let size: Int?
    public let annotations: Annotations?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil, size: Int? = nil, annotations: Annotations? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.annotations = annotations
    }
}

/// Documentation for ResourceTemplate
public struct ResourceTemplate: Codable, Equatable, Sendable {
    public let uriTemplate: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    public let annotations: Annotations?

    public init(uriTemplate: String, name: String, description: String? = nil, mimeType: String? = nil, annotations: Annotations? = nil) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

/// Documentation for ListResourcesRequestParams
public struct ListResourcesRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let cursor: String?

    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// Documentation for ListResourcesResult
public struct ListResourcesResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let nextCursor: String?
    public let resources: [Resource]

    public init(_meta: Meta? = nil, nextCursor: String? = nil, resources: [Resource]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resources = resources
    }
}

/// Documentation for ListResourceTemplatesRequestParams
public struct ListResourceTemplatesRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let cursor: String?

    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

/// Documentation for ListResourceTemplatesResult
public struct ListResourceTemplatesResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let nextCursor: String?
    public let resourceTemplates: [ResourceTemplate]

    public init(_meta: Meta? = nil, nextCursor: String? = nil, resourceTemplates: [ResourceTemplate]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resourceTemplates = resourceTemplates
    }
}

/// Documentation for ReadResourceRequestParams
public struct ReadResourceRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Documentation for ResourceContents
public enum ResourceContents: Codable, Equatable, Sendable {
    case text(TextResourceContents)
    case blob(BlobResourceContents)

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

    /// Documentation for encode
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

/// Documentation for TextResourceContents
public struct TextResourceContents: Codable, Equatable, Sendable {
    public let uri: String
    public let mimeType: String?
    public let text: String

    public init(uri: String, mimeType: String? = nil, text: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
    }
}

/// Documentation for BlobResourceContents
public struct BlobResourceContents: Codable, Equatable, Sendable {
    public let uri: String
    public let mimeType: String?
    public let blob: String

    public init(uri: String, mimeType: String? = nil, blob: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.blob = blob
    }
}

/// Documentation for ReadResourceResult
public struct ReadResourceResult: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let contents: [ResourceContents]

    public init(_meta: Meta? = nil, contents: [ResourceContents]) {
        self._meta = _meta
        self.contents = contents
    }
}

/// Documentation for ResourceListChangedNotificationParams
public struct ResourceListChangedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

/// Documentation for ResourceUpdatedNotificationParams
public struct ResourceUpdatedNotificationParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Documentation for SubscribeRequestParams
public struct SubscribeRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

/// Documentation for UnsubscribeRequestParams
public struct UnsubscribeRequestParams: Codable, Equatable, Sendable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}
