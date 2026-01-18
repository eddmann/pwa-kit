import Foundation

/// Root configuration for PWAKit.
///
/// This is the top-level configuration type that encompasses all settings
/// for the PWA wrapper application. It is loaded from a JSON file
/// (`pwa-config.json`) at app launch.
///
/// ## Example JSON
///
/// ```json
/// {
///   "version": 1,
///   "app": {
///     "name": "My PWA",
///     "bundleId": "com.example.mypwa",
///     "startUrl": "https://app.example.com/"
///   },
///   "origins": {
///     "allowed": ["app.example.com"],
///     "auth": ["accounts.google.com"],
///     "external": []
///   },
///   "features": {
///     "notifications": true,
///     "haptics": true
///   },
///   "appearance": {
///     "displayMode": "standalone",
///     "pullToRefresh": true
///   },
///   "notifications": {
///     "provider": "apns"
///   }
/// }
/// ```
public struct PWAConfiguration: Codable, Sendable, Equatable {
    /// Schema version number for migration support.
    public let version: Int

    /// Core application metadata.
    public let app: AppConfiguration

    /// URL handling rules.
    public let origins: OriginsConfiguration

    /// Feature flags for bridge modules.
    public let features: FeaturesConfiguration

    /// UI customization settings.
    public let appearance: AppearanceConfiguration

    /// Push notification settings.
    public let notifications: NotificationsConfiguration

    /// Creates a new PWA configuration.
    ///
    /// - Parameters:
    ///   - version: Schema version number.
    ///   - app: App metadata configuration.
    ///   - origins: URL handling configuration.
    ///   - features: Feature flags configuration.
    ///   - appearance: Appearance configuration.
    ///   - notifications: Notifications configuration.
    public init(
        version: Int,
        app: AppConfiguration,
        origins: OriginsConfiguration,
        features: FeaturesConfiguration = .default,
        appearance: AppearanceConfiguration = .default,
        notifications: NotificationsConfiguration = .default
    ) {
        self.version = version
        self.app = app
        self.origins = origins
        self.features = features
        self.appearance = appearance
        self.notifications = notifications
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case version
        case app
        case origins
        case features
        case appearance
        case notifications
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Int.self, forKey: .version)
        self.app = try container.decode(AppConfiguration.self, forKey: .app)
        self.origins = try container.decode(OriginsConfiguration.self, forKey: .origins)
        self.features = try container.decodeIfPresent(FeaturesConfiguration.self, forKey: .features) ?? .default
        self.appearance = try container.decodeIfPresent(AppearanceConfiguration.self, forKey: .appearance) ?? .default
        self.notifications = try container.decodeIfPresent(
            NotificationsConfiguration.self,
            forKey: .notifications
        ) ?? .default
    }
}
