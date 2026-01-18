import Foundation

/// Configuration for enabling or disabling bridge modules.
///
/// Each property corresponds to a bridge module that can be conditionally
/// enabled or disabled. Disabled modules return "module not available"
/// errors from the bridge.
public struct FeaturesConfiguration: Codable, Sendable, Equatable {
    /// Enable push notification support (APNs).
    public let notifications: Bool

    /// Enable haptic feedback (UIImpactFeedbackGenerator).
    public let haptics: Bool

    /// Enable Face ID / Touch ID authentication.
    public let biometrics: Bool

    /// Enable Keychain-based secure storage.
    public let secureStorage: Bool

    /// Enable HealthKit data access.
    ///
    /// Disabled by default as it requires App Store review.
    public let healthkit: Bool

    /// Enable in-app purchases (StoreKit 2).
    ///
    /// Disabled by default as it requires App Store review.
    public let iap: Bool

    /// Enable native share sheet.
    public let share: Bool

    /// Enable AirPrint support.
    public let print: Bool

    /// Enable system clipboard access.
    public let clipboard: Bool

    /// Enable camera permission management.
    public let cameraPermission: Bool

    /// Enable location permission management.
    public let locationPermission: Bool

    /// Creates a new features configuration with all values specified.
    ///
    /// - Parameters:
    ///   - notifications: Enable push notifications. Defaults to `true`.
    ///   - haptics: Enable haptic feedback. Defaults to `true`.
    ///   - biometrics: Enable biometric authentication. Defaults to `true`.
    ///   - secureStorage: Enable secure storage. Defaults to `true`.
    ///   - healthkit: Enable HealthKit. Defaults to `false`.
    ///   - iap: Enable in-app purchases. Defaults to `false`.
    ///   - share: Enable share sheet. Defaults to `true`.
    ///   - print: Enable printing. Defaults to `true`.
    ///   - clipboard: Enable clipboard access. Defaults to `true`.
    ///   - cameraPermission: Enable camera permission. Defaults to `true`.
    ///   - locationPermission: Enable location permission. Defaults to `true`.
    public init(
        notifications: Bool = true,
        haptics: Bool = true,
        biometrics: Bool = true,
        secureStorage: Bool = true,
        healthkit: Bool = false,
        iap: Bool = false,
        share: Bool = true,
        print: Bool = true,
        clipboard: Bool = true,
        cameraPermission: Bool = true,
        locationPermission: Bool = true
    ) {
        self.notifications = notifications
        self.haptics = haptics
        self.biometrics = biometrics
        self.secureStorage = secureStorage
        self.healthkit = healthkit
        self.iap = iap
        self.share = share
        self.print = print
        self.clipboard = clipboard
        self.cameraPermission = cameraPermission
        self.locationPermission = locationPermission
    }

    /// Default configuration with standard feature flags.
    public static let `default` = FeaturesConfiguration()

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case notifications
        case haptics
        case biometrics
        case secureStorage
        case healthkit
        case iap
        case share
        case print
        case clipboard
        case cameraPermission
        case locationPermission
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.notifications = try container.decodeIfPresent(Bool.self, forKey: .notifications) ?? true
        self.haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        self.biometrics = try container.decodeIfPresent(Bool.self, forKey: .biometrics) ?? true
        self.secureStorage = try container.decodeIfPresent(Bool.self, forKey: .secureStorage) ?? true
        self.healthkit = try container.decodeIfPresent(Bool.self, forKey: .healthkit) ?? false
        self.iap = try container.decodeIfPresent(Bool.self, forKey: .iap) ?? false
        self.share = try container.decodeIfPresent(Bool.self, forKey: .share) ?? true
        self.print = try container.decodeIfPresent(Bool.self, forKey: .print) ?? true
        self.clipboard = try container.decodeIfPresent(Bool.self, forKey: .clipboard) ?? true
        self.cameraPermission = try container.decodeIfPresent(Bool.self, forKey: .cameraPermission) ?? true
        self.locationPermission = try container.decodeIfPresent(Bool.self, forKey: .locationPermission) ?? true
    }
}
