import Foundation

// MARK: - Models

public struct Customer: Codable, Equatable {
    public var age: Int?
    public var id: String
    public var name: String

    public init(age: Int? = nil, id: String, name: String) {
        self.age = age
        self.id = id
        self.name = name
    }
}

// MARK: - API Client

/// API Client for Parsed API (v1.0.0)
public struct APIClient {
    /// The base URL for the API.
    public let baseURL: URL
    /// The URL session used for networking.
    public let session: URLSession

    /// Initializes a new API Client.
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

}


