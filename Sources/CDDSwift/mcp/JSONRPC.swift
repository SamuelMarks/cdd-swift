import Foundation

/// A type representing a JSON-RPC ID (string or integer)
public enum JSONRPCId: Codable, Equatable, Hashable, Sendable {
    /// String ID
    case string(String)
    /// Integer ID
    case integer(Int)

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

/// A JSON-RPC 2.0 message
public protocol JSONRPCMessage: Codable, Sendable {
    /// The jsonrpc version, must be "2.0"
    var jsonrpc: String { get }
}

/// A JSON-RPC 2.0 Request
public struct JSONRPCRequest<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version
    public var jsonrpc = "2.0"
    /// The request ID
    public let id: JSONRPCId
    /// The method being called
    public let method: String
    /// The parameters for the method
    public let params: T?

    /// Initialize a JSONRPCRequest
    public init(id: JSONRPCId, method: String, params: T? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 Notification
public struct JSONRPCNotification<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version
    public var jsonrpc = "2.0"
    /// The method being called
    public let method: String
    /// The parameters for the method
    public let params: T?

    /// Initialize a JSONRPCNotification
    public init(method: String, params: T? = nil) {
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 Response
public struct JSONRPCResponse<T: Codable & Sendable>: JSONRPCMessage {
    /// The JSON-RPC version
    public var jsonrpc = "2.0"
    /// The response ID
    public let id: JSONRPCId
    /// The response result
    public let result: T?

    /// Initialize a JSONRPCResponse
    public init(id: JSONRPCId, result: T? = nil) {
        self.id = id
        self.result = result
    }
}

/// Documentation for JSONRPCErrorCode
public enum JSONRPCErrorCode: Int, Codable, Sendable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
}

/// A JSON-RPC 2.0 Error Detail
public struct JSONRPCErrorDetail: Codable, Equatable, Error, Sendable {
    /// Error code
    public let code: Int
    /// Error message
    public let message: String
    /// Additional data
    public let data: AnyCodable?

    /// Initialize a JSONRPCErrorDetail
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(code: JSONRPCErrorCode, message: String, data: AnyCodable? = nil) {
        self.code = code.rawValue
        self.message = message
        self.data = data
    }
}

/// A JSON-RPC 2.0 Error
public struct JSONRPCError: JSONRPCMessage {
    /// The JSON-RPC version
    public var jsonrpc = "2.0"
    /// The error ID (can be null, but we just omit it or represent it via Optional JSONRPCId if we needed to, but we make it optional here)
    public let id: JSONRPCId?
    /// The error detail
    public let error: JSONRPCErrorDetail

    /// Initialize a JSONRPCError
    public init(id: JSONRPCId?, error: JSONRPCErrorDetail) {
        self.id = id
        self.error = error
    }
}
