import Foundation

@propertyWrapper
/// Validates a minimum boundary.
public struct Minimum<Value: Comparable & Codable>: Codable, Equatable {
    /// Wrapped value.
    public var wrappedValue: Value
    /// Minimum value.
    public let minimumValue: Value

    /// Initializer.
    public init(wrappedValue: Value, _ minimumValue: Value) {
        self.wrappedValue = wrappedValue
        self.minimumValue = minimumValue
    }
}

@propertyWrapper
/// Validates a maximum boundary.
public struct Maximum<Value: Comparable & Codable>: Codable, Equatable {
    /// Wrapped value.
    public var wrappedValue: Value
    /// Maximum value.
    public let maximumValue: Value

    /// Initializer.
    public init(wrappedValue: Value, _ maximumValue: Value) {
        self.wrappedValue = wrappedValue
        self.maximumValue = maximumValue
    }
}

@propertyWrapper
/// Validates a minimum string length.
public struct MinLength: Codable, Equatable {
    /// Wrapped value.
    public var wrappedValue: String
    /// Minimum length.
    public let minLength: Int

    /// Initializer.
    public init(wrappedValue: String, _ minLength: Int) {
        self.wrappedValue = wrappedValue
        self.minLength = minLength
    }
}

@propertyWrapper
/// Validates a maximum string length.
public struct MaxLength: Codable, Equatable {
    /// Wrapped value.
    public var wrappedValue: String
    /// Maximum length.
    public let maxLength: Int

    /// Initializer.
    public init(wrappedValue: String, _ maxLength: Int) {
        self.wrappedValue = wrappedValue
        self.maxLength = maxLength
    }
}

@propertyWrapper
/// Validates a regex pattern.
public struct Pattern: Codable, Equatable {
    /// Wrapped value.
    public var wrappedValue: String
    /// Pattern.
    public let pattern: String

    /// Initializer.
    public init(wrappedValue: String, _ pattern: String) {
        self.wrappedValue = wrappedValue
        self.pattern = pattern
    }
}
