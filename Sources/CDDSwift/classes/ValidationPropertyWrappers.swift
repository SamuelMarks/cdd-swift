import Foundation

@propertyWrapper
public struct Minimum<Value: Comparable & Codable>: Codable, Equatable {
    public var wrappedValue: Value
    public let minimumValue: Value
    
    public init(wrappedValue: Value, _ minimumValue: Value) {
        self.wrappedValue = wrappedValue
        self.minimumValue = minimumValue
    }
}

@propertyWrapper
public struct Maximum<Value: Comparable & Codable>: Codable, Equatable {
    public var wrappedValue: Value
    public let maximumValue: Value
    
    public init(wrappedValue: Value, _ maximumValue: Value) {
        self.wrappedValue = wrappedValue
        self.maximumValue = maximumValue
    }
}

@propertyWrapper
public struct MinLength: Codable, Equatable {
    public var wrappedValue: String
    public let minLength: Int
    
    public init(wrappedValue: String, _ minLength: Int) {
        self.wrappedValue = wrappedValue
        self.minLength = minLength
    }
}

@propertyWrapper
public struct MaxLength: Codable, Equatable {
    public var wrappedValue: String
    public let maxLength: Int
    
    public init(wrappedValue: String, _ maxLength: Int) {
        self.wrappedValue = wrappedValue
        self.maxLength = maxLength
    }
}

@propertyWrapper
public struct Pattern: Codable, Equatable {
    public var wrappedValue: String
    public let pattern: String
    
    public init(wrappedValue: String, _ pattern: String) {
        self.wrappedValue = wrappedValue
        self.pattern = pattern
    }
}
