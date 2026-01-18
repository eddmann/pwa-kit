import Foundation

// MARK: - NotificationPermissionState

/// The permission state for push notifications.
///
/// This enum maps to the possible authorization statuses from
/// `UNUserNotificationCenter` and is used to communicate the
/// current notification permission state to JavaScript.
///
/// ## Example
///
/// ```swift
/// let state = NotificationPermissionState.granted
/// let encoded = try JSONEncoder().encode(state)
/// // "granted"
/// ```
public enum NotificationPermissionState: String, Codable, Sendable, Equatable, CaseIterable {
    /// Permission has not been requested yet.
    case notDetermined = "not_determined"

    /// The user has denied notification permission.
    case denied

    /// The user has granted notification permission.
    case granted

    /// Notifications are not available on this device.
    /// This can occur when notifications are disabled at the system level.
    case unavailable

    /// Permission status is unknown or could not be determined.
    case unknown
}

// MARK: - NotificationSubscription

/// The result of a notification subscription request.
///
/// When the user subscribes to push notifications, this type contains
/// the outcome including the device token (on success) or error information.
///
/// ## Example
///
/// Successful subscription:
/// ```json
/// {
///   "success": true,
///   "token": "abc123def456...",
///   "permissionState": "granted"
/// }
/// ```
///
/// Failed subscription:
/// ```json
/// {
///   "success": false,
///   "error": "User denied notification permission",
///   "permissionState": "denied"
/// }
/// ```
public struct NotificationSubscription: Codable, Sendable, Equatable {
    /// Whether the subscription was successful.
    public let success: Bool

    /// The APNs device token (hex-encoded string), present on success.
    public let token: String?

    /// The current permission state after the subscription attempt.
    public let permissionState: NotificationPermissionState

    /// Error message if the subscription failed.
    public let error: String?

    /// Creates a successful subscription result.
    ///
    /// - Parameters:
    ///   - token: The APNs device token as a hex-encoded string.
    ///   - permissionState: The current permission state (typically `.granted`).
    public init(token: String, permissionState: NotificationPermissionState = .granted) {
        self.success = true
        self.token = token
        self.permissionState = permissionState
        self.error = nil
    }

    /// Creates a failed subscription result.
    ///
    /// - Parameters:
    ///   - error: A description of why the subscription failed.
    ///   - permissionState: The current permission state.
    public init(error: String, permissionState: NotificationPermissionState) {
        self.success = false
        self.token = nil
        self.permissionState = permissionState
        self.error = error
    }

    /// Creates a subscription result with all fields.
    ///
    /// This initializer is primarily used for decoding.
    ///
    /// - Parameters:
    ///   - success: Whether the subscription was successful.
    ///   - token: The APNs device token, if available.
    ///   - permissionState: The current permission state.
    ///   - error: Error message, if any.
    public init(
        success: Bool,
        token: String?,
        permissionState: NotificationPermissionState,
        error: String?
    ) {
        self.success = success
        self.token = token
        self.permissionState = permissionState
        self.error = error
    }
}

// MARK: - NotificationPayload

/// Payload for push notification events sent to JavaScript.
///
/// When a push notification is received or tapped, this type represents
/// the notification data dispatched to the web application.
///
/// ## Event Types
///
/// - `received`: Notification was received while app is in foreground
/// - `tapped`: User tapped on a notification to open the app
///
/// ## Example
///
/// ```json
/// {
///   "type": "tapped",
///   "title": "New Message",
///   "body": "You have a new message from John",
///   "userInfo": {
///     "messageId": "123",
///     "senderId": "456"
///   },
///   "badge": 1,
///   "timestamp": 1704067200.0
/// }
/// ```
public struct NotificationPayload: Codable, Sendable, Equatable {
    /// The type of notification event.
    public enum EventType: String, Codable, Sendable, Equatable {
        /// Notification received while app is in foreground.
        case received

        /// User tapped on the notification.
        case tapped
    }

    /// The type of notification event.
    public let type: EventType

    /// The notification title, if present.
    public let title: String?

    /// The notification body text, if present.
    public let body: String?

    /// The notification subtitle, if present.
    public let subtitle: String?

    /// Custom data from the notification payload.
    ///
    /// This dictionary contains the `userInfo` from the push notification,
    /// allowing the server to send arbitrary data that the web app can use.
    public let userInfo: [String: AnyCodable]?

    /// The badge count to display on the app icon, if specified.
    public let badge: Int?

    /// The sound to play, if specified.
    public let sound: String?

    /// The timestamp when the notification was received.
    public let timestamp: Double

    /// Creates a new notification payload.
    ///
    /// - Parameters:
    ///   - type: The type of notification event.
    ///   - title: The notification title.
    ///   - body: The notification body text.
    ///   - subtitle: The notification subtitle.
    ///   - userInfo: Custom data from the notification.
    ///   - badge: The badge count to display.
    ///   - sound: The sound to play.
    ///   - timestamp: The timestamp when received (defaults to current time).
    public init(
        type: EventType,
        title: String? = nil,
        body: String? = nil,
        subtitle: String? = nil,
        userInfo: [String: AnyCodable]? = nil,
        badge: Int? = nil,
        sound: String? = nil,
        timestamp: Double = Date().timeIntervalSince1970
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.userInfo = userInfo
        self.badge = badge
        self.sound = sound
        self.timestamp = timestamp
    }
}

// MARK: - SetBadgeRequest

/// Request payload for setting the app badge count.
///
/// ## Example
///
/// ```json
/// {
///   "count": 5
/// }
/// ```
public struct SetBadgeRequest: Codable, Sendable, Equatable {
    /// The badge count to display on the app icon.
    /// Set to 0 to clear the badge.
    public let count: Int

    /// Creates a set badge request.
    ///
    /// - Parameter count: The badge count to display.
    public init(count: Int) {
        self.count = count
    }
}
