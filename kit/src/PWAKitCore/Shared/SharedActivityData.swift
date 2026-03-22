import Foundation

// MARK: - SharedActivityData

/// Shared data model for Live Activities (Dynamic Island) content.
///
/// This struct represents the content state of a Live Activity. It uses
/// a flexible key-value approach so that PWAs can push arbitrary data
/// to the Dynamic Island without requiring native code changes.
///
/// The data is encoded to JSON and shared via App Groups between the
/// main app and the Widget Extension.
///
/// ## Example JSON from JavaScript
///
/// ```json
/// {
///   "title": "Order #1234",
///   "subtitle": "Preparing your food",
///   "progress": 0.45,
///   "icon": "fork.knife",
///   "tint": "#FF6B35",
///   "fields": {
///     "eta": "12:30 PM",
///     "status": "Cooking"
///   }
/// }
/// ```
public struct SharedActivityData: Codable, Sendable, Equatable {
    /// Primary title displayed in the Dynamic Island expanded view.
    public let title: String

    /// Subtitle displayed below the title.
    public let subtitle: String?

    /// Progress value between 0.0 and 1.0 for a progress indicator.
    public let progress: Double?

    /// SF Symbol name for the activity icon.
    public let icon: String?

    /// Hex color string for the accent/tint color.
    public let tint: String?

    /// Arbitrary key-value pairs for custom fields.
    public let fields: [String: String]?

    /// Creates a new shared activity data instance.
    public init(
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        icon: String? = nil,
        tint: String? = nil,
        fields: [String: String]? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.icon = icon
        self.tint = tint
        self.fields = fields
    }

    /// Parses SharedActivityData from an AnyCodable bridge payload.
    ///
    /// - Parameter payload: The bridge message payload.
    /// - Returns: A parsed SharedActivityData, or nil if the title is missing.
    public static func from(payload: AnyCodable?) -> SharedActivityData? {
        guard let title = payload?["title"]?.stringValue else {
            return nil
        }

        var fields: [String: String]?
        if let fieldsDict = payload?["fields"]?.dictionaryValue {
            fields = [:]
            for (key, value) in fieldsDict {
                if let str = value.stringValue {
                    fields?[key] = str
                }
            }
        }

        return SharedActivityData(
            title: title,
            subtitle: payload?["subtitle"]?.stringValue,
            progress: payload?["progress"]?.doubleValue,
            icon: payload?["icon"]?.stringValue,
            tint: payload?["tint"]?.stringValue,
            fields: fields
        )
    }
}

// MARK: - SharedWidgetData

/// Shared data model for Lock Screen and Home Screen widget content.
///
/// This struct is stored in the App Group shared container so the
/// Widget Extension can read it and render the widget UI.
///
/// ## Example JSON from JavaScript
///
/// ```json
/// {
///   "kind": "status",
///   "title": "Steps Today",
///   "value": "8,421",
///   "subtitle": "Goal: 10,000",
///   "icon": "figure.walk",
///   "tint": "#34C759",
///   "url": "https://app.example.com/steps"
/// }
/// ```
public struct SharedWidgetData: Codable, Sendable, Equatable {
    /// Widget kind identifier, used to match against registered widget types.
    public let kind: String

    /// Primary title for the widget.
    public let title: String

    /// Primary display value (large text in the widget).
    public let value: String?

    /// Subtitle displayed below the value.
    public let subtitle: String?

    /// SF Symbol name for the widget icon.
    public let icon: String?

    /// Hex color string for the accent color.
    public let tint: String?

    /// Deep link URL opened when the widget is tapped.
    public let url: String?

    /// Timestamp when this data was last updated.
    public let updatedAt: Date

    /// Creates a new shared widget data instance.
    public init(
        kind: String,
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: String? = nil,
        url: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.url = url
        self.updatedAt = updatedAt
    }

    /// Parses SharedWidgetData from an AnyCodable bridge payload.
    ///
    /// - Parameter payload: The bridge message payload.
    /// - Returns: A parsed SharedWidgetData, or nil if required fields are missing.
    public static func from(payload: AnyCodable?) -> SharedWidgetData? {
        guard let kind = payload?["kind"]?.stringValue,
              let title = payload?["title"]?.stringValue else
        {
            return nil
        }

        return SharedWidgetData(
            kind: kind,
            title: title,
            value: payload?["value"]?.stringValue,
            subtitle: payload?["subtitle"]?.stringValue,
            icon: payload?["icon"]?.stringValue,
            tint: payload?["tint"]?.stringValue,
            url: payload?["url"]?.stringValue
        )
    }
}

// MARK: - AppGroupStorage

/// Utilities for reading and writing shared data via App Groups.
///
/// App Groups enable sharing data between the main app and extensions
/// (Widget Extension, etc.) through a shared UserDefaults suite.
public enum AppGroupStorage {
    /// The App Group identifier. Must match the value configured in
    /// both the main app and widget extension entitlements.
    ///
    /// This should be set during app launch via `configure(appGroupId:)`.
    private static var _appGroupId: String?

    /// The shared UserDefaults suite for the App Group.
    public static var sharedDefaults: UserDefaults? {
        guard let appGroupId = _appGroupId else { return nil }
        return UserDefaults(suiteName: appGroupId)
    }

    /// Configures the App Group identifier.
    ///
    /// Call this once during app launch before using any shared storage.
    ///
    /// - Parameter appGroupId: The App Group identifier (e.g., "group.com.example.mypwa").
    public static func configure(appGroupId: String) {
        _appGroupId = appGroupId
    }

    /// Returns the configured App Group identifier.
    public static var appGroupId: String? {
        _appGroupId
    }

    // MARK: - Widget Data

    private static let widgetDataKeyPrefix = "pwakit.widget."

    /// Saves widget data to the shared container.
    ///
    /// - Parameter data: The widget data to save.
    public static func saveWidgetData(_ data: SharedWidgetData) {
        guard let defaults = sharedDefaults else { return }
        let key = widgetDataKeyPrefix + data.kind
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }

    /// Loads widget data from the shared container.
    ///
    /// - Parameter kind: The widget kind identifier.
    /// - Returns: The stored widget data, or nil if not found.
    public static func loadWidgetData(kind: String) -> SharedWidgetData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKeyPrefix + kind) else
        {
            return nil
        }
        return try? JSONDecoder().decode(SharedWidgetData.self, from: data)
    }

    /// Removes widget data from the shared container.
    ///
    /// - Parameter kind: The widget kind identifier.
    public static func removeWidgetData(kind: String) {
        sharedDefaults?.removeObject(forKey: widgetDataKeyPrefix + kind)
    }

    // MARK: - Activity Data

    private static let activityDataKey = "pwakit.liveActivity.current"

    /// Saves live activity data to the shared container.
    ///
    /// - Parameter data: The activity data to save.
    public static func saveActivityData(_ data: SharedActivityData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: activityDataKey)
        }
    }

    /// Loads the current live activity data from the shared container.
    ///
    /// - Returns: The stored activity data, or nil if not found.
    public static func loadActivityData() -> SharedActivityData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: activityDataKey) else
        {
            return nil
        }
        return try? JSONDecoder().decode(SharedActivityData.self, from: data)
    }

    /// Removes live activity data from the shared container.
    public static func removeActivityData() {
        sharedDefaults?.removeObject(forKey: activityDataKey)
    }
}
