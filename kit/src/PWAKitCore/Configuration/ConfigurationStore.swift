import Foundation

// MARK: - ConfigurationStore

/// Thread-safe store for runtime configuration access.
///
/// `ConfigurationStore` provides a centralized, thread-safe access point for the app's
/// configuration. It wraps `ConfigurationLoader` with caching and provides convenience
/// methods for common operations like feature flag checks.
///
/// ## Thread Safety
///
/// The store is implemented as an actor, ensuring all access is serialized and safe
/// from data races. For SwiftUI integration, use `ConfigurationStoreObservable`.
///
/// ## Example
///
/// ```swift
/// // Access configuration
/// let config = try await ConfigurationStore.shared.configuration
///
/// // Check feature flags
/// let isEnabled = await ConfigurationStore.shared.isFeatureEnabled(.notifications)
///
/// // Reload configuration at runtime
/// try await ConfigurationStore.shared.reload()
/// ```
public actor ConfigurationStore {
    /// The shared configuration store instance.
    public static let shared = ConfigurationStore()

    /// The current loaded configuration.
    ///
    /// Accessing this property will load the configuration if not already loaded.
    /// - Throws: `ConfigurationError` if loading fails.
    public var configuration: PWAConfiguration {
        get async throws {
            if let cached = cachedConfiguration {
                return cached
            }
            return try await load()
        }
    }

    /// The cached configuration, if loaded.
    private var cachedConfiguration: PWAConfiguration?

    /// The configuration loader instance.
    private let loader: ConfigurationLoader

    /// Observers to notify when configuration changes.
    private var observers: [UUID: @Sendable (PWAConfiguration) -> Void] = [:]

    /// Creates a new configuration store.
    ///
    /// - Parameter loader: The configuration loader to use. Defaults to `.shared`.
    public init(loader: ConfigurationLoader = .shared) {
        self.loader = loader
    }

    // MARK: - Loading

    /// Loads the configuration from the loader.
    ///
    /// This method loads the configuration using the standard priority ordering
    /// and caches the result.
    ///
    /// - Returns: The loaded configuration.
    /// - Throws: `ConfigurationError` if loading fails.
    @discardableResult
    public func load() async throws -> PWAConfiguration {
        let config = try await loader.load()
        cachedConfiguration = config
        notifyObservers(config)
        return config
    }

    /// Reloads the configuration, bypassing the cache.
    ///
    /// Use this method when you need to pick up configuration changes
    /// made at runtime (e.g., from a downloaded update).
    ///
    /// - Returns: The reloaded configuration.
    /// - Throws: `ConfigurationError` if loading fails.
    @discardableResult
    public func reload() async throws -> PWAConfiguration {
        await loader.clearCache()
        let config = try await loader.load(ignoreCache: true)
        cachedConfiguration = config
        notifyObservers(config)
        return config
    }

    /// Clears the cached configuration.
    ///
    /// After calling this method, the next access to `configuration`
    /// will trigger a fresh load.
    public func clearCache() async {
        cachedConfiguration = nil
        await loader.clearCache()
    }

    // MARK: - Feature Flags

    /// Checks if a specific feature is enabled.
    ///
    /// - Parameter feature: The feature to check.
    /// - Returns: `true` if the feature is enabled, `false` otherwise.
    ///           Returns `false` if configuration hasn't been loaded.
    public func isFeatureEnabled(_ feature: Feature) -> Bool {
        guard let config = cachedConfiguration else {
            return feature.defaultValue
        }
        return feature.isEnabled(in: config.features)
    }

    /// Checks if notifications are enabled.
    public var notificationsEnabled: Bool {
        isFeatureEnabled(.notifications)
    }

    /// Checks if haptics are enabled.
    public var hapticsEnabled: Bool {
        isFeatureEnabled(.haptics)
    }

    /// Checks if biometrics are enabled.
    public var biometricsEnabled: Bool {
        isFeatureEnabled(.biometrics)
    }

    /// Checks if secure storage is enabled.
    public var secureStorageEnabled: Bool {
        isFeatureEnabled(.secureStorage)
    }

    /// Checks if HealthKit is enabled.
    public var healthkitEnabled: Bool {
        isFeatureEnabled(.healthkit)
    }

    /// Checks if in-app purchases are enabled.
    public var iapEnabled: Bool {
        isFeatureEnabled(.iap)
    }

    /// Checks if share is enabled.
    public var shareEnabled: Bool {
        isFeatureEnabled(.share)
    }

    /// Checks if print is enabled.
    public var printEnabled: Bool {
        isFeatureEnabled(.print)
    }

    /// Checks if clipboard is enabled.
    public var clipboardEnabled: Bool {
        isFeatureEnabled(.clipboard)
    }

    /// Checks if camera permission is enabled.
    public var cameraPermissionEnabled: Bool {
        isFeatureEnabled(.cameraPermission)
    }

    /// Checks if microphone permission is enabled.
    public var microphonePermissionEnabled: Bool {
        isFeatureEnabled(.microphonePermission)
    }

    /// Checks if location permission is enabled.
    public var locationPermissionEnabled: Bool {
        isFeatureEnabled(.locationPermission)
    }

    // MARK: - Observation

    /// Adds an observer to be notified when configuration changes.
    ///
    /// - Parameter handler: The closure to call when configuration changes.
    /// - Returns: An identifier that can be used to remove the observer.
    @discardableResult
    public func addObserver(_ handler: @escaping @Sendable (PWAConfiguration) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }

    /// Removes an observer.
    ///
    /// - Parameter id: The observer identifier returned from `addObserver(_:)`.
    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    /// Notifies all observers of a configuration change.
    private func notifyObservers(_ configuration: PWAConfiguration) {
        for handler in observers.values {
            handler(configuration)
        }
    }
}

// MARK: ConfigurationStore.Feature

extension ConfigurationStore {
    /// Represents a feature that can be enabled or disabled.
    public enum Feature: String, CaseIterable, Sendable {
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
        case microphonePermission
        case locationPermission

        /// The default value if configuration is not loaded.
        public var defaultValue: Bool {
            switch self {
            case .notifications,
                 .haptics,
                 .biometrics,
                 .secureStorage,
                 .share,
                 .print,
                 .clipboard,
                 .cameraPermission,
                 .microphonePermission,
                 .locationPermission:
                true
            case .healthkit,
                 .iap:
                false
            }
        }

        /// Checks if this feature is enabled in the given features configuration.
        public func isEnabled(in features: FeaturesConfiguration) -> Bool {
            switch self {
            case .notifications: features.notifications
            case .haptics: features.haptics
            case .biometrics: features.biometrics
            case .secureStorage: features.secureStorage
            case .healthkit: features.healthkit
            case .iap: features.iap
            case .share: features.share
            case .print: features.print
            case .clipboard: features.clipboard
            case .cameraPermission: features.cameraPermission
            case .microphonePermission: features.microphonePermission
            case .locationPermission: features.locationPermission
            }
        }
    }
}

// MARK: - ConfigurationStoreObservable

/// Observable wrapper for `ConfigurationStore` for SwiftUI integration.
///
/// This class provides an `ObservableObject` interface for use with SwiftUI views
/// on iOS 15+. It automatically updates published properties when the configuration
/// changes.
///
/// ## Example
///
/// ```swift
/// struct SettingsView: View {
///     @StateObject private var configStore = ConfigurationStoreObservable()
///
///     var body: some View {
///         Group {
///             if let config = configStore.configuration {
///                 Text("App: \(config.app.name)")
///             } else if configStore.isLoading {
///                 ProgressView()
///             } else if let error = configStore.error {
///                 Text("Error: \(error.localizedDescription)")
///             }
///         }
///         .task {
///             await configStore.load()
///         }
///     }
/// }
/// ```
@MainActor
public final class ConfigurationStoreObservable: ObservableObject {
    /// The current configuration, or `nil` if not loaded.
    @Published public private(set) var configuration: PWAConfiguration?

    /// Whether the configuration is currently loading.
    @Published public private(set) var isLoading = false

    /// The last error encountered, or `nil` if no error.
    @Published public private(set) var error: ConfigurationError?

    /// The underlying configuration store.
    private let store: ConfigurationStore

    /// The observer ID for configuration changes.
    private var observerId: UUID?

    /// Creates a new observable configuration store.
    ///
    /// - Parameter store: The underlying store to use. Defaults to `.shared`.
    public init(store: ConfigurationStore = .shared) {
        self.store = store
    }

    deinit {
        // Note: Cannot call async removeObserver in deinit.
        // Observer cleanup happens when store is deallocated or manually removed.
    }

    /// Loads the configuration.
    ///
    /// This method is safe to call multiple times; it will not reload
    /// if a load is already in progress.
    public func load() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let config = try await store.load()
            configuration = config
        } catch let loadError as ConfigurationError {
            error = loadError
        } catch {
            self.error = .unexpected(reason: error.localizedDescription)
        }

        isLoading = false
    }

    /// Reloads the configuration, bypassing caches.
    public func reload() async {
        isLoading = true
        error = nil

        do {
            let config = try await store.reload()
            configuration = config
        } catch let loadError as ConfigurationError {
            error = loadError
        } catch {
            self.error = .unexpected(reason: error.localizedDescription)
        }

        isLoading = false
    }

    /// Checks if a feature is enabled.
    ///
    /// - Parameter feature: The feature to check.
    /// - Returns: `true` if the feature is enabled.
    public func isFeatureEnabled(_ feature: ConfigurationStore.Feature) -> Bool {
        guard let config = configuration else {
            return feature.defaultValue
        }
        return feature.isEnabled(in: config.features)
    }

    /// Starts observing configuration changes.
    ///
    /// Call this method to receive updates when the configuration changes
    /// via `ConfigurationStore.reload()`.
    public func startObserving() async {
        guard observerId == nil else { return }

        observerId = await store.addObserver { [weak self] config in
            Task { @MainActor [weak self] in
                self?.configuration = config
            }
        }
    }

    /// Stops observing configuration changes.
    public func stopObserving() async {
        guard let id = observerId else { return }
        await store.removeObserver(id)
        observerId = nil
    }
}
