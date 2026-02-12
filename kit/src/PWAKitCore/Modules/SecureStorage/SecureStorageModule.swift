import Foundation

/// A module that provides secure storage capabilities to JavaScript.
///
/// `SecureStorageModule` exposes iOS Keychain storage to web applications,
/// allowing them to securely store sensitive data like tokens, credentials,
/// and other secrets that persist across app launches.
///
/// ## Supported Actions
///
/// - `set(key, value)`: Store a value in the Keychain.
///   - `key`: The storage key (required)
///   - `value`: The string value to store (required)
///   - Returns: `{ success: true }` on success
///
/// - `get(key)`: Retrieve a value from the Keychain.
///   - `key`: The storage key (required)
///   - Returns: `{ value: "..." }` or `{ value: null }` if not found
///
/// - `delete(key)`: Remove a value from the Keychain.
///   - `key`: The storage key (required)
///   - Returns: `{ success: true }` on success
///
/// ## Example
///
/// JavaScript request to store a value:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "secureStorage",
///   "action": "set",
///   "payload": {
///     "key": "authToken",
///     "value": "eyJhbGciOiJIUzI1NiIs..."
///   }
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "success": true }
/// }
/// ```
///
/// JavaScript request to retrieve a value:
/// ```json
/// {
///   "id": "def-456",
///   "module": "secureStorage",
///   "action": "get",
///   "payload": { "key": "authToken" }
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": { "value": "eyJhbGciOiJIUzI1NiIs..." }
/// }
/// ```
///
/// JavaScript request to delete a value:
/// ```json
/// {
///   "id": "ghi-789",
///   "module": "secureStorage",
///   "action": "delete",
///   "payload": { "key": "authToken" }
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "ghi-789",
///   "success": true,
///   "data": { "success": true }
/// }
/// ```
///
/// ## Security Notes
///
/// - Values are stored in the iOS Keychain, encrypted at rest
/// - Data persists across app reinstalls (unless backup is excluded)
/// - Access is restricted to this app (unless access groups are configured)
public struct SecureStorageModule: PWAModule {
    public static let moduleName = "secureStorage"
    public static let supportedActions = ["set", "get", "delete"]

    /// The keychain helper used for storage operations.
    private let keychain: KeychainHelper

    /// Creates a new secure storage module instance.
    ///
    /// - Parameter keychain: Optional custom keychain helper. Defaults to a new instance.
    public init(keychain: KeychainHelper = KeychainHelper()) {
        self.keychain = keychain
    }

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "set":
            return try handleSet(payload: payload)

        case "get":
            return try handleGet(payload: payload)

        case "delete":
            return try handleDelete(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - set Action

    /// Handles the `set` action to store a value in the Keychain.
    ///
    /// - Parameter payload: Dictionary containing `key` and `value` strings.
    /// - Returns: A dictionary with `success: true`.
    /// - Throws: `BridgeError.invalidPayload` if key or value is missing.
    private func handleSet(payload: AnyCodable?) throws -> AnyCodable {
        guard let key = payload?["key"]?.stringValue, !key.isEmpty else {
            throw BridgeError.invalidPayload("Missing or empty 'key' parameter")
        }

        guard let value = payload?["value"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing 'value' parameter")
        }

        do {
            try keychain.save(value, forKey: key)
            return AnyCodable([
                "success": AnyCodable(true),
            ])
        } catch let error as KeychainError {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - get Action

    /// Handles the `get` action to retrieve a value from the Keychain.
    ///
    /// - Parameter payload: Dictionary containing `key` string.
    /// - Returns: A dictionary with `value` (string or null if not found).
    /// - Throws: `BridgeError.invalidPayload` if key is missing.
    private func handleGet(payload: AnyCodable?) throws -> AnyCodable {
        guard let key = payload?["key"]?.stringValue, !key.isEmpty else {
            throw BridgeError.invalidPayload("Missing or empty 'key' parameter")
        }

        do {
            let value = try keychain.retrieve(forKey: key)
            if let value {
                return AnyCodable([
                    "value": AnyCodable(value),
                ])
            } else {
                return AnyCodable([
                    "value": AnyCodable.null,
                ])
            }
        } catch let error as KeychainError {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - delete Action

    /// Handles the `delete` action to remove a value from the Keychain.
    ///
    /// - Parameter payload: Dictionary containing `key` string.
    /// - Returns: A dictionary with `success: true`.
    /// - Throws: `BridgeError.invalidPayload` if key is missing.
    private func handleDelete(payload: AnyCodable?) throws -> AnyCodable {
        guard let key = payload?["key"]?.stringValue, !key.isEmpty else {
            throw BridgeError.invalidPayload("Missing or empty 'key' parameter")
        }

        do {
            try keychain.delete(forKey: key)
            return AnyCodable([
                "success": AnyCodable(true),
            ])
        } catch let error as KeychainError {
            throw BridgeError.moduleError(underlying: error)
        }
    }
}
