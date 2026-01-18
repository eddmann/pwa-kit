import Foundation

/// Handles custom URL scheme navigation for PWA applications.
///
/// `CustomSchemeHandler` converts custom URL schemes (e.g., `mypwa://`)
/// to HTTPS URLs and coordinates navigation when the WebView is ready.
///
/// ## Usage
///
/// ```swift
/// let handler = CustomSchemeHandler(
///     customScheme: "mypwa",
///     targetHost: "app.example.com"
/// )
///
/// // When a custom scheme URL is received
/// if let httpsURL = handler.convertToHTTPS(customSchemeURL) {
///     handler.setPendingURL(httpsURL)
/// }
///
/// // When WebView is ready
/// if let pendingURL = handler.consumePendingURL() {
///     webView.load(URLRequest(url: pendingURL))
/// }
/// ```
///
/// ## Custom URL Scheme Configuration
///
/// To use custom schemes, add them to Info.plist under `CFBundleURLTypes`.
/// The app will then be able to open URLs like `mypwa://path/to/content`.
///
/// ## Thread Safety
///
/// This class is `Sendable` and uses `@MainActor` isolation for safe access
/// from any context.
@MainActor
public final class CustomSchemeHandler {
    /// The custom URL scheme to handle (without "://").
    private let customScheme: String

    /// The target host to use when converting to HTTPS.
    private let targetHost: String

    /// The pending URL waiting to be navigated.
    private var pendingURL: URL?

    /// Callback invoked when a pending URL is set.
    ///
    /// Use this to trigger WebView navigation when a custom scheme URL arrives
    /// while the app is already running.
    public var onPendingURLSet: ((URL) -> Void)?

    /// Creates a new custom scheme handler.
    ///
    /// - Parameters:
    ///   - customScheme: The custom URL scheme to handle (e.g., "mypwa").
    ///   - targetHost: The target host for HTTPS URLs (e.g., "app.example.com").
    public init(customScheme: String, targetHost: String) {
        // Normalize the scheme by removing "://" suffix if present
        self.customScheme = customScheme.lowercased().replacingOccurrences(of: "://", with: "")
        self.targetHost = targetHost.lowercased()
    }

    /// Creates a custom scheme handler from an app configuration.
    ///
    /// The custom scheme is derived from the bundle ID (last component)
    /// and the target host is extracted from the start URL.
    ///
    /// - Parameter appConfig: The app configuration containing startUrl and bundleId.
    public convenience init?(appConfig: AppConfiguration) {
        guard let startURL = URL(string: appConfig.startUrl),
              let host = startURL.host else
        {
            return nil
        }

        // Use bundle ID last component as scheme (e.g., "com.example.mypwa" -> "mypwa")
        let scheme = appConfig.bundleId.components(separatedBy: ".").last ?? appConfig.bundleId
        self.init(customScheme: scheme, targetHost: host)
    }

    // MARK: - Scheme Handling

    /// Checks if a URL uses the configured custom scheme.
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL uses the custom scheme, `false` otherwise.
    public func isCustomScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == customScheme
    }

    /// Converts a custom scheme URL to an HTTPS URL.
    ///
    /// The conversion preserves the path, query, and fragment from the original URL:
    /// - `mypwa://path/to/page?query=value#section`
    /// - becomes `https://app.example.com/path/to/page?query=value#section`
    ///
    /// - Parameter url: The custom scheme URL to convert.
    /// - Returns: The equivalent HTTPS URL, or `nil` if conversion fails.
    public func convertToHTTPS(_ url: URL) -> URL? {
        guard isCustomScheme(url) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = targetHost

        // Preserve path - custom scheme URLs treat host as path
        // e.g., mypwa://dashboard/page becomes https://targetHost/dashboard/page
        // where "dashboard" is parsed as url.host and "/page" as url.path
        var pathComponents: [String] = []

        // In custom schemes, the "host" is actually the first path segment
        if let host = url.host, !host.isEmpty {
            pathComponents.append(host)
        }

        // Append the actual path (without leading /)
        let urlPath = url.path
        if !urlPath.isEmpty {
            let trimmedPath = urlPath.hasPrefix("/") ? String(urlPath.dropFirst()) : urlPath
            if !trimmedPath.isEmpty {
                pathComponents.append(trimmedPath)
            }
        }

        // Build final path
        let path = pathComponents.isEmpty ? "" : "/" + pathComponents.joined(separator: "/")

        components.path = path
        components.query = url.query
        components.fragment = url.fragment

        return components.url
    }

    // MARK: - Pending URL Management

    /// Sets a pending URL to be navigated when the WebView is ready.
    ///
    /// Call this after converting a custom scheme URL to HTTPS.
    /// The URL will be stored until `consumePendingURL()` is called.
    ///
    /// If a URL is already pending, it will be replaced.
    ///
    /// - Parameter url: The HTTPS URL to navigate to.
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

    // MARK: - URL Context Handling

    /// Handles a URL context from scene lifecycle methods.
    ///
    /// This is a convenience method for handling `UIOpenURLContext` URLs
    /// received in `scene(_:openURLContexts:)` or similar lifecycle methods.
    ///
    /// - Parameter url: The URL to handle.
    /// - Returns: `true` if the URL was handled, `false` otherwise.
    public func handleURL(_ url: URL) -> Bool {
        guard isCustomScheme(url) else {
            return false
        }

        guard let httpsURL = convertToHTTPS(url) else {
            return false
        }

        setPendingURL(httpsURL)
        return true
    }

    // MARK: - Properties

    /// The configured custom URL scheme.
    public var scheme: String {
        customScheme
    }

    /// The configured target host for HTTPS conversion.
    public var host: String {
        targetHost
    }
}
