import Foundation
import Security

// MARK: - KeychainHelper

/// A helper for securely storing and retrieving string values from the iOS Keychain.
///
/// `KeychainHelper` provides a simple interface for common Keychain operations:
/// - Save string values
/// - Retrieve string values
/// - Delete values
/// - Update existing values
///
/// All operations use the `kSecClassGenericPassword` class for storage.
///
/// ## Example
///
/// ```swift
/// let keychain = KeychainHelper()
///
/// // Save a value
/// try keychain.save("my-secret-token", forKey: "authToken")
///
/// // Retrieve a value
/// if let token = try keychain.retrieve(forKey: "authToken") {
///     print("Token: \(token)")
/// }
///
/// // Delete a value
/// try keychain.delete(forKey: "authToken")
/// ```
///
/// ## Thread Safety
///
/// `KeychainHelper` is thread-safe and can be used from any thread.
/// The Keychain APIs handle synchronization internally.
public struct KeychainHelper: Sendable {
    /// The service identifier used for Keychain entries.
    ///
    /// This groups all entries created by this helper together.
    /// Defaults to the app's bundle identifier.
    public let service: String

    /// The access group for shared Keychain access.
    ///
    /// Use this to share Keychain items between apps in the same App Group.
    /// When `nil`, items are only accessible by this app.
    public let accessGroup: String?

    /// Creates a new KeychainHelper instance.
    ///
    /// - Parameters:
    ///   - service: The service identifier. Defaults to the app's bundle identifier.
    ///   - accessGroup: Optional access group for shared Keychain access.
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.pwakit.securestorage",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Save

    /// Saves a string value to the Keychain.
    ///
    /// If a value already exists for the given key, it will be updated.
    ///
    /// - Parameters:
    ///   - value: The string value to save.
    ///   - key: The key to associate with the value.
    /// - Throws: `KeychainError` if the save operation fails.
    public func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First try to update existing item
        let updateStatus = try? update(data, forKey: key)
        if updateStatus == true {
            return
        }

        // If no existing item, add new one
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
    }

    // MARK: - Retrieve

    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The stored string value, or `nil` if not found.
    /// - Throws: `KeychainError` if the retrieval fails for reasons other than "not found".
    public func retrieve(forKey key: String) throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else
            {
                throw KeychainError.decodingFailed
            }
            return string

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.from(status: status)
        }
    }

    // MARK: - Delete

    /// Deletes a value from the Keychain.
    ///
    /// - Parameter key: The key to delete.
    /// - Throws: `KeychainError` if the deletion fails.
    ///           Does not throw if the key doesn't exist.
    public func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status: status)
        }
    }

    // MARK: - Update

    /// Updates an existing value in the Keychain.
    ///
    /// - Parameters:
    ///   - data: The new data to store.
    ///   - key: The key to update.
    /// - Returns: `true` if the update succeeded, `false` if the item doesn't exist.
    /// - Throws: `KeychainError` if the update fails for other reasons.
    @discardableResult
    private func update(_ data: Data, forKey key: String) throws -> Bool {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw KeychainError.from(status: status)
        }
    }

    // MARK: - Query Building

    /// Creates the base query dictionary for Keychain operations.
    ///
    /// - Parameter key: The key (account) to include in the query.
    /// - Returns: A dictionary suitable for Keychain API calls.
    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, Sendable, Equatable {
    /// Failed to encode the string value to data.
    case encodingFailed

    /// Failed to decode the data to a string value.
    case decodingFailed

    /// Item was not found in the Keychain.
    case itemNotFound

    /// Access to the Keychain was denied.
    case accessDenied

    /// A duplicate item already exists.
    case duplicateItem

    /// An unexpected error occurred.
    ///
    /// - Parameter status: The OSStatus code from the Keychain operation.
    case unexpectedError(OSStatus)

    /// Creates a `KeychainError` from an OSStatus code.
    ///
    /// - Parameter status: The OSStatus from a Keychain operation.
    /// - Returns: The corresponding `KeychainError`.
    public static func from(status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            .itemNotFound
        case errSecAuthFailed,
             errSecInteractionNotAllowed:
            .accessDenied
        case errSecDuplicateItem:
            .duplicateItem
        default:
            .unexpectedError(status)
        }
    }
}

// MARK: LocalizedError

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode value for Keychain storage"
        case .decodingFailed:
            "Failed to decode value from Keychain"
        case .itemNotFound:
            "Item not found in Keychain"
        case .accessDenied:
            "Access to Keychain was denied"
        case .duplicateItem:
            "Item already exists in Keychain"
        case let .unexpectedError(status):
            "Keychain error: \(status)"
        }
    }
}

// MARK: CustomStringConvertible

extension KeychainError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .encodingFailed:
            "KeychainError.encodingFailed"
        case .decodingFailed:
            "KeychainError.decodingFailed"
        case .itemNotFound:
            "KeychainError.itemNotFound"
        case .accessDenied:
            "KeychainError.accessDenied"
        case .duplicateItem:
            "KeychainError.duplicateItem"
        case let .unexpectedError(status):
            "KeychainError.unexpectedError(\(status))"
        }
    }
}
