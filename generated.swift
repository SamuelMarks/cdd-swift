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
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
}

// MARK: - Mocks

public class MockAPIClient {
    public init() {}
}

// MARK: - Tests Stub

import XCTest

final class APIClientTests: XCTestCase {
    func testExample() async throws {
        XCTAssertTrue(true)
    }
}
