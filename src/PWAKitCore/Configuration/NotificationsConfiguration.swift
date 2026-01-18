import Foundation

// MARK: - NotificationProvider

/// Push notification provider type.
public enum NotificationProvider: String, Codable, Sendable {
    /// Apple Push Notification service (native).
    case apns
}

// MARK: - NotificationsConfiguration

/// Configuration for push notification behavior.
///
/// PWAKit uses native APNs exclusively. The device token is provided
/// to your web app via the bridge for server-side registration.
public struct NotificationsConfiguration: Codable, Sendable, Equatable {
    /// Push notification provider.
    public let provider: NotificationProvider

    /// Creates a new notifications configuration.
    ///
    /// - Parameter provider: Push notification provider. Defaults to `.apns`.
    public init(provider: NotificationProvider = .apns) {
        self.provider = provider
    }

    /// Default notifications configuration using APNs.
    public static let `default` = NotificationsConfiguration()

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case provider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.provider = try container.decodeIfPresent(NotificationProvider.self, forKey: .provider) ?? .apns
    }
}
