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

// MARK: - NotificationTrigger

/// Trigger configuration for local notifications.
///
/// Defines when a local notification should be delivered.
/// Supports time intervals, specific dates, and calendar-based triggers.
///
/// ## Example
///
/// Time interval trigger:
/// ```json
/// { "type": "timeInterval", "seconds": 60, "repeats": false }
/// ```
///
/// Date trigger:
/// ```json
/// { "type": "date", "date": "2024-01-15T14:00:00Z" }
/// ```
///
/// Calendar trigger:
/// ```json
/// { "type": "calendar", "hour": 9, "minute": 0, "repeats": true }
/// ```
public enum NotificationTrigger: Codable, Sendable, Equatable {
    /// Trigger after a time interval.
    ///
    /// - Parameters:
    ///   - seconds: Number of seconds until the notification fires.
    ///   - repeats: Whether to repeat. If true, minimum interval is 60 seconds.
    case timeInterval(seconds: Double, repeats: Bool)

    /// Trigger at a specific date.
    ///
    /// - Parameter date: The date when the notification should fire.
    case date(Date)

    /// Trigger based on calendar components.
    ///
    /// - Parameters:
    ///   - components: Calendar components defining when to trigger.
    ///   - repeats: Whether to repeat at this time.
    case calendar(components: CalendarComponents, repeats: Bool)

    /// Calendar components for scheduling.
    public struct CalendarComponents: Codable, Sendable, Equatable {
        public let hour: Int?
        public let minute: Int?
        public let second: Int?
        public let weekday: Int?
        public let day: Int?
        public let month: Int?
        public let year: Int?

        public init(
            hour: Int? = nil,
            minute: Int? = nil,
            second: Int? = nil,
            weekday: Int? = nil,
            day: Int? = nil,
            month: Int? = nil,
            year: Int? = nil
        ) {
            self.hour = hour
            self.minute = minute
            self.second = second
            self.weekday = weekday
            self.day = day
            self.month = month
            self.year = year
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case seconds
        case repeats
        case date
        case hour
        case minute
        case second
        case weekday
        case day
        case month
        case year
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "timeInterval":
            let seconds = try container.decode(Double.self, forKey: .seconds)
            let repeats = try container.decodeIfPresent(Bool.self, forKey: .repeats) ?? false
            self = .timeInterval(seconds: seconds, repeats: repeats)

        case "date":
            let dateValue = try container.decode(String.self, forKey: .date)
            guard let date = ISO8601DateFormatter().date(from: dateValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .date,
                    in: container,
                    debugDescription: "Invalid ISO8601 date format"
                )
            }
            self = .date(date)

        case "calendar":
            let components = try CalendarComponents(
                hour: container.decodeIfPresent(Int.self, forKey: .hour),
                minute: container.decodeIfPresent(Int.self, forKey: .minute),
                second: container.decodeIfPresent(Int.self, forKey: .second),
                weekday: container.decodeIfPresent(Int.self, forKey: .weekday),
                day: container.decodeIfPresent(Int.self, forKey: .day),
                month: container.decodeIfPresent(Int.self, forKey: .month),
                year: container.decodeIfPresent(Int.self, forKey: .year)
            )
            let repeats = try container.decodeIfPresent(Bool.self, forKey: .repeats) ?? false
            self = .calendar(components: components, repeats: repeats)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown trigger type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .timeInterval(seconds, repeats):
            try container.encode("timeInterval", forKey: .type)
            try container.encode(seconds, forKey: .seconds)
            try container.encode(repeats, forKey: .repeats)

        case let .date(date):
            try container.encode("date", forKey: .type)
            try container.encode(ISO8601DateFormatter().string(from: date), forKey: .date)

        case let .calendar(components, repeats):
            try container.encode("calendar", forKey: .type)
            try container.encodeIfPresent(components.hour, forKey: .hour)
            try container.encodeIfPresent(components.minute, forKey: .minute)
            try container.encodeIfPresent(components.second, forKey: .second)
            try container.encodeIfPresent(components.weekday, forKey: .weekday)
            try container.encodeIfPresent(components.day, forKey: .day)
            try container.encodeIfPresent(components.month, forKey: .month)
            try container.encodeIfPresent(components.year, forKey: .year)
            try container.encode(repeats, forKey: .repeats)
        }
    }
}

// MARK: - ScheduleNotificationRequest

/// Request payload for scheduling a local notification.
///
/// ## Example
///
/// ```json
/// {
///   "id": "reminder-123",
///   "title": "Time to check in",
///   "body": "Don't forget your daily check-in!",
///   "badge": 1,
///   "sound": "default",
///   "trigger": { "type": "timeInterval", "seconds": 3600 }
/// }
/// ```
public struct ScheduleNotificationRequest: Codable, Sendable, Equatable {
    /// Unique identifier for the notification.
    public let id: String

    /// The notification title.
    public let title: String

    /// The notification body text.
    public let body: String?

    /// The notification subtitle.
    public let subtitle: String?

    /// The badge count to display.
    public let badge: Int?

    /// The sound to play. Use "default" for the default sound.
    public let sound: String?

    /// Custom data to include with the notification.
    public let data: [String: AnyCodable]?

    /// When to trigger the notification.
    public let trigger: NotificationTrigger

    /// Creates a schedule notification request.
    public init(
        id: String,
        title: String,
        body: String? = nil,
        subtitle: String? = nil,
        badge: Int? = nil,
        sound: String? = nil,
        data: [String: AnyCodable]? = nil,
        trigger: NotificationTrigger
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.badge = badge
        self.sound = sound
        self.data = data
        self.trigger = trigger
    }
}

// MARK: - CancelNotificationRequest

/// Request payload for canceling a scheduled notification.
///
/// ## Example
///
/// ```json
/// { "id": "reminder-123" }
/// ```
public struct CancelNotificationRequest: Codable, Sendable, Equatable {
    /// The identifier of the notification to cancel.
    public let id: String

    /// Creates a cancel notification request.
    public init(id: String) {
        self.id = id
    }
}

// MARK: - PendingNotificationInfo

/// Information about a pending scheduled notification.
///
/// Returned when listing pending notifications.
public struct PendingNotificationInfo: Codable, Sendable, Equatable {
    /// The notification identifier.
    public let id: String

    /// The notification title.
    public let title: String

    /// The notification body.
    public let body: String?

    /// The notification subtitle.
    public let subtitle: String?

    /// Whether the notification repeats.
    public let repeats: Bool

    /// The next trigger date, if determinable.
    public let nextTriggerDate: String?

    /// Creates pending notification info.
    public init(
        id: String,
        title: String,
        body: String? = nil,
        subtitle: String? = nil,
        repeats: Bool = false,
        nextTriggerDate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.repeats = repeats
        self.nextTriggerDate = nextTriggerDate
    }
}
