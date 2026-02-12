import Foundation

// MARK: - BridgeError

/// Errors that can occur during bridge message handling.
///
/// `BridgeError` represents failures that occur when processing messages
/// from JavaScript to native code. These errors are returned to JavaScript
/// as error responses with localized descriptions.
///
/// ## Error Cases
///
/// - `unknownModule`: The requested module is not registered.
/// - `unknownAction`: The action is not supported by the module.
/// - `invalidPayload`: The payload could not be decoded.
/// - `moduleError`: An error occurred within the module implementation.
///
/// ## Example
///
/// ```swift
/// // Return an error response for an unknown module
/// let error = BridgeError.unknownModule("widgets")
/// let response = BridgeResponse.failure(
///     id: message.id,
///     error: error.localizedDescription
/// )
/// ```
public enum BridgeError: Error, Sendable, Equatable {
    /// The requested module is not registered.
    ///
    /// - Parameter name: The name of the unknown module.
    case unknownModule(String)

    /// The action is not supported by the module.
    ///
    /// - Parameter name: The name of the unknown action.
    case unknownAction(String)

    /// The payload could not be decoded.
    ///
    /// - Parameter reason: A description of why decoding failed.
    case invalidPayload(String)

    /// An error occurred within the module implementation.
    ///
    /// - Parameter underlying: The underlying error from the module.
    case moduleError(underlying: any Error)

    // MARK: - Equatable

    public static func == (lhs: BridgeError, rhs: BridgeError) -> Bool {
        switch (lhs, rhs) {
        case let (.unknownModule(lhsName), .unknownModule(rhsName)):
            lhsName == rhsName
        case let (.unknownAction(lhsName), .unknownAction(rhsName)):
            lhsName == rhsName
        case let (.invalidPayload(lhsReason), .invalidPayload(rhsReason)):
            lhsReason == rhsReason
        case let (.moduleError(lhsError), .moduleError(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        default:
            false
        }
    }
}

// MARK: LocalizedError

extension BridgeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unknownModule(name):
            "Unknown module: \(name)"
        case let .unknownAction(name):
            "Unknown action: \(name)"
        case let .invalidPayload(reason):
            "Invalid payload: \(reason)"
        case let .moduleError(underlying):
            "Module error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: CustomStringConvertible

extension BridgeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unknownModule(name):
            "BridgeError.unknownModule(\"\(name)\")"
        case let .unknownAction(name):
            "BridgeError.unknownAction(\"\(name)\")"
        case let .invalidPayload(reason):
            "BridgeError.invalidPayload(\"\(reason)\")"
        case let .moduleError(underlying):
            "BridgeError.moduleError(\(underlying))"
        }
    }
}
