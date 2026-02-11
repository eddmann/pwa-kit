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
    public static let supportedActions = [
        "subscribe",
        "requestPermission",
        "getToken",
        "getPermissionState",
        "setBadge",
        "schedule",
        "cancel",
        "cancelAll",
        "getPending",
    ]

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

        case "requestPermission":
            return try await handleRequestPermission()

        case "getToken":
            return handleGetToken()

        case "getPermissionState":
            return try await handleGetPermissionState()

        case "setBadge":
            return try await handleSetBadge(payload: payload)

        case "schedule":
            return try await handleSchedule(payload: payload)

        case "cancel":
            return try handleCancel(payload: payload)

        case "cancelAll":
            return handleCancelAll()

        case "getPending":
            return try await handleGetPending()

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

    // MARK: - Request Permission

    /// Handles the `requestPermission` action to request notification permission only.
    ///
    /// Unlike `subscribe`, this does not register for remote notifications.
    /// Useful for local notifications that only need user permission.
    ///
    /// - Returns: The resulting permission state.
    private func handleRequestPermission() async throws -> AnyCodable {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        let state = await getPermissionState()

        return AnyCodable([
            "granted": AnyCodable(granted),
            "state": AnyCodable(state.rawValue),
        ])
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

    // MARK: - Schedule

    /// Handles the `schedule` action to schedule a local notification.
    ///
    /// - Parameter payload: The schedule notification request.
    /// - Returns: Success result with the notification ID.
    /// - Throws: `BridgeError.invalidPayload` if the request is invalid.
    private func handleSchedule(payload: AnyCodable?) async throws -> AnyCodable {
        guard let payloadDict = payload?.dictionaryValue else {
            throw BridgeError.invalidPayload("Missing schedule notification payload")
        }

        // Decode the request
        let request = try decodeScheduleRequest(from: payloadDict)

        // Validate the request
        try validateScheduleRequest(request)

        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = request.title

        if let body = request.body {
            content.body = body
        }
        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }
        if let badge = request.badge {
            content.badge = NSNumber(value: badge)
        }
        if let sound = request.sound {
            content.sound = sound == "default" ? .default : UNNotificationSound(named: UNNotificationSoundName(sound))
        }
        if let data = request.data {
            content.userInfo = data.mapValues { $0.value as Any }
        }

        // Create the trigger
        let trigger = try createTrigger(from: request.trigger)

        // Create and schedule the request
        let notificationRequest = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(notificationRequest)

        return AnyCodable(["success": AnyCodable(true), "id": AnyCodable(request.id)])
    }

    /// Decodes a schedule request from a dictionary.
    private func decodeScheduleRequest(from dict: [String: AnyCodable]) throws -> ScheduleNotificationRequest {
        guard let id = dict["id"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing 'id' field")
        }
        guard let title = dict["title"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing 'title' field")
        }
        guard let triggerDict = dict["trigger"]?.dictionaryValue else {
            throw BridgeError.invalidPayload("Missing 'trigger' field")
        }

        let trigger = try decodeTrigger(from: triggerDict)

        return ScheduleNotificationRequest(
            id: id,
            title: title,
            body: dict["body"]?.stringValue,
            subtitle: dict["subtitle"]?.stringValue,
            badge: dict["badge"]?.intValue,
            sound: dict["sound"]?.stringValue,
            data: dict["data"]?.dictionaryValue,
            trigger: trigger
        )
    }

    /// Decodes a trigger from a dictionary.
    private func decodeTrigger(from dict: [String: AnyCodable]) throws -> NotificationTrigger {
        guard let type = dict["type"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing trigger 'type' field")
        }

        switch type {
        case "timeInterval":
            guard let seconds = dict["seconds"]?.doubleValue else {
                throw BridgeError.invalidPayload("Missing 'seconds' field for timeInterval trigger")
            }
            let repeats = dict["repeats"]?.boolValue ?? false
            return .timeInterval(seconds: seconds, repeats: repeats)

        case "date":
            guard let dateString = dict["date"]?.stringValue else {
                throw BridgeError.invalidPayload("Missing 'date' field for date trigger")
            }
            guard let date = ISO8601DateFormatter().date(from: dateString) else {
                throw BridgeError.invalidPayload("Invalid ISO8601 date format")
            }
            return .date(date)

        case "calendar":
            let components = NotificationTrigger.CalendarComponents(
                hour: dict["hour"]?.intValue,
                minute: dict["minute"]?.intValue,
                second: dict["second"]?.intValue,
                weekday: dict["weekday"]?.intValue,
                day: dict["day"]?.intValue,
                month: dict["month"]?.intValue,
                year: dict["year"]?.intValue
            )
            let repeats = dict["repeats"]?.boolValue ?? false
            return .calendar(components: components, repeats: repeats)

        default:
            throw BridgeError.invalidPayload("Unknown trigger type: \(type)")
        }
    }

    /// Validates a schedule request.
    private func validateScheduleRequest(_ request: ScheduleNotificationRequest) throws {
        if request.id.isEmpty {
            throw BridgeError.invalidPayload("Notification ID cannot be empty")
        }
        if request.title.isEmpty {
            throw BridgeError.invalidPayload("Notification title cannot be empty")
        }

        // Validate trigger-specific constraints
        switch request.trigger {
        case let .timeInterval(seconds, repeats):
            if seconds <= 0 {
                throw BridgeError.invalidPayload("Time interval must be positive")
            }
            if repeats, seconds < 60 {
                throw BridgeError.invalidPayload("Repeating time interval must be at least 60 seconds")
            }

        case let .date(date):
            if date <= Date() {
                throw BridgeError.invalidPayload("Notification date must be in the future")
            }

        case let .calendar(components, _):
            // Validate calendar component ranges
            if let hour = components.hour, hour < 0 || hour > 23 {
                throw BridgeError.invalidPayload("Hour must be between 0 and 23")
            }
            if let minute = components.minute, minute < 0 || minute > 59 {
                throw BridgeError.invalidPayload("Minute must be between 0 and 59")
            }
            if let second = components.second, second < 0 || second > 59 {
                throw BridgeError.invalidPayload("Second must be between 0 and 59")
            }
            if let weekday = components.weekday, weekday < 1 || weekday > 7 {
                throw BridgeError.invalidPayload("Weekday must be between 1 (Sunday) and 7 (Saturday)")
            }
            if let day = components.day, day < 1 || day > 31 {
                throw BridgeError.invalidPayload("Day must be between 1 and 31")
            }
            if let month = components.month, month < 1 || month > 12 {
                throw BridgeError.invalidPayload("Month must be between 1 and 12")
            }
        }
    }

    /// Creates a UNNotificationTrigger from a NotificationTrigger.
    private func createTrigger(from trigger: NotificationTrigger) throws -> UNNotificationTrigger {
        switch trigger {
        case let .timeInterval(seconds, repeats):
            return UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)

        case let .date(date):
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case let .calendar(components, repeats):
            var dateComponents = DateComponents()
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute
            dateComponents.second = components.second
            dateComponents.weekday = components.weekday
            dateComponents.day = components.day
            dateComponents.month = components.month
            dateComponents.year = components.year
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        }
    }

    // MARK: - Cancel

    /// Handles the `cancel` action to cancel a scheduled notification.
    ///
    /// - Parameter payload: Dictionary containing the notification ID.
    /// - Returns: Success indicator.
    /// - Throws: `BridgeError.invalidPayload` if ID is missing.
    private func handleCancel(payload: AnyCodable?) throws -> AnyCodable {
        guard let id = payload?["id"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing 'id' field")
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])

        return AnyCodable(["success": AnyCodable(true)])
    }

    // MARK: - Cancel All

    /// Handles the `cancelAll` action to cancel all scheduled notifications.
    ///
    /// - Returns: Success indicator.
    private func handleCancelAll() -> AnyCodable {
        notificationCenter.removeAllPendingNotificationRequests()
        return AnyCodable(["success": AnyCodable(true)])
    }

    // MARK: - Get Pending

    /// Handles the `getPending` action to retrieve all pending notifications.
    ///
    /// - Returns: Array of pending notification info.
    private func handleGetPending() async throws -> AnyCodable {
        let requests = await notificationCenter.pendingNotificationRequests()

        let notifications = requests.map { request -> [String: AnyCodable] in
            var info: [String: AnyCodable] = [
                "id": AnyCodable(request.identifier),
                "title": AnyCodable(request.content.title),
            ]

            if !request.content.body.isEmpty {
                info["body"] = AnyCodable(request.content.body)
            }
            if !request.content.subtitle.isEmpty {
                info["subtitle"] = AnyCodable(request.content.subtitle)
            }

            // Determine if repeating
            var repeats = false
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                repeats = trigger.repeats
                if let nextDate = trigger.nextTriggerDate() {
                    info["nextTriggerDate"] = AnyCodable(ISO8601DateFormatter().string(from: nextDate))
                }
            } else if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                repeats = trigger.repeats
                if let nextDate = trigger.nextTriggerDate() {
                    info["nextTriggerDate"] = AnyCodable(ISO8601DateFormatter().string(from: nextDate))
                }
            }
            info["repeats"] = AnyCodable(repeats)

            return info
        }

        return AnyCodable(["notifications": AnyCodable(notifications.map { AnyCodable($0) })])
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

    /// Adds a notification request.
    func add(_ request: UNNotificationRequest) async throws

    /// Removes pending notifications with the specified identifiers.
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])

    /// Removes all pending notification requests.
    func removeAllPendingNotificationRequests()

    /// Returns all pending notification requests.
    func pendingNotificationRequests() async -> [UNNotificationRequest]
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

    public func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func removeAllPendingNotificationRequests() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    public func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
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
