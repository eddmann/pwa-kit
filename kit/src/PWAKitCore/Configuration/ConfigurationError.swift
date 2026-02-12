import Foundation

// MARK: - ConfigurationError

/// Errors that can occur during configuration loading and parsing.
///
/// `ConfigurationError` represents all possible failures when loading
/// configuration from various sources (bundle, documents directory, etc.).
///
/// ## Example
///
/// ```swift
/// do {
///     let config = try await ConfigurationLoader.load()
/// } catch let error as ConfigurationError {
///     switch error {
///     case .fileNotFound(let source):
///         print("Config file not found in: \(source)")
///     case .invalidJSON(let underlying):
///         print("JSON parsing failed: \(underlying)")
///     case .validation(let validationError):
///         print("Validation failed: \(validationError)")
///     }
/// }
/// ```
public enum ConfigurationError: Error, Equatable, Sendable {
    /// The configuration file was not found at the expected location.
    case fileNotFound(source: String)

    /// The configuration file could not be read.
    case unableToRead(source: String, reason: String)

    /// The configuration file contains invalid JSON.
    case invalidJSON(reason: String)

    /// The configuration failed validation.
    case validation(ConfigurationValidationError)

    /// An unexpected error occurred during loading.
    case unexpected(reason: String)
}

// MARK: LocalizedError

extension ConfigurationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(source):
            "Configuration file not found: \(source)"
        case let .unableToRead(source, reason):
            "Unable to read configuration from \(source): \(reason)"
        case let .invalidJSON(reason):
            "Invalid JSON in configuration file: \(reason)"
        case let .validation(validationError):
            "Configuration validation failed: \(validationError.localizedDescription)"
        case let .unexpected(reason):
            "Unexpected configuration error: \(reason)"
        }
    }
}
