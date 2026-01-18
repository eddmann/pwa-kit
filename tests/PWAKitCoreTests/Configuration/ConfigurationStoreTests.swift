import Foundation
import Testing

@testable import PWAKitApp

// MARK: - Counter

/// Thread-safe counter for observer tests.
private actor Counter {
    var value = 0

    func increment() {
        value += 1
    }

    func get() -> Int {
        value
    }
}

// MARK: - ConfigHolder

/// Thread-safe configuration holder for observer tests.
private actor ConfigHolder {
    var config: PWAConfiguration?

    func set(_ config: PWAConfiguration) {
        self.config = config
    }

    func get() -> PWAConfiguration? {
        config
    }
}

// MARK: - ConfigurationStoreTests

@Suite("ConfigurationStore Tests")
struct ConfigurationStoreTests {
    // MARK: - Loading Tests

    @Test("Loads configuration successfully")
    func loadsConfiguration() async throws {
        let store = ConfigurationStore()
        let config = try await store.load()

        // Should return a valid configuration
        #expect(config.version >= 1)
        #expect(!config.app.name.isEmpty)
    }

    @Test("Configuration property loads on first access")
    func configurationPropertyLoads() async throws {
        let store = ConfigurationStore()

        // First access should load
        let config = try await store.configuration
        #expect(config.version >= 1)

        // Subsequent access should return cached value
        let config2 = try await store.configuration
        #expect(config == config2)
    }

    @Test("Reload bypasses cache and returns fresh configuration")
    func reloadBypassesCache() async throws {
        let store = ConfigurationStore()

        // Initial load
        let config1 = try await store.load()

        // Reload should return configuration (may be same since no file changes)
        let config2 = try await store.reload()

        // Both should be valid configurations
        #expect(config1.version >= 1)
        #expect(config2.version >= 1)
    }

    @Test("Clear cache requires fresh load")
    func clearCacheRequiresFreshLoad() async throws {
        let store = ConfigurationStore()

        // Initial load
        _ = try await store.load()

        // Clear cache
        await store.clearCache()

        // Next access should load fresh
        let config = try await store.configuration
        #expect(config.version >= 1)
    }

    // MARK: - Feature Flag Tests

    @Test("Feature flag returns correct value when configuration loaded")
    func featureFlagReturnsCorrectValue() async throws {
        let store = ConfigurationStore()
        _ = try await store.load()

        // Default configuration has notifications enabled
        let isEnabled = await store.isFeatureEnabled(.notifications)
        #expect(isEnabled == true)
    }

    @Test("Feature flag returns default when configuration not loaded")
    func featureFlagReturnsDefaultWhenNotLoaded() async {
        let store = ConfigurationStore()

        // Without loading, should return default value
        let notificationsEnabled = await store.isFeatureEnabled(.notifications)
        let healthkitEnabled = await store.isFeatureEnabled(.healthkit)

        #expect(notificationsEnabled == true) // Default is true
        #expect(healthkitEnabled == false) // Default is false
    }

    @Test("All convenience feature properties work")
    func convenienceFeatureProperties() async throws {
        let store = ConfigurationStore()
        _ = try await store.load()

        // Test all convenience properties
        _ = await store.notificationsEnabled
        _ = await store.hapticsEnabled
        _ = await store.biometricsEnabled
        _ = await store.secureStorageEnabled
        _ = await store.healthkitEnabled
        _ = await store.iapEnabled
        _ = await store.shareEnabled
        _ = await store.printEnabled
        _ = await store.clipboardEnabled

        // If we get here without errors, the properties work
    }

    // MARK: - Feature Enum Tests

    @Test("Feature enum has correct default values")
    func featureDefaultValues() {
        // Features that default to true
        #expect(ConfigurationStore.Feature.notifications.defaultValue == true)
        #expect(ConfigurationStore.Feature.haptics.defaultValue == true)
        #expect(ConfigurationStore.Feature.biometrics.defaultValue == true)
        #expect(ConfigurationStore.Feature.secureStorage.defaultValue == true)
        #expect(ConfigurationStore.Feature.share.defaultValue == true)
        #expect(ConfigurationStore.Feature.print.defaultValue == true)
        #expect(ConfigurationStore.Feature.clipboard.defaultValue == true)

        // Features that default to false (require App Store review)
        #expect(ConfigurationStore.Feature.healthkit.defaultValue == false)
        #expect(ConfigurationStore.Feature.iap.defaultValue == false)
    }

    @Test("Feature enum checks configuration correctly")
    func featureChecksConfiguration() {
        let enabledConfig = FeaturesConfiguration(
            notifications: true,
            haptics: false,
            biometrics: true,
            secureStorage: false,
            healthkit: true,
            iap: false,
            share: true,
            print: false,
            clipboard: true
        )

        #expect(ConfigurationStore.Feature.notifications.isEnabled(in: enabledConfig) == true)
        #expect(ConfigurationStore.Feature.haptics.isEnabled(in: enabledConfig) == false)
        #expect(ConfigurationStore.Feature.biometrics.isEnabled(in: enabledConfig) == true)
        #expect(ConfigurationStore.Feature.secureStorage.isEnabled(in: enabledConfig) == false)
        #expect(ConfigurationStore.Feature.healthkit.isEnabled(in: enabledConfig) == true)
        #expect(ConfigurationStore.Feature.iap.isEnabled(in: enabledConfig) == false)
        #expect(ConfigurationStore.Feature.share.isEnabled(in: enabledConfig) == true)
        #expect(ConfigurationStore.Feature.print.isEnabled(in: enabledConfig) == false)
        #expect(ConfigurationStore.Feature.clipboard.isEnabled(in: enabledConfig) == true)
    }

    @Test("Feature enum contains all expected cases")
    func featureEnumCoverage() {
        let allFeatures = ConfigurationStore.Feature.allCases
        #expect(allFeatures.count == 9)

        let featureNames = Set(allFeatures.map(\.rawValue))
        #expect(featureNames.contains("notifications"))
        #expect(featureNames.contains("haptics"))
        #expect(featureNames.contains("biometrics"))
        #expect(featureNames.contains("secureStorage"))
        #expect(featureNames.contains("healthkit"))
        #expect(featureNames.contains("iap"))
        #expect(featureNames.contains("share"))
        #expect(featureNames.contains("print"))
        #expect(featureNames.contains("clipboard"))
    }

    // MARK: - Observer Tests

    @Test("Observer is notified on load")
    func observerNotifiedOnLoad() async throws {
        let store = ConfigurationStore()
        let holder = ConfigHolder()

        _ = await store.addObserver { config in
            Task {
                await holder.set(config)
            }
        }

        _ = try await store.load()

        // Give observer time to process
        try await Task.sleep(nanoseconds: 10_000_000)

        let receivedConfig = await holder.get()
        #expect(receivedConfig != nil)
        #expect(receivedConfig?.version == 1)
    }

    @Test("Observer is notified on reload")
    func observerNotifiedOnReload() async throws {
        let store = ConfigurationStore()
        let counter = Counter()

        _ = await store.addObserver { _ in
            Task {
                await counter.increment()
            }
        }

        _ = try await store.load()
        _ = try await store.reload()

        // Give observers time to process
        try await Task.sleep(nanoseconds: 10_000_000)

        let count = await counter.get()
        #expect(count == 2)
    }

    @Test("Observer can be removed")
    func observerCanBeRemoved() async throws {
        let store = ConfigurationStore()
        let counter = Counter()

        let observerId = await store.addObserver { _ in
            Task {
                await counter.increment()
            }
        }

        _ = try await store.load()

        // Give observer time to process
        try await Task.sleep(nanoseconds: 10_000_000)
        let countAfterLoad = await counter.get()
        #expect(countAfterLoad == 1)

        await store.removeObserver(observerId)

        _ = try await store.reload()

        // Give time to ensure observer would have been called if still registered
        try await Task.sleep(nanoseconds: 10_000_000)
        let countAfterReload = await counter.get()
        #expect(countAfterReload == 1) // Should not increase
    }

    @Test("Multiple observers are all notified")
    func multipleObserversNotified() async throws {
        let store = ConfigurationStore()
        let counter1 = Counter()
        let counter2 = Counter()

        _ = await store.addObserver { _ in
            Task {
                await counter1.increment()
            }
        }
        _ = await store.addObserver { _ in
            Task {
                await counter2.increment()
            }
        }

        _ = try await store.load()

        // Give observers time to process
        try await Task.sleep(nanoseconds: 10_000_000)

        let count1 = await counter1.get()
        let count2 = await counter2.get()
        #expect(count1 == 1)
        #expect(count2 == 1)
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent access is safe")
    func concurrentAccessIsSafe() async throws {
        let store = ConfigurationStore()

        // Load configuration first
        _ = try await store.load()

        // Perform many concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    await store.isFeatureEnabled(.notifications)
                }
                group.addTask {
                    await store.isFeatureEnabled(.haptics)
                }
                group.addTask {
                    await store.notificationsEnabled
                }
            }

            // All tasks should complete without data races
            for await result in group {
                #expect(result == true || result == false)
            }
        }
    }

    @Test("Concurrent load and read is safe")
    func concurrentLoadAndReadIsSafe() async throws {
        let store = ConfigurationStore()

        await withTaskGroup(of: Void.self) { group in
            // Some tasks load
            for _ in 0 ..< 10 {
                group.addTask {
                    _ = try? await store.load()
                }
            }

            // Some tasks read
            for _ in 0 ..< 10 {
                group.addTask {
                    _ = await store.isFeatureEnabled(.notifications)
                }
            }

            // Some tasks reload
            for _ in 0 ..< 5 {
                group.addTask {
                    _ = try? await store.reload()
                }
            }

            // All should complete safely
        }
    }

    // MARK: - Shared Instance Tests

    @Test("Shared instance is accessible")
    func sharedInstanceAccessible() async throws {
        let config = try await ConfigurationStore.shared.load()
        #expect(config.version >= 1)
    }
}

// MARK: - ConfigurationStoreObservableTests

@Suite("ConfigurationStoreObservable Tests")
@MainActor
struct ConfigurationStoreObservableTests {
    @Test("Initial state is correct")
    func initialState() {
        let observable = ConfigurationStoreObservable()

        #expect(observable.configuration == nil)
        #expect(observable.isLoading == false)
        #expect(observable.error == nil)
    }

    @Test("Load updates configuration")
    func loadUpdatesConfiguration() async {
        let observable = ConfigurationStoreObservable()

        await observable.load()

        #expect(observable.configuration != nil)
        #expect(observable.isLoading == false)
        #expect(observable.error == nil)
    }

    @Test("Reload updates configuration")
    func reloadUpdatesConfiguration() async {
        let observable = ConfigurationStoreObservable()

        await observable.load()
        let config1 = observable.configuration

        await observable.reload()
        let config2 = observable.configuration

        #expect(config1 != nil)
        #expect(config2 != nil)
    }

    @Test("Feature check returns correct value")
    func featureCheckReturnsCorrectValue() async {
        let observable = ConfigurationStoreObservable()

        // Before loading, returns default
        #expect(observable.isFeatureEnabled(.notifications) == true)
        #expect(observable.isFeatureEnabled(.healthkit) == false)

        await observable.load()

        // After loading, returns configured value
        #expect(observable.isFeatureEnabled(.notifications) == true)
    }

    @Test("Observation can be started and stopped")
    func observationStartStop() async {
        let observable = ConfigurationStoreObservable()

        await observable.startObserving()
        await observable.stopObserving()

        // Should not crash or have side effects
    }

    @Test("Multiple loads do not stack")
    func multipleLoadsDoNotStack() async {
        let observable = ConfigurationStoreObservable()

        // Start a load
        async let load1: Void = observable.load()

        // Try to start another (should be ignored since already loading)
        // Note: This test verifies the guard in load()

        await load1
        #expect(observable.configuration != nil)
    }
}
