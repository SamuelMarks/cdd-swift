/// JSON-RPC 2.0 protocol message envelopes, identifiers, and error descriptors.

/// A type representing a JSON-RPC ID (string or integer).
public enum JSONRPCId: Codable, Equatable, Hashable, Sendable {
    /// String-valued JSON-RPC request/response identifier.
    case string(String)
    /// Integer-valued JSON-RPC request/response identifier.
    case integer(Int)

    /// Decodes a `JSONRPCId` from a single-value JSON container.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorruptedError` if the value is neither a string nor an integer.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringId = try? container.decode(String.self) {
            self = .string(stringId)
        } else if let intId = try? container.decode(Int.self) {
            self = .integer(intId)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "JSONRPCId must be a string or integer")
        }
    }

    /// Encodes this `JSONRPCId` into a single-value JSON container.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the underlying string or integer cannot be encoded.
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

/// A JSON-RPC 2.0 message envelope.
public protocol JSONRPCMessage: Codable, Sendable {
    /// The JSON-RPC specification version string, which must be `"2.0"`.
    var jsonrpc: String { get }
}

/// A JSON-RPC 2.0 Request message.
public struct JSONRPCRequest<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version string (`"2.0"`).
    public var jsonrpc = "2.0"
    /// The request identifier correlating this request with its response.
    public let id: JSONRPCId
    /// The name of the RPC method being invoked.
    public let method: String
    /// Optional structured parameters for the RPC method.
    public let params: T?

    /// Initializes a `JSONRPCRequest`.
    ///
    /// - Parameters:
    ///   - id: The unique request identifier.
    ///   - method: The RPC method name.
    ///   - params: Optional method parameters payload.
    public init(id: JSONRPCId, method: String, params: T? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 Notification message (a request without an `id`).
public struct JSONRPCNotification<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version string (`"2.0"`).
    public var jsonrpc = "2.0"
    /// The name of the notification method being invoked.
    public let method: String
    /// Optional structured parameters for the notification.
    public let params: T?

    /// Initializes a `JSONRPCNotification`.
    ///
    /// - Parameters:
    ///   - method: The notification method name.
    ///   - params: Optional notification parameters payload.
    public init(method: String, params: T? = nil) {
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 Response message.
public struct JSONRPCResponse<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version string (`"2.0"`).
    public var jsonrpc = "2.0"
    /// The request identifier matching the originating `JSONRPCRequest`.
    public let id: JSONRPCId
    /// The result payload returned by the RPC method.
    public let result: T?

    /// Initializes a `JSONRPCResponse`.
    ///
    /// - Parameters:
    ///   - id: The correlating request identifier.
    ///   - result: Optional result value.
    public init(id: JSONRPCId, result: T? = nil) {
        self.id = id
        self.result = result
    }
}

/// Standard JSON-RPC 2.0 numeric error codes.
public enum JSONRPCErrorCode: Int, Codable, Sendable {
    /// Invalid JSON was received by the server (`-32700`).
    case parseError = -32700
    /// The JSON sent is not a valid Request object (`-32600`).
    case invalidRequest = -32600
    /// The method does not exist or is not available (`-32601`).
    case methodNotFound = -32601
    /// Invalid method parameter(s) (`-32602`).
    case invalidParams = -32602
    /// Internal JSON-RPC error (`-32603`).
    case internalError = -32603
}

/// A JSON-RPC 2.0 Error Detail object.
public struct JSONRPCErrorDetail: Codable, Equatable, Error, Sendable {
    /// Numeric error code indicating the error type.
    public let code: Int
    /// Concise single-sentence description of the error.
    public let message: String
    /// Optional additional structured data about the error.
    public let data: AnyCodable?

    /// Initializes a `JSONRPCErrorDetail` with a raw integer error code.
    ///
    /// - Parameters:
    ///   - code: The numeric JSON-RPC error code.
    ///   - message: A human-readable description of the error.
    ///   - data: Optional structured error metadata.
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    /// Initializes a `JSONRPCErrorDetail` with a standard `JSONRPCErrorCode`.
    ///
    /// - Parameters:
    ///   - code: The standard `JSONRPCErrorCode` value.
    ///   - message: A human-readable description of the error.
    ///   - data: Optional structured error metadata.
    public init(code: JSONRPCErrorCode, message: String, data: AnyCodable? = nil) {
        self.code = code.rawValue
        self.message = message
        self.data = data
    }
}

/// A JSON-RPC 2.0 Error response envelope.
public struct JSONRPCError: JSONRPCMessage {
    /// The JSON-RPC version string (`"2.0"`).
    public var jsonrpc = "2.0"
    /// The request identifier, or `nil` if the request ID could not be determined.
    public let id: JSONRPCId?
    /// The structured error detail object.
    public let error: JSONRPCErrorDetail

    /// Initializes a `JSONRPCError` envelope.
    ///
    /// - Parameters:
    ///   - id: The correlating request identifier, if known.
    ///   - error: The `JSONRPCErrorDetail` describing the failure.
    public init(id: JSONRPCId?, error: JSONRPCErrorDetail) {
        self.id = id
        self.error = error
    }
}
