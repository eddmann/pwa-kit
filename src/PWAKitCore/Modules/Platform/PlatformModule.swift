import Foundation
import UIKit

// MARK: - PlatformModule

/// A module that provides platform and device information to JavaScript.
///
/// `PlatformModule` exposes native platform details that web applications
/// can use to adapt their behavior or UI for the native app context.
///
/// ## Supported Actions
///
/// - `getInfo`: Returns comprehensive platform information including:
///   - `platform`: The operating system name (e.g., "iOS")
///   - `version`: The OS version (e.g., "17.0")
///   - `isNative`: Always `true` when running in the native shell
///   - `appVersion`: The app's version string from the bundle
///   - `appBuild`: The app's build number from the bundle
///   - `deviceModel`: The device model identifier
///   - `deviceName`: The user-assigned device name (if available)
///
/// ## Example
///
/// JavaScript request:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "platform",
///   "action": "getInfo"
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": {
///     "platform": "iOS",
///     "version": "17.0",
///     "isNative": true,
///     "appVersion": "1.0.0",
///     "appBuild": "1",
///     "deviceModel": "iPhone",
///     "deviceName": "John's iPhone"
///   }
/// }
/// ```
public struct PlatformModule: PWAModule {
    public static let moduleName = "platform"
    public static let supportedActions = ["getInfo"]

    /// Creates a new platform module instance.
    public init() {}

    public func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "getInfo":
            return getInfo()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Action Handlers

    /// Returns comprehensive platform and device information.
    ///
    /// This method gathers information from `UIDevice.current` and `Bundle.main`
    /// to provide a complete picture of the runtime environment.
    ///
    /// - Returns: A dictionary containing platform information.
    private func getInfo() -> AnyCodable {
        let device = UIDevice.current
        let platform = device.systemName
        let version = device.systemVersion
        let deviceModel = device.model
        let deviceName = device.name

        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let appBuild = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return AnyCodable([
            "platform": AnyCodable(platform),
            "version": AnyCodable(version),
            "isNative": AnyCodable(true),
            "appVersion": AnyCodable(appVersion),
            "appBuild": AnyCodable(appBuild),
            "deviceModel": AnyCodable(deviceModel),
            "deviceName": AnyCodable(deviceName),
        ])
    }
}
