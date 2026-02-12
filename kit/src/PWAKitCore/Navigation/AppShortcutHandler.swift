import Foundation
import UIKit

// MARK: - AppShortcutHandler

/// Handles app shortcut (3D Touch / long press) navigation for PWA applications.
///
/// `AppShortcutHandler` parses `UIApplicationShortcutItem` instances and maps
/// shortcut types to URLs for WebView navigation.
///
/// ## Usage
///
/// ```swift
/// let handler = AppShortcutHandler(
///     baseURL: URL(string: "https://app.example.com")!,
///     shortcutMappings: [
///         "com.example.dashboard": "/dashboard",
///         "com.example.settings": "/settings"
///     ]
/// )
///
/// // When a shortcut is activated
/// if let url = handler.urlForShortcut(shortcutItem) {
///     handler.setPendingURL(url)
/// }
///
/// // When WebView is ready
/// if let pendingURL = handler.consumePendingURL() {
///     webView.load(URLRequest(url: pendingURL))
/// }
/// ```
///
/// ## Info.plist Configuration
///
/// Static shortcuts are defined in Info.plist under `UIApplicationShortcutItems`:
/// ```xml
/// <key>UIApplicationShortcutItems</key>
/// <array>
///     <dict>
///         <key>UIApplicationShortcutItemType</key>
///         <string>com.example.dashboard</string>
///         <key>UIApplicationShortcutItemTitle</key>
///         <string>Dashboard</string>
///         <key>UIApplicationShortcutItemIconType</key>
///         <string>UIApplicationShortcutIconTypeHome</string>
///     </dict>
/// </array>
/// ```
///
/// ## Thread Safety
///
/// This class is `Sendable` and uses `@MainActor` isolation for safe access
/// from any context.
@MainActor
public final class AppShortcutHandler {
    /// The base URL for constructing shortcut navigation URLs.
    private let baseURL: URL

    /// Mapping from shortcut type identifiers to URL paths.
    private let shortcutMappings: [String: String]

    /// The pending URL waiting to be navigated.
    private var pendingURL: URL?

    /// Callback invoked when a pending URL is set.
    ///
    /// Use this to trigger WebView navigation when a shortcut is activated
    /// while the app is already running.
    public var onPendingURLSet: ((URL) -> Void)?

    /// Creates a new app shortcut handler.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for constructing navigation URLs.
    ///   - shortcutMappings: A dictionary mapping shortcut type identifiers to URL paths.
    ///     The path will be appended to the base URL.
    public init(baseURL: URL, shortcutMappings: [String: String] = [:]) {
        self.baseURL = baseURL
        self.shortcutMappings = shortcutMappings
    }

    /// Creates an app shortcut handler from an app configuration.
    ///
    /// - Parameters:
    ///   - appConfig: The app configuration containing the start URL.
    ///   - shortcutMappings: A dictionary mapping shortcut type identifiers to URL paths.
    public convenience init?(appConfig: AppConfiguration, shortcutMappings: [String: String] = [:]) {
        guard let url = URL(string: appConfig.startUrl),
              let scheme = url.scheme,
              let host = url.host else
        {
            return nil
        }

        // Construct base URL from scheme and host
        var components = URLComponents()
        components.scheme = scheme
        components.host = host

        guard let baseURL = components.url else {
            return nil
        }

        self.init(baseURL: baseURL, shortcutMappings: shortcutMappings)
    }

    // MARK: - Shortcut Handling

    /// Checks if a shortcut type is configured for handling.
    ///
    /// - Parameter type: The shortcut type identifier.
    /// - Returns: `true` if the shortcut type has a mapping, `false` otherwise.
    public func canHandle(type: String) -> Bool {
        shortcutMappings[type] != nil
    }

    /// Returns the URL for a given shortcut type.
    ///
    /// If the shortcut type has a configured mapping, the corresponding path
    /// is appended to the base URL.
    ///
    /// If no mapping exists but the shortcut has a `userInfo` dictionary with
    /// a "url" or "path" key, that value is used instead.
    ///
    /// - Parameter type: The shortcut type identifier.
    /// - Returns: The navigation URL, or `nil` if no mapping exists.
    public func urlForShortcutType(_ type: String) -> URL? {
        if let path = shortcutMappings[type] {
            return baseURL.appendingPathComponent(path)
        }
        return nil
    }

    /// Returns the URL for a UIApplicationShortcutItem.
    ///
    /// This method first checks the shortcut mappings, then falls back to
    /// checking the shortcut's `userInfo` dictionary for a "url" or "path" key.
    ///
    /// - Parameter shortcutItem: The shortcut item to process.
    /// - Returns: The navigation URL, or `nil` if no mapping exists.
    public func urlForShortcut(_ shortcutItem: UIApplicationShortcutItem) -> URL? {
        // First, check configured mappings
        if let url = urlForShortcutType(shortcutItem.type) {
            return url
        }

        // Fall back to userInfo
        if let userInfo = shortcutItem.userInfo {
            // Check for explicit URL
            if let urlString = userInfo["url"] as? String,
               let url = URL(string: urlString)
            {
                return url
            }

            // Check for path
            if let path = userInfo["path"] as? String {
                return baseURL.appendingPathComponent(path)
            }
        }

        return nil
    }

    /// Handles a shortcut item and sets the pending URL.
    ///
    /// - Parameter shortcutItem: The shortcut item to handle.
    /// - Returns: `true` if the shortcut was handled, `false` otherwise.
    @discardableResult
    public func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let url = urlForShortcut(shortcutItem) else {
            return false
        }

        setPendingURL(url)
        return true
    }

    // MARK: - Pending URL Management

    /// Sets a pending URL to be navigated when the WebView is ready.
    ///
    /// Call this after resolving a shortcut to a URL.
    /// The URL will be stored until `consumePendingURL()` is called.
    ///
    /// If a URL is already pending, it will be replaced.
    ///
    /// - Parameter url: The URL to navigate to.
    public func setPendingURL(_ url: URL) {
        pendingURL = url
        onPendingURLSet?(url)
    }

    /// Consumes and returns the pending URL, if any.
    ///
    /// The pending URL is cleared after being consumed, so subsequent calls
    /// will return `nil` until a new URL is set.
    ///
    /// - Returns: The pending URL if one was set, `nil` otherwise.
    public func consumePendingURL() -> URL? {
        let url = pendingURL
        pendingURL = nil
        return url
    }

    /// Returns the pending URL without consuming it.
    ///
    /// Use this to check if there's a pending URL without clearing it.
    ///
    /// - Returns: The pending URL if one was set, `nil` otherwise.
    public func peekPendingURL() -> URL? {
        pendingURL
    }

    /// Checks if there is a pending URL waiting to be navigated.
    ///
    /// - Returns: `true` if a pending URL exists, `false` otherwise.
    public var hasPendingURL: Bool {
        pendingURL != nil
    }

    /// Clears any pending URL without consuming it.
    ///
    /// Use this when the pending URL should be discarded, for example when
    /// the user navigates elsewhere before the URL could be processed.
    public func clearPendingURL() {
        pendingURL = nil
    }

    // MARK: - Properties

    /// The configured base URL for navigation.
    public var base: URL {
        baseURL
    }

    /// The configured shortcut mappings.
    public var mappings: [String: String] {
        shortcutMappings
    }
}
