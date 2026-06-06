import Foundation

public struct Resource: Codable, Equatable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    public let annotations: [String: AnyCodable]? // Actually annotations usually have audience, priority, etc. Let's make it unstructured for now or use a dedicated struct if needed.

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil, annotations: [String: AnyCodable]? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

public struct ResourceTemplate: Codable, Equatable {
    public let uriTemplate: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    public let annotations: [String: AnyCodable]?

    public init(uriTemplate: String, name: String, description: String? = nil, mimeType: String? = nil, annotations: [String: AnyCodable]? = nil) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.annotations = annotations
    }
}

public struct ListResourcesRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public let cursor: String?

    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

public struct ListResourcesResult: Codable, Equatable {
    public let _meta: Meta?
    public let nextCursor: String?
    public let resources: [Resource]

    public init(_meta: Meta? = nil, nextCursor: String? = nil, resources: [Resource]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resources = resources
    }
}

public struct ListResourceTemplatesRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public let cursor: String?

    public init(_meta: Meta? = nil, cursor: String? = nil) {
        self._meta = _meta
        self.cursor = cursor
    }
}

public struct ListResourceTemplatesResult: Codable, Equatable {
    public let _meta: Meta?
    public let nextCursor: String?
    public let resourceTemplates: [ResourceTemplate]

    public init(_meta: Meta? = nil, nextCursor: String? = nil, resourceTemplates: [ResourceTemplate]) {
        self._meta = _meta
        self.nextCursor = nextCursor
        self.resourceTemplates = resourceTemplates
    }
}

public struct ReadResourceRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

public enum ResourceContents: Codable, Equatable {
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .blob(let blob):
            try container.encode(blob)
        }
    }
}

public struct TextResourceContents: Codable, Equatable {
    public let uri: String
    public let mimeType: String?
    public let text: String

    public init(uri: String, mimeType: String? = nil, text: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
    }
}

public struct BlobResourceContents: Codable, Equatable {
    public let uri: String
    public let mimeType: String?
    public let blob: String

    public init(uri: String, mimeType: String? = nil, blob: String) {
        self.uri = uri
        self.mimeType = mimeType
        self.blob = blob
    }
}

public struct ReadResourceResult: Codable, Equatable {
    public let _meta: Meta?
    public let contents: [ResourceContents]

    public init(_meta: Meta? = nil, contents: [ResourceContents]) {
        self._meta = _meta
        self.contents = contents
    }
}

public struct ResourceListChangedNotificationParams: Codable, Equatable {
    public let _meta: Meta?

    public init(_meta: Meta? = nil) {
        self._meta = _meta
    }
}

public struct ResourceUpdatedNotificationParams: Codable, Equatable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

public struct SubscribeRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}

public struct UnsubscribeRequestParams: Codable, Equatable {
    public let _meta: Meta?
    public let uri: String

    public init(_meta: Meta? = nil, uri: String) {
        self._meta = _meta
        self.uri = uri
    }
}
