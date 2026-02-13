import Foundation

// MARK: - FeatureFlag

/// Protocol for types that represent a feature flag.
///
/// Modules can conform to this protocol to provide a standardized way
/// of checking whether they are enabled in the current configuration.
///
/// ## Example
///
/// ```swift
/// struct HapticsModule: PWAModule {
///     static let featureFlag = ConfigurationStore.Feature.haptics
///
///     func handle(action: String, payload: Any?) async throws -> Any? {
///         guard await Self.featureFlag.isEnabled() else {
///             throw BridgeError.moduleDisabled(name: Self.moduleName)
///         }
///         // ... handle action
///     }
/// }
/// ```
public protocol FeatureFlag: Sendable {
    /// The unique identifier for this feature.
    var identifier: String { get }

    /// The default value if configuration is not loaded.
    var defaultValue: Bool { get }

    /// Checks if this feature is enabled in the given features configuration.
    ///
    /// - Parameter features: The features configuration to check against.
    /// - Returns: `true` if the feature is enabled.
    func isEnabled(in features: FeaturesConfiguration) -> Bool
}

// MARK: - Default Implementation

extension FeatureFlag {
    /// Checks if this feature is enabled using the shared configuration store.
    ///
    /// This method provides a convenient way for modules to check their
    /// enabled state without needing direct access to the configuration.
    ///
    /// - Returns: `true` if the feature is enabled, or `defaultValue` if configuration is not loaded.
    public func isEnabled() async -> Bool {
        guard let config = try? await ConfigurationStore.shared.configuration else {
            return defaultValue
        }
        return isEnabled(in: config.features)
    }

    /// Synchronously checks if this feature is enabled.
    ///
    /// Uses the cached configuration from the store. If no configuration
    /// is cached, returns the default value.
    ///
    /// - Parameter store: The configuration store to check. Defaults to `.shared`.
    /// - Returns: `true` if the feature is enabled.
    public func isEnabledSync(in store: ConfigurationStore = .shared) async -> Bool {
        guard let feature = self as? ConfigurationStore.Feature else {
            return defaultValue
        }
        return await store.isFeatureEnabled(feature)
    }
}

// MARK: - ConfigurationStore.Feature + FeatureFlag

extension ConfigurationStore.Feature: FeatureFlag {
    /// The unique identifier for this feature.
    public var identifier: String {
        rawValue
    }
}

// MARK: - FeatureFlagChecker

/// Utility for checking feature flags at module registration time.
///
/// This struct provides a synchronous way to check if features are enabled
/// when registering modules, avoiding the need for async context.
public struct FeatureFlagChecker: Sendable {
    /// The features configuration to check against.
    public let features: FeaturesConfiguration

    /// Creates a new feature flag checker.
    ///
    /// - Parameter features: The features configuration to use.
    public init(features: FeaturesConfiguration) {
        self.features = features
    }

    /// Creates a checker using the default features configuration.
    public static let `default` = FeatureFlagChecker(features: .default)

    /// Checks if a feature is enabled.
    ///
    /// - Parameter flag: The feature flag to check.
    /// - Returns: `true` if the feature is enabled.
    public func isEnabled(_ flag: some FeatureFlag) -> Bool {
        flag.isEnabled(in: features)
    }

    /// Checks if the notifications feature is enabled.
    public var notifications: Bool {
        features.notifications
    }

    /// Checks if the haptics feature is enabled.
    public var haptics: Bool {
        features.haptics
    }

    /// Checks if the biometrics feature is enabled.
    public var biometrics: Bool {
        features.biometrics
    }

    /// Checks if the secure storage feature is enabled.
    public var secureStorage: Bool {
        features.secureStorage
    }

    /// Checks if the HealthKit feature is enabled.
    public var healthkit: Bool {
        features.healthkit
    }

    /// Checks if the in-app purchases feature is enabled.
    public var iap: Bool {
        features.iap
    }

    /// Checks if the share feature is enabled.
    public var share: Bool {
        features.share
    }

    /// Checks if the print feature is enabled.
    public var print: Bool {
        features.print
    }

    /// Checks if the clipboard feature is enabled.
    public var clipboard: Bool {
        features.clipboard
    }

    /// Checks if the camera permission feature is enabled.
    public var cameraPermission: Bool {
        features.cameraPermission
    }

    /// Checks if the microphone permission feature is enabled.
    public var microphonePermission: Bool {
        features.microphonePermission
    }

    /// Checks if the location permission feature is enabled.
    public var locationPermission: Bool {
        features.locationPermission
    }
}

// MARK: - Module Feature Flag Extension

/// Extension providing feature flag utilities for modules.
extension FeaturesConfiguration {
    /// Creates a feature flag checker for this configuration.
    public var checker: FeatureFlagChecker {
        FeatureFlagChecker(features: self)
    }

    /// Checks if a specific feature flag is enabled.
    ///
    /// - Parameter flag: The feature flag to check.
    /// - Returns: `true` if the feature is enabled.
    public func isEnabled(_ flag: some FeatureFlag) -> Bool {
        flag.isEnabled(in: self)
    }
}
