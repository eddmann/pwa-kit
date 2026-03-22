import Foundation

/// Configuration for core application metadata.
///
/// Contains the essential app information needed for PWAKit to function:
/// - Display name
/// - Bundle identifier
/// - Start URL for the WebView
/// - App Group identifier (for widgets and background refresh)
public struct AppConfiguration: Codable, Sendable, Equatable {
    /// Display name of the application.
    public let name: String

    /// iOS bundle identifier (e.g., `com.example.app`).
    public let bundleId: String

    /// The initial URL to load in the WebView. Must be HTTPS.
    public let startUrl: String

    /// App Group identifier for sharing data with Widget Extensions.
    ///
    /// Required for widgets, Live Activities, and background refresh.
    /// Must match the App Group configured in both the main app and
    /// widget extension entitlements (e.g., `"group.com.example.mypwa"`).
    public let appGroupId: String?

    /// Creates a new app configuration.
    ///
    /// - Parameters:
    ///   - name: Display name of the application.
    ///   - bundleId: iOS bundle identifier.
    ///   - startUrl: Initial URL to load (must be HTTPS).
    ///   - appGroupId: Optional App Group identifier for widget/extension data sharing.
    public init(
        name: String,
        bundleId: String,
        startUrl: String,
        appGroupId: String? = nil
    ) {
        self.name = name
        self.bundleId = bundleId
        self.startUrl = startUrl
        self.appGroupId = appGroupId
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case name
        case bundleId
        case startUrl
        case appGroupId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleId = try container.decode(String.self, forKey: .bundleId)
        self.startUrl = try container.decode(String.self, forKey: .startUrl)
        self.appGroupId = try container.decodeIfPresent(String.self, forKey: .appGroupId)
    }
}
