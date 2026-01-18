import Foundation
import StoreKit
import UIKit

// MARK: - AppModule

/// A module that provides app lifecycle and meta functionality to JavaScript.
///
/// `AppModule` exposes native app capabilities for version information,
/// requesting app reviews, and opening system settings.
///
/// ## Supported Actions
///
/// - `getVersion`: Returns app version and build information.
///   - Returns `{ version: "1.0.0", build: "1" }`
///
/// - `requestReview`: Requests an App Store review from the user.
///   - Uses `SKStoreReviewController.requestReview(in:)`
///   - Returns `{ requested: true }` when the request is made
///   - Note: iOS may limit how often the review prompt appears
///
/// - `openSettings`: Opens the app's settings page in the Settings app.
///   - Uses `UIApplication.openSettingsURLString`
///   - Returns `{ opened: true }` on success
///
/// ## Example
///
/// JavaScript request for version:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "app",
///   "action": "getVersion"
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": {
///     "version": "1.0.0",
///     "build": "42"
///   }
/// }
/// ```
///
/// JavaScript request to open settings:
/// ```json
/// {
///   "id": "def-456",
///   "module": "app",
///   "action": "openSettings"
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": {
///     "opened": true
///   }
/// }
/// ```
public struct AppModule: PWAModule {
    public static let moduleName = "app"
    public static let supportedActions = ["getVersion", "requestReview", "openSettings"]

    /// Creates a new app module instance.
    public init() {}

    public func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "getVersion":
            return getVersion()

        case "requestReview":
            return await requestReview()

        case "openSettings":
            return await openSettings()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - getVersion Action

    /// Returns the app's version and build number.
    ///
    /// Retrieves version information from the main bundle's Info.plist.
    ///
    /// - Returns: A dictionary containing `version` and `build` strings.
    private func getVersion() -> AnyCodable {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return AnyCodable([
            "version": AnyCodable(version),
            "build": AnyCodable(build),
        ])
    }

    // MARK: - requestReview Action

    /// Requests an App Store review from the user.
    ///
    /// Uses `SKStoreReviewController` to present the review dialog.
    /// iOS may limit how often this prompt is displayed to users.
    ///
    /// - Returns: A dictionary indicating whether the request was made.
    private func requestReview() async -> AnyCodable {
        await MainActor.run {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
        return AnyCodable([
            "requested": AnyCodable(true),
        ])
    }

    // MARK: - openSettings Action

    /// Opens the app's settings page in the Settings app.
    ///
    /// Uses `UIApplication.open` with the settings URL to navigate
    /// directly to this app's settings page.
    ///
    /// - Returns: A dictionary indicating whether settings were opened.
    private func openSettings() async -> AnyCodable {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return AnyCodable([
                "opened": AnyCodable(false),
                "error": AnyCodable("Unable to create settings URL"),
            ])
        }

        let opened = await MainActor.run {
            UIApplication.shared.canOpenURL(settingsURL)
        }

        if opened {
            await MainActor.run {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
            return AnyCodable([
                "opened": AnyCodable(true),
            ])
        } else {
            return AnyCodable([
                "opened": AnyCodable(false),
                "error": AnyCodable("Cannot open settings URL"),
            ])
        }
    }
}
