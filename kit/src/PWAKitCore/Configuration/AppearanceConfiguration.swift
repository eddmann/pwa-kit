import Foundation

// MARK: - DisplayMode

/// Display mode for the WebView content.
public enum DisplayMode: String, Codable, Sendable {
    /// Hides browser UI, app appears native.
    case standalone

    /// Hides status bar, maximum screen space.
    case fullscreen
}

// MARK: - StatusBarStyle

/// Status bar appearance style.
public enum StatusBarStyle: String, Codable, Sendable {
    /// Adapts to web content background color automatically.
    case adaptive

    /// Forces light appearance (dark status bar text).
    case light

    /// Forces dark appearance (light status bar text).
    case dark
}

// MARK: - OrientationLock

/// Orientation lock for the application.
public enum OrientationLock: String, Codable, Sendable {
    /// Allow all orientations.
    case any

    /// Lock to portrait orientation.
    case portrait

    /// Lock to landscape orientation.
    case landscape
}

// MARK: - AppearanceConfiguration

/// Configuration for UI behavior and styling.
///
/// Controls the visual appearance and interaction behavior of the WebView.
public struct AppearanceConfiguration: Codable, Sendable, Equatable {
    /// How the app displays content.
    public let displayMode: DisplayMode

    /// Enable pull-to-refresh gesture.
    public let pullToRefresh: Bool

    /// Status bar appearance.
    public let statusBarStyle: StatusBarStyle

    /// Orientation lock for the application.
    public let orientationLock: OrientationLock

    /// Background color for the loading screen (hex format).
    ///
    /// Use standard CSS hex color format: `#RRGGBB` or `#RGB`.
    /// If not specified, the system background color is used.
    ///
    /// Example: `"#f2f2f7"` for iOS light gray, `"#000000"` for black.
    public let backgroundColor: String?

    /// Theme/accent color for progress indicators (hex format).
    ///
    /// Use standard CSS hex color format: `#RRGGBB` or `#RGB`.
    /// If not specified, the system accent color is used.
    ///
    /// Example: `"#007AFF"` for iOS blue.
    public let themeColor: String?

    /// Creates a new appearance configuration.
    ///
    /// - Parameters:
    ///   - displayMode: Display mode for content. Defaults to `.standalone`.
    ///   - pullToRefresh: Enable pull-to-refresh. Defaults to `false`.
    ///   - statusBarStyle: Status bar style. Defaults to `.adaptive`.
    ///   - orientationLock: Orientation lock. Defaults to `.any`.
    ///   - backgroundColor: Background color hex string. Defaults to `nil` (system color).
    ///   - themeColor: Theme/accent color hex string. Defaults to `nil` (system color).
    public init(
        displayMode: DisplayMode = .standalone,
        pullToRefresh: Bool = false,
        statusBarStyle: StatusBarStyle = .adaptive,
        orientationLock: OrientationLock = .any,
        backgroundColor: String? = nil,
        themeColor: String? = nil
    ) {
        self.displayMode = displayMode
        self.pullToRefresh = pullToRefresh
        self.statusBarStyle = statusBarStyle
        self.orientationLock = orientationLock
        self.backgroundColor = backgroundColor
        self.themeColor = themeColor
    }

    /// Default appearance configuration.
    public static let `default` = AppearanceConfiguration()

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case pullToRefresh
        case statusBarStyle
        case orientationLock
        case backgroundColor
        case themeColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .standalone
        self.pullToRefresh = try container.decodeIfPresent(Bool.self, forKey: .pullToRefresh) ?? false
        self.statusBarStyle = try container.decodeIfPresent(StatusBarStyle.self, forKey: .statusBarStyle) ?? .adaptive
        self.orientationLock = try container.decodeIfPresent(OrientationLock.self, forKey: .orientationLock) ?? .any
        self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        self.themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor)
    }
}
