import Foundation

@propertyWrapper
/// Documentation for Minimum
public struct Minimum<Value: Comparable & Codable>: Codable, Equatable {
    /// Documentation for wrappedValue
    public var wrappedValue: Value
    /// Documentation for minimumValue
    public let minimumValue: Value

    /// Documentation for initializer
    public init(wrappedValue: Value, _ minimumValue: Value) {
        self.wrappedValue = wrappedValue
        self.minimumValue = minimumValue
    }
}

@propertyWrapper
/// Documentation for Maximum
public struct Maximum<Value: Comparable & Codable>: Codable, Equatable {
    /// Documentation for wrappedValue
    public var wrappedValue: Value
    /// Documentation for maximumValue
    public let maximumValue: Value

    /// Documentation for initializer
    public init(wrappedValue: Value, _ maximumValue: Value) {
        self.wrappedValue = wrappedValue
        self.maximumValue = maximumValue
    }
}

@propertyWrapper
/// Documentation for MinLength
public struct MinLength: Codable, Equatable {
    /// Documentation for wrappedValue
    public var wrappedValue: String
    /// Documentation for minLength
    public let minLength: Int

    /// Documentation for initializer
    public init(wrappedValue: String, _ minLength: Int) {
        self.wrappedValue = wrappedValue
        self.minLength = minLength
    }
}

@propertyWrapper
/// Documentation for MaxLength
public struct MaxLength: Codable, Equatable {
    /// Documentation for wrappedValue
    public var wrappedValue: String
    /// Documentation for maxLength
    public let maxLength: Int

    /// Documentation for initializer
    public init(wrappedValue: String, _ maxLength: Int) {
        self.wrappedValue = wrappedValue
        self.maxLength = maxLength
    }
}

@propertyWrapper
/// Documentation for Pattern
public struct Pattern: Codable, Equatable {
    /// Documentation for wrappedValue
    public var wrappedValue: String
    /// Documentation for pattern
    public let pattern: String

    /// Documentation for initializer
    public init(wrappedValue: String, _ pattern: String) {
        self.wrappedValue = wrappedValue
        self.pattern = pattern
    }
}
