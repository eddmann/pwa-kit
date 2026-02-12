import Foundation

@testable import PWAKitApp

// MARK: - TestModule

/// A comprehensive test module for bridge integration testing.
///
/// `TestModule` provides a variety of actions useful for testing the complete
/// message flow through the bridge system:
/// - `echo`: Returns the payload unmodified
/// - `error`: Throws a configurable error
/// - `delay`: Simulates async work with a configurable delay
/// - `getInfo`: Returns module information
///
/// ## Example
///
/// ```swift
/// let dispatcher = BridgeDispatcher()
/// await dispatcher.register(TestModule())
///
/// let message = BridgeMessage(
///     id: "test-1",
///     module: "test",
///     action: "echo",
///     payload: AnyCodable(["key": AnyCodable("value")])
/// )
///
/// let response = await dispatcher.dispatch(message: message, context: context)
/// // response.data contains {"key": "value"}
/// ```
public struct TestModule: PWAModule {
    public static let moduleName = "test"
    public static let supportedActions = ["echo", "error", "delay", "getInfo"]

    /// Creates a new test module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        switch action {
        case "echo":
            return handleEcho(payload: payload)

        case "error":
            try handleError(payload: payload)
            return nil

        case "delay":
            return try await handleDelay(payload: payload)

        case "getInfo":
            return handleGetInfo()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Action Handlers

    /// Returns the payload unmodified.
    ///
    /// This action is useful for testing payload encoding/decoding roundtrips.
    ///
    /// - Parameter payload: The payload to echo back.
    /// - Returns: The same payload that was received.
    private func handleEcho(payload: AnyCodable?) -> AnyCodable? {
        payload
    }

    /// Throws an error based on the payload configuration.
    ///
    /// The payload can contain:
    /// - `type`: The error type ("bridge", "custom", or any string for generic error)
    /// - `message`: The error message
    ///
    /// If no payload is provided, throws a default error.
    ///
    /// - Parameter payload: Optional configuration for the error.
    /// - Throws: The configured error.
    private func handleError(payload: AnyCodable?) throws {
        let errorType = payload?["type"]?.stringValue ?? "generic"
        let message = payload?["message"]?.stringValue ?? "Test error"

        switch errorType {
        case "bridge":
            throw BridgeError.invalidPayload(message)
        case "custom":
            throw TestModuleError.customError(message)
        default:
            throw TestModuleError.genericError(message)
        }
    }

    /// Simulates async work with a configurable delay.
    ///
    /// The payload can contain:
    /// - `milliseconds`: The delay duration in milliseconds (default: 10)
    ///
    /// - Parameter payload: Optional configuration for the delay.
    /// - Returns: A response indicating completion.
    private func handleDelay(payload: AnyCodable?) async throws -> AnyCodable {
        let milliseconds = payload?["milliseconds"]?.intValue ?? 10
        let nanoseconds = UInt64(milliseconds) * 1_000_000

        try await Task.sleep(nanoseconds: nanoseconds)

        return AnyCodable([
            "completed": AnyCodable(true),
            "delayMs": AnyCodable(milliseconds),
        ])
    }

    /// Returns information about the test module.
    ///
    /// - Returns: Module information including name, version, and supported actions.
    private func handleGetInfo() -> AnyCodable {
        AnyCodable([
            "name": AnyCodable(Self.moduleName),
            "version": AnyCodable("1.0.0"),
            "actions": AnyCodable(Self.supportedActions.map { AnyCodable($0) }),
        ])
    }
}

// MARK: - TestModuleError

/// Errors that can be thrown by the test module.
public enum TestModuleError: Error, LocalizedError, Equatable {
    /// A generic test error.
    case genericError(String)

    /// A custom test error for testing error handling.
    case customError(String)

    public var errorDescription: String? {
        switch self {
        case let .genericError(message):
            "Test error: \(message)"
        case let .customError(message):
            "Custom error: \(message)"
        }
    }
}
