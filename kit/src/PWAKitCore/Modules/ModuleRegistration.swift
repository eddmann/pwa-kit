import Foundation

/// Utilities for registering default modules with the bridge dispatcher.
///
/// This enum provides convenient methods for registering all built-in modules
/// with a `BridgeDispatcher` or `ModuleRegistry`. It supports both unconditional
/// registration and feature-flag-based conditional registration.
///
/// ## Usage
///
/// ### Register all default modules unconditionally:
/// ```swift
/// let dispatcher = BridgeDispatcher()
/// await ModuleRegistration.registerDefaultModules(in: dispatcher)
/// ```
///
/// ### Register modules based on feature flags:
/// ```swift
/// let dispatcher = BridgeDispatcher()
/// let features = FeaturesConfiguration(haptics: true, notifications: false)
/// await ModuleRegistration.registerDefaultModules(
///     in: dispatcher,
///     features: features
/// )
/// ```
///
/// ## Module Registration
///
/// The following modules are registered by default:
/// - `PlatformModule`: Always registered (no feature flag)
/// - `AppModule`: Always registered (no feature flag)
/// - `HapticsModule`: Registered when `features.haptics` is enabled
/// - `NotificationsModule`: Registered when `features.notifications` is enabled
/// - `ShareModule`: Registered when `features.share` is enabled
/// - `BiometricsModule`: Registered when `features.biometrics` is enabled
/// - `SecureStorageModule`: Registered when `features.secureStorage` is enabled
/// - `PrintModule`: Registered when `features.print` is enabled
/// - `ClipboardModule`: Registered when `features.clipboard` is enabled
/// - `IAPModule`: Registered when `features.iap` is enabled
/// - `HealthKitModule`: Registered when `features.healthkit` is enabled
/// - `CameraPermissionModule`: Registered when `features.cameraPermission` is enabled
/// - `LocationPermissionModule`: Registered when `features.locationPermission` is enabled
public enum ModuleRegistration {
    /// Registers all default modules with the given dispatcher.
    ///
    /// This method registers the built-in modules that are always enabled,
    /// regardless of feature flags. Modules that depend on feature flags
    /// should use `registerDefaultModules(in:features:)` instead.
    ///
    /// - Parameter dispatcher: The bridge dispatcher to register modules with.
    /// - Returns: The number of modules registered.
    @discardableResult
    public static func registerDefaultModules(
        in dispatcher: BridgeDispatcher
    ) async -> Int {
        // PlatformModule is always registered (no feature flag)
        await dispatcher.register(PlatformModule())

        // AppModule is always registered (no feature flag)
        await dispatcher.register(AppModule())

        return 2
    }

    /// Registers all default modules with the given dispatcher, respecting feature flags.
    ///
    /// This method registers built-in modules conditionally based on the provided
    /// feature configuration. Modules without a feature flag are always registered.
    ///
    /// - Parameters:
    ///   - dispatcher: The bridge dispatcher to register modules with.
    ///   - features: The features configuration to check against.
    /// - Returns: The number of modules registered.
    @discardableResult
    public static func registerDefaultModules(
        in dispatcher: BridgeDispatcher,
        features: FeaturesConfiguration
    ) async -> Int {
        var count = 0

        // PlatformModule is always registered (no feature flag)
        await dispatcher.register(PlatformModule())
        count += 1

        // AppModule is always registered (no feature flag)
        await dispatcher.register(AppModule())
        count += 1

        // HapticsModule is registered conditionally based on feature flag
        if features.haptics {
            await dispatcher.register(HapticsModule())
            count += 1
        }

        // NotificationsModule is registered conditionally based on feature flag
        if features.notifications {
            await dispatcher.register(NotificationsModule())
            count += 1
        }

        // ShareModule is registered conditionally based on feature flag
        if features.share {
            await dispatcher.register(ShareModule())
            count += 1
        }

        // BiometricsModule is registered conditionally based on feature flag
        if features.biometrics {
            await dispatcher.register(BiometricsModule())
            count += 1
        }

        // SecureStorageModule is registered conditionally based on feature flag
        if features.secureStorage {
            await dispatcher.register(SecureStorageModule())
            count += 1
        }

        // PrintModule is registered conditionally based on feature flag
        if features.print {
            await dispatcher.register(PrintModule())
            count += 1
        }

        // ClipboardModule is registered conditionally based on feature flag
        if features.clipboard {
            await dispatcher.register(ClipboardModule())
            count += 1
        }

        // IAPModule is registered conditionally based on feature flag
        if features.iap {
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                await dispatcher.register(IAPModule())
                count += 1
            }
        }

        // HealthKitModule is registered conditionally based on feature flag
        if features.healthkit {
            if #available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *) {
                await dispatcher.register(HealthKitModule())
                count += 1
            }
        }

        // CameraPermissionModule is registered conditionally based on feature flag
        if features.cameraPermission {
            await dispatcher.register(CameraPermissionModule())
            count += 1
        }

        // MicrophonePermissionModule is registered conditionally based on feature flag
        if features.microphonePermission {
            await dispatcher.register(MicrophonePermissionModule())
            count += 1
        }

        // LocationPermissionModule is registered conditionally based on feature flag
        if features.locationPermission {
            await dispatcher.register(LocationPermissionModule())
            count += 1
        }

        return count
    }

    /// Registers all default modules with the given registry.
    ///
    /// This method provides direct access to the module registry for cases
    /// where you need more control over the registration process.
    ///
    /// - Parameter registry: The module registry to register modules with.
    /// - Returns: The number of modules registered.
    @discardableResult
    public static func registerDefaultModules(
        in registry: ModuleRegistry
    ) async -> Int {
        // PlatformModule is always registered (no feature flag)
        await registry.register(PlatformModule())

        // AppModule is always registered (no feature flag)
        await registry.register(AppModule())

        return 2
    }

    /// Registers all default modules with the given registry, respecting feature flags.
    ///
    /// - Parameters:
    ///   - registry: The module registry to register modules with.
    ///   - features: The features configuration to check against.
    /// - Returns: The number of modules registered.
    @discardableResult
    public static func registerDefaultModules(
        in registry: ModuleRegistry,
        features: FeaturesConfiguration
    ) async -> Int {
        var count = 0

        // PlatformModule is always registered (no feature flag)
        await registry.register(PlatformModule())
        count += 1

        // AppModule is always registered (no feature flag)
        await registry.register(AppModule())
        count += 1

        // HapticsModule is registered conditionally based on feature flag
        if features.haptics {
            await registry.register(HapticsModule())
            count += 1
        }

        // NotificationsModule is registered conditionally based on feature flag
        if features.notifications {
            await registry.register(NotificationsModule())
            count += 1
        }

        // ShareModule is registered conditionally based on feature flag
        if features.share {
            await registry.register(ShareModule())
            count += 1
        }

        // BiometricsModule is registered conditionally based on feature flag
        if features.biometrics {
            await registry.register(BiometricsModule())
            count += 1
        }

        // SecureStorageModule is registered conditionally based on feature flag
        if features.secureStorage {
            await registry.register(SecureStorageModule())
            count += 1
        }

        // PrintModule is registered conditionally based on feature flag
        if features.print {
            await registry.register(PrintModule())
            count += 1
        }

        // ClipboardModule is registered conditionally based on feature flag
        if features.clipboard {
            await registry.register(ClipboardModule())
            count += 1
        }

        // IAPModule is registered conditionally based on feature flag
        if features.iap {
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                await registry.register(IAPModule())
                count += 1
            }
        }

        // HealthKitModule is registered conditionally based on feature flag
        if features.healthkit {
            if #available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *) {
                await registry.register(HealthKitModule())
                count += 1
            }
        }

        // CameraPermissionModule is registered conditionally based on feature flag
        if features.cameraPermission {
            await registry.register(CameraPermissionModule())
            count += 1
        }

        // MicrophonePermissionModule is registered conditionally based on feature flag
        if features.microphonePermission {
            await registry.register(MicrophonePermissionModule())
            count += 1
        }

        // LocationPermissionModule is registered conditionally based on feature flag
        if features.locationPermission {
            await registry.register(LocationPermissionModule())
            count += 1
        }

        return count
    }

    /// Returns a list of all module names that would be registered with default settings.
    ///
    /// This is useful for documentation and debugging purposes.
    public static var defaultModuleNames: [String] {
        [
            PlatformModule.moduleName,
            AppModule.moduleName,
        ]
    }

    /// Returns a list of all module names that would be registered with the given features.
    ///
    /// - Parameter features: The features configuration to check against.
    /// - Returns: An array of module names that would be registered.
    public static func moduleNames(for features: FeaturesConfiguration) -> [String] {
        var names = [String]()

        // PlatformModule is always registered
        names.append(PlatformModule.moduleName)

        // AppModule is always registered
        names.append(AppModule.moduleName)

        // HapticsModule is registered conditionally based on feature flag
        if features.haptics {
            names.append(HapticsModule.moduleName)
        }

        // NotificationsModule is registered conditionally based on feature flag
        if features.notifications {
            names.append(NotificationsModule.moduleName)
        }

        // ShareModule is registered conditionally based on feature flag
        if features.share {
            names.append(ShareModule.moduleName)
        }

        // BiometricsModule is registered conditionally based on feature flag
        if features.biometrics {
            names.append(BiometricsModule.moduleName)
        }

        // SecureStorageModule is registered conditionally based on feature flag
        if features.secureStorage {
            names.append(SecureStorageModule.moduleName)
        }

        // PrintModule is registered conditionally based on feature flag
        if features.print {
            names.append(PrintModule.moduleName)
        }

        // ClipboardModule is registered conditionally based on feature flag
        if features.clipboard {
            names.append(ClipboardModule.moduleName)
        }

        // IAPModule is registered conditionally based on feature flag
        if features.iap {
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                names.append(IAPModule.moduleName)
            }
        }

        // HealthKitModule is registered conditionally based on feature flag
        if features.healthkit {
            if #available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *) {
                names.append(HealthKitModule.moduleName)
            }
        }

        // CameraPermissionModule is registered conditionally based on feature flag
        if features.cameraPermission {
            names.append(CameraPermissionModule.moduleName)
        }

        // MicrophonePermissionModule is registered conditionally based on feature flag
        if features.microphonePermission {
            names.append(MicrophonePermissionModule.moduleName)
        }

        // LocationPermissionModule is registered conditionally based on feature flag
        if features.locationPermission {
            names.append(LocationPermissionModule.moduleName)
        }

        return names
    }
}
