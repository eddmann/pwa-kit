import Foundation

// MARK: - PWAModule

/// Protocol for native bridge modules that handle JavaScript requests.
///
/// `PWAModule` defines the contract for implementing native modules that
/// can be invoked from JavaScript through the bridge. Each module:
/// - Has a unique name for routing messages
/// - Declares its supported actions
/// - Handles incoming messages asynchronously
///
/// ## Implementation Requirements
///
/// Modules must be `Sendable` to ensure thread-safe access from the
/// bridge dispatcher actor. The `handle` method is called on an
/// arbitrary executor and must be safe for concurrent use.
///
/// ## Example
///
/// ```swift
/// struct PlatformModule: PWAModule {
///     static let moduleName = "platform"
///     static let supportedActions = ["getInfo"]
///
///     func handle(
///         action: String,
///         payload: AnyCodable?,
///         context: ModuleContext
///     ) async throws -> AnyCodable? {
///         switch action {
///         case "getInfo":
///             return AnyCodable([
///                 "platform": AnyCodable("iOS"),
///                 "version": AnyCodable(UIDevice.current.systemVersion)
///             ])
///         default:
///             throw BridgeError.unknownAction(action)
///         }
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// The module protocol requires `Sendable` conformance. Implementations
/// should either:
/// - Be value types without mutable state
/// - Use actors for any mutable state
/// - Mark mutable state with `@unchecked Sendable` if manually synchronized
public protocol PWAModule: Sendable {
    /// The unique name of this module.
    ///
    /// This name is used for routing messages from JavaScript.
    /// It should match the `module` field in `BridgeMessage`.
    ///
    /// Examples: `"platform"`, `"haptics"`, `"notifications"`
    static var moduleName: String { get }

    /// The list of actions this module supports.
    ///
    /// This array is used for validation and documentation.
    /// Each action name should match the `action` field in `BridgeMessage`.
    ///
    /// Examples: `["getInfo"]`, `["impact", "notification", "selection"]`
    static var supportedActions: [String] { get }

    /// Handles an action request from the JavaScript bridge.
    ///
    /// This method is called by the `BridgeDispatcher` when a message
    /// targeting this module is received. The implementation should:
    /// 1. Validate the action is supported
    /// 2. Parse the payload if needed
    /// 3. Perform the requested operation
    /// 4. Return any result data
    ///
    /// - Parameters:
    ///   - action: The action name from the bridge message.
    ///   - payload: The optional payload containing action-specific data.
    ///   - context: The module context providing access to app resources.
    ///
    /// - Returns: Optional result data to send back to JavaScript.
    ///
    /// - Throws: `BridgeError.unknownAction` if the action is not supported,
    ///           `BridgeError.invalidPayload` if payload parsing fails,
    ///           or any module-specific error.
    func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable?
}

// MARK: - Default Implementations

extension PWAModule {
    /// Checks whether this module supports the given action.
    ///
    /// - Parameter action: The action name to check.
    /// - Returns: `true` if the action is in `supportedActions`.
    public static func supports(action: String) -> Bool {
        supportedActions.contains(action)
    }

    /// Validates that the action is supported, throwing if not.
    ///
    /// - Parameter action: The action name to validate.
    /// - Throws: `BridgeError.unknownAction` if not supported.
    public func validateAction(_ action: String) throws {
        guard Self.supports(action: action) else {
            throw BridgeError.unknownAction(action)
        }
    }
}
