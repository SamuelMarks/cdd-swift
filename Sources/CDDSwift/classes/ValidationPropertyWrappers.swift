/// Property wrappers enforcing OpenAPI numeric and string validation constraints at runtime.
import Foundation

@propertyWrapper
/// Property wrapper that validates a numeric or comparable value against an inclusive minimum boundary.
public struct Minimum<Value: Comparable & Codable>: Codable, Equatable {
    /// The underlying value being validated.
    public var wrappedValue: Value
    /// The inclusive lower bound required for `wrappedValue`.
    public let minValue: Value

    /// Initializes the `Minimum` wrapper and validates the initial value.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - minValue: The inclusive minimum bound.
    public init(wrappedValue: Value, _ minValue: Value) {
        self.wrappedValue = wrappedValue
        self.minValue = minValue
    }

    /// Validates that `wrappedValue` is greater than or equal to `minValue`.
    ///
    /// - Throws: `CDDError.validationFailed` if `wrappedValue < minValue`.
    public func validate() throws {
        if wrappedValue < minValue {
            throw CDDError.validationFailed(field: "Minimum", reason: "Value \(wrappedValue) is less than minimum \(minValue)")
        }
    }
}

extension Minimum: Sendable where Value: Sendable {}

@propertyWrapper
/// Property wrapper that validates a numeric or comparable value against an inclusive maximum boundary.
public struct Maximum<Value: Comparable & Codable>: Codable, Equatable {
    /// The underlying value being validated.
    public var wrappedValue: Value
    /// The inclusive upper bound required for `wrappedValue`.
    public let maxValue: Value

    /// Initializes the `Maximum` wrapper and stores the upper bound.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value.
    ///   - maxValue: The inclusive maximum bound.
    public init(wrappedValue: Value, _ maxValue: Value) {
        self.wrappedValue = wrappedValue
        self.maxValue = maxValue
    }

    /// Validates that `wrappedValue` is less than or equal to `maxValue`.
    ///
    /// - Throws: `CDDError.validationFailed` if `wrappedValue > maxValue`.
    public func validate() throws {
        if wrappedValue > maxValue {
            throw CDDError.validationFailed(field: "Maximum", reason: "Value \(wrappedValue) exceeds maximum \(maxValue)")
        }
    }
}

extension Maximum: Sendable where Value: Sendable {}

@propertyWrapper
/// Property wrapper that validates a `String` against a minimum character length.
public struct MinLength: Codable, Equatable, Sendable {
    /// The underlying string value.
    public var wrappedValue: String
    /// The inclusive minimum character count.
    public let length: Int

    /// Initializes the `MinLength` wrapper.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial string value.
    ///   - length: The minimum allowed character count.
    public init(wrappedValue: String, _ length: Int) {
        self.wrappedValue = wrappedValue
        self.length = length
    }

    /// Validates that `wrappedValue.count` is at least `length`.
    ///
    /// - Throws: `CDDError.validationFailed` if `wrappedValue.count < length`.
    public func validate() throws {
        if wrappedValue.count < length {
            throw CDDError.validationFailed(field: "MinLength", reason: "String length \(wrappedValue.count) is less than minimum \(length)")
        }
    }
}

@propertyWrapper
/// Property wrapper that validates a `String` against a maximum character length.
public struct MaxLength: Codable, Equatable, Sendable {
    /// The underlying string value.
    public var wrappedValue: String
    /// The inclusive maximum character count.
    public let length: Int

    /// Initializes the `MaxLength` wrapper.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial string value.
    ///   - length: The maximum allowed character count.
    public init(wrappedValue: String, _ length: Int) {
        self.wrappedValue = wrappedValue
        self.length = length
    }

    /// Validates that `wrappedValue.count` does not exceed `length`.
    ///
    /// - Throws: `CDDError.validationFailed` if `wrappedValue.count > length`.
    public func validate() throws {
        if wrappedValue.count > length {
            throw CDDError.validationFailed(field: "MaxLength", reason: "String length \(wrappedValue.count) exceeds maximum \(length)")
        }
    }
}

@propertyWrapper
/// Property wrapper that validates a `String` against a regular expression pattern.
public struct Pattern: Codable, Equatable, Sendable {
    /// The underlying string value.
    public var wrappedValue: String
    /// The regular expression pattern string.
    public let pattern: String

    /// Initializes the `Pattern` wrapper.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial string value.
    ///   - pattern: The regular expression pattern to match.
    public init(wrappedValue: String, _ pattern: String) {
        self.wrappedValue = wrappedValue
        self.pattern = pattern
    }

    /// Validates that `wrappedValue` matches `pattern`.
    ///
    /// - Throws: `CDDError.validationFailed` if `wrappedValue` does not match `pattern`.
    public func validate() throws {
        if wrappedValue.range(of: pattern, options: .regularExpression) == nil {
            throw CDDError.validationFailed(field: "Pattern", reason: "String '\(wrappedValue)' does not match pattern '\(pattern)'")
        }
    }
}
