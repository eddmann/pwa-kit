import Foundation

// MARK: - AnyCodable

/// A type-erased wrapper for encoding and decoding arbitrary JSON values.
///
/// `AnyCodable` supports all JSON-compatible types:
/// - `nil`
/// - `Bool`
/// - `Int`, `Double` (numbers)
/// - `String`
/// - `[AnyCodable]` (arrays)
/// - `[String: AnyCodable]` (objects)
///
/// ## Example
///
/// ```swift
/// let payload = AnyCodable([
///     "style": AnyCodable("medium"),
///     "intensity": AnyCodable(0.8)
/// ])
///
/// let data = try JSONEncoder().encode(payload)
/// // {"style":"medium","intensity":0.8}
/// ```
public struct AnyCodable: Codable, Sendable, Equatable {
    /// The wrapped value.
    private let storage: Storage

    /// Internal storage for type-erased values.
    private enum Storage: Sendable, Equatable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case dictionary([String: AnyCodable])
    }

    // MARK: - Initializers

    /// Creates an `AnyCodable` wrapping `nil`.
    public init() {
        self.storage = .null
    }

    /// Creates an `AnyCodable` wrapping `nil`.
    public static var null: AnyCodable {
        AnyCodable()
    }

    /// Creates an `AnyCodable` wrapping a Boolean value.
    public init(_ value: Bool) {
        self.storage = .bool(value)
    }

    /// Creates an `AnyCodable` wrapping an integer value.
    public init(_ value: Int) {
        self.storage = .int(value)
    }

    /// Creates an `AnyCodable` wrapping a double value.
    public init(_ value: Double) {
        self.storage = .double(value)
    }

    /// Creates an `AnyCodable` wrapping a string value.
    public init(_ value: String) {
        self.storage = .string(value)
    }

    /// Creates an `AnyCodable` wrapping an array of `AnyCodable` values.
    public init(_ value: [AnyCodable]) {
        self.storage = .array(value)
    }

    /// Creates an `AnyCodable` wrapping a dictionary of `AnyCodable` values.
    public init(_ value: [String: AnyCodable]) {
        self.storage = .dictionary(value)
    }

    // MARK: - Value Access

    /// Returns the wrapped value as its underlying type, or `nil` if the cast fails.
    public var value: Any? {
        switch storage {
        case .null:
            nil
        case let .bool(value):
            value
        case let .int(value):
            value
        case let .double(value):
            value
        case let .string(value):
            value
        case let .array(value):
            value.map(\.value)
        case let .dictionary(value):
            value.mapValues { $0.value }
        }
    }

    /// Returns the wrapped value as a Boolean, or `nil` if not a Boolean.
    public var boolValue: Bool? {
        if case let .bool(value) = storage { return value }
        return nil
    }

    /// Returns the wrapped value as an Int, or `nil` if not an Int.
    public var intValue: Int? {
        switch storage {
        case let .int(value):
            value
        case let .double(value) where value == Double(Int(value)):
            Int(value)
        default:
            nil
        }
    }

    /// Returns the wrapped value as a Double, or `nil` if not a number.
    public var doubleValue: Double? {
        switch storage {
        case let .int(value):
            Double(value)
        case let .double(value):
            value
        default:
            nil
        }
    }

    /// Returns the wrapped value as a String, or `nil` if not a String.
    public var stringValue: String? {
        if case let .string(value) = storage { return value }
        return nil
    }

    /// Returns the wrapped value as an array, or `nil` if not an array.
    public var arrayValue: [AnyCodable]? {
        if case let .array(value) = storage { return value }
        return nil
    }

    /// Returns the wrapped value as a dictionary, or `nil` if not a dictionary.
    public var dictionaryValue: [String: AnyCodable]? {
        if case let .dictionary(value) = storage { return value }
        return nil
    }

    /// Returns `true` if the wrapped value is `nil`.
    public var isNull: Bool {
        if case .null = storage { return true }
        return false
    }

    // MARK: - Subscript

    /// Accesses the value at the given key if the wrapped value is a dictionary.
    public subscript(key: String) -> AnyCodable? {
        dictionaryValue?[key]
    }

    /// Accesses the value at the given index if the wrapped value is an array.
    public subscript(index: Int) -> AnyCodable? {
        guard let array = arrayValue, array.indices.contains(index) else { return nil }
        return array[index]
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.storage = .null
        } else if let bool = try? container.decode(Bool.self) {
            self.storage = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self.storage = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self.storage = .double(double)
        } else if let string = try? container.decode(String.self) {
            self.storage = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.storage = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.storage = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch storage {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .dictionary(value):
            try container.encode(value)
        }
    }
}

// MARK: ExpressibleByNilLiteral

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self.storage = .null
    }
}

// MARK: ExpressibleByBooleanLiteral

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.storage = .bool(value)
    }
}

// MARK: ExpressibleByIntegerLiteral

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.storage = .int(value)
    }
}

// MARK: ExpressibleByFloatLiteral

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.storage = .double(value)
    }
}

// MARK: ExpressibleByStringLiteral

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.storage = .string(value)
    }
}

// MARK: ExpressibleByArrayLiteral

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyCodable...) {
        self.storage = .array(elements)
    }
}

// MARK: ExpressibleByDictionaryLiteral

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AnyCodable)...) {
        self.storage = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: CustomStringConvertible

extension AnyCodable: CustomStringConvertible {
    public var description: String {
        switch storage {
        case .null:
            "null"
        case let .bool(value):
            value.description
        case let .int(value):
            value.description
        case let .double(value):
            value.description
        case let .string(value):
            "\"\(value)\""
        case let .array(value):
            value.description
        case let .dictionary(value):
            value.description
        }
    }
}
