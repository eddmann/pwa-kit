import Foundation
import UIKit
import UserNotifications

// MARK: - NotificationsModule

/// A module that provides push notification capabilities to JavaScript.
///
/// `NotificationsModule` exposes APNs push notification registration and
/// permission management to web applications.
///
/// ## Supported Actions
///
/// - `subscribe`: Request permission and register for remote notifications.
/// - `getToken`: Retrieve the stored device token.
/// - `getPermissionState`: Query the current notification permission state.
/// - `setBadge`: Set the app icon badge count.
///
/// ## Example
///
/// JavaScript request to subscribe:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "notifications",
///   "action": "subscribe"
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": {
///     "success": true,
///     "token": "abc123def456...",
///     "permissionState": "granted"
///   }
/// }
/// ```
///
/// JavaScript request to get permission state:
/// ```json
/// {
///   "id": "def-456",
///   "module": "notifications",
///   "action": "getPermissionState"
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": { "state": "granted" }
/// }
/// ```
///
/// JavaScript request to set badge:
/// ```json
/// {
///   "id": "ghi-789",
///   "module": "notifications",
///   "action": "setBadge",
///   "payload": { "count": 5 }
/// }
/// ```
public struct NotificationsModule: PWAModule {
    public static let moduleName = "notifications"
    public static let supportedActions = ["subscribe", "getToken", "getPermissionState", "setBadge"]

    /// The UserDefaults key used for storing the device token.
    public static let deviceTokenKey = "PWAKit.deviceToken"

    /// Storage provider for the device token.
    private let storage: TokenStorage

    /// The notification center to use for permission requests.
    private let notificationCenter: NotificationCenterProtocol

    /// Creates a new notifications module instance.
    ///
    /// - Parameters:
    ///   - storage: Token storage provider. Defaults to UserDefaults.
    ///   - notificationCenter: Notification center for permission requests.
    ///     Defaults to the current UNUserNotificationCenter.
    public init(
        storage: TokenStorage = UserDefaultsTokenStorage(),
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenterWrapper()
    ) {
        self.storage = storage
        self.notificationCenter = notificationCenter
    }

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "subscribe":
            return try await handleSubscribe()

        case "getToken":
            return handleGetToken()

        case "getPermissionState":
            return try await handleGetPermissionState()

        case "setBadge":
            return try await handleSetBadge(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Subscribe

    /// Handles the `subscribe` action to request permission and register for remote notifications.
    ///
    /// This method:
    /// 1. Requests notification permission from the user
    /// 2. If granted, triggers remote notification registration
    /// 3. Returns the current permission state and any stored token
    ///
    /// Note: The actual device token is received asynchronously via AppDelegate's
    /// `didRegisterForRemoteNotificationsWithDeviceToken` callback. This method
    /// returns the currently stored token, which may be from a previous registration.
    ///
    /// - Returns: A `NotificationSubscription` result.
    private func handleSubscribe() async throws -> AnyCodable {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])

        if granted {
            // Request registration for remote notifications
            await registerForRemoteNotifications()

            // Get the current permission state
            let state = await getPermissionState()

            // Return the stored token if available
            if let token = storage.getToken() {
                let subscription = NotificationSubscription(token: token, permissionState: state)
                return encodeSubscription(subscription)
            } else {
                // Token not yet available, return success with pending state
                let subscription = NotificationSubscription(
                    success: true,
                    token: nil,
                    permissionState: state,
                    error: nil
                )
                return encodeSubscription(subscription)
            }
        } else {
            // Permission denied
            let state = await getPermissionState()
            let subscription = NotificationSubscription(
                error: "User denied notification permission",
                permissionState: state
            )
            return encodeSubscription(subscription)
        }
    }

    /// Registers for remote notifications on the main thread.
    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Get Token

    /// Handles the `getToken` action to retrieve the stored device token.
    ///
    /// - Returns: The stored device token, or null if not available.
    private func handleGetToken() -> AnyCodable {
        if let token = storage.getToken() {
            AnyCodable(["token": AnyCodable(token)])
        } else {
            AnyCodable(["token": AnyCodable.null])
        }
    }

    // MARK: - Get Permission State

    /// Handles the `getPermissionState` action to query the notification permission state.
    ///
    /// - Returns: The current permission state.
    private func handleGetPermissionState() async throws -> AnyCodable {
        let state = await getPermissionState()
        return AnyCodable(["state": AnyCodable(state.rawValue)])
    }

    /// Gets the current notification permission state from UNUserNotificationCenter.
    private func getPermissionState() async -> NotificationPermissionState {
        let status = await notificationCenter.getAuthorizationStatus()
        return mapAuthorizationStatus(status)
    }

    /// Maps UNAuthorizationStatus to NotificationPermissionState.
    ///
    /// - Parameter status: The authorization status from UNUserNotificationCenter.
    /// - Returns: The corresponding permission state.
    func mapAuthorizationStatus(_ status: UNAuthorizationStatus) -> NotificationPermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized,
             .provisional:
            return .granted
        case .ephemeral:
            return .granted
        @unknown default:
            return .unknown
        }
    }

    // MARK: - Set Badge

    /// Handles the `setBadge` action to set the app icon badge count.
    ///
    /// - Parameter payload: Dictionary containing a `count` key with the badge number.
    /// - Returns: Success indicator.
    /// - Throws: `BridgeError.invalidPayload` if count is missing or invalid.
    private func handleSetBadge(payload: AnyCodable?) async throws -> AnyCodable {
        guard let count = payload?["count"]?.intValue else {
            throw BridgeError.invalidPayload("Missing or invalid 'count' field")
        }

        guard count >= 0 else {
            throw BridgeError.invalidPayload("Badge count must be non-negative")
        }

        await setBadgeCount(count)

        return AnyCodable(["success": AnyCodable(true)])
    }

    /// Sets the badge count on the main thread.
    @MainActor
    private func setBadgeCount(_ count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    // MARK: - Helpers

    /// Encodes a subscription result to AnyCodable.
    private func encodeSubscription(_ subscription: NotificationSubscription) -> AnyCodable {
        var result: [String: AnyCodable] = [
            "success": AnyCodable(subscription.success),
            "permissionState": AnyCodable(subscription.permissionState.rawValue),
        ]

        if let token = subscription.token {
            result["token"] = AnyCodable(token)
        }

        if let error = subscription.error {
            result["error"] = AnyCodable(error)
        }

        return AnyCodable(result)
    }
}

// MARK: - TokenStorage

/// Protocol for storing and retrieving the device token.
public protocol TokenStorage: Sendable {
    /// Retrieves the stored device token.
    /// - Returns: The device token as a hex string, or nil if not stored.
    func getToken() -> String?

    /// Stores the device token.
    /// - Parameter token: The device token as a hex string.
    func setToken(_ token: String)

    /// Clears the stored device token.
    func clearToken()
}

// MARK: - UserDefaultsTokenStorage

/// Default token storage using UserDefaults.
public final class UserDefaultsTokenStorage: TokenStorage, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    /// Creates a UserDefaults-based token storage.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use. Defaults to standard.
    ///   - key: The key for storing the token. Defaults to `PWAKit.deviceToken`.
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = NotificationsModule.deviceTokenKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func getToken() -> String? {
        userDefaults.string(forKey: key)
    }

    public func setToken(_ token: String) {
        userDefaults.set(token, forKey: key)
    }

    public func clearToken() {
        userDefaults.removeObject(forKey: key)
    }
}

// MARK: - NotificationCenterProtocol

/// Protocol abstracting UNUserNotificationCenter for testing.
public protocol NotificationCenterProtocol: Sendable {
    /// Requests authorization for notification options.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Gets the current authorization status.
    func getAuthorizationStatus() async -> UNAuthorizationStatus
}

// MARK: - UNUserNotificationCenterWrapper

/// Wrapper around UNUserNotificationCenter that conforms to NotificationCenterProtocol.
public struct UNUserNotificationCenterWrapper: NotificationCenterProtocol {
    public init() {}

    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    public func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

// MARK: - Device Token Helpers

/// Extension for converting device token data to hex string.
extension Data {
    /// Converts the data to a hex-encoded string.
    ///
    /// This is useful for converting APNs device token data to a string format
    /// that can be sent to a push notification server.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(
    ///     _ application: UIApplication,
    ///     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    /// ) {
    ///     let tokenString = deviceToken.hexEncodedString()
    ///     // "abc123def456..."
    /// }
    /// ```
    public func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
