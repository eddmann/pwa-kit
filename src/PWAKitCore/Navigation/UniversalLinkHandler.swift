import Foundation

/// Handles universal link navigation for PWA applications.
///
/// `UniversalLinkHandler` manages incoming universal links (associated domain links)
/// and coordinates navigation to the appropriate URL when the WebView is ready.
///
/// ## Usage
///
/// ```swift
/// let handler = UniversalLinkHandler(
///     allowedOrigins: ["app.example.com", "*.example.com"]
/// )
///
/// // When a universal link is received
/// if handler.canHandle(url: incomingURL) {
///     handler.setPendingLink(incomingURL)
/// }
///
/// // When WebView is ready
/// if let pendingURL = handler.consumePendingLink() {
///     webView.load(URLRequest(url: pendingURL))
/// }
/// ```
///
/// ## Associated Domains
///
/// For universal links to work, the app must have an associated domains entitlement
/// configured in the format `applinks:your-domain.com`. The server must also serve
/// an apple-app-site-association (AASA) file at `.well-known/apple-app-site-association`.
///
/// ## Thread Safety
///
/// This class is `Sendable` and uses `@MainActor` isolation for safe access
/// from any context.
@MainActor
public final class UniversalLinkHandler {
    /// Origins that can be handled as universal links.
    private let allowedOrigins: [String]

    /// The pending link waiting to be navigated.
    private var pendingLink: URL?

    /// Callback invoked when a pending link is set.
    ///
    /// Use this to trigger WebView navigation when a link arrives while the app
    /// is already running.
    public var onPendingLinkSet: ((URL) -> Void)?

    /// Creates a new universal link handler.
    ///
    /// - Parameter allowedOrigins: Origins that can be handled as universal links.
    ///   Supports wildcard patterns like `*.example.com`.
    public init(allowedOrigins: [String]) {
        self.allowedOrigins = allowedOrigins
    }

    /// Creates a universal link handler from an origins configuration.
    ///
    /// - Parameter origins: The origins configuration containing allowed origins.
    public convenience init(origins: OriginsConfiguration) {
        self.init(allowedOrigins: origins.allowed)
    }

    // MARK: - Link Handling

    /// Checks if a URL can be handled as a universal link.
    ///
    /// A URL can be handled if:
    /// - It uses the `https` scheme
    /// - Its host matches one of the allowed origins
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL can be handled, `false` otherwise.
    public func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return false
        }

        return matchesAllowedOrigin(url)
    }

    /// Sets a pending link to be navigated when the WebView is ready.
    ///
    /// Call this when a universal link is received. The link will be stored
    /// until `consumePendingLink()` is called.
    ///
    /// If a link is already pending, it will be replaced.
    ///
    /// - Parameter url: The universal link URL.
    public func setPendingLink(_ url: URL) {
        pendingLink = url
        onPendingLinkSet?(url)
    }

    /// Consumes and returns the pending link, if any.
    ///
    /// The pending link is cleared after being consumed, so subsequent calls
    /// will return `nil` until a new link is set.
    ///
    /// - Returns: The pending URL if one was set, `nil` otherwise.
    public func consumePendingLink() -> URL? {
        let link = pendingLink
        pendingLink = nil
        return link
    }

    /// Returns the pending link without consuming it.
    ///
    /// Use this to check if there's a pending link without clearing it.
    ///
    /// - Returns: The pending URL if one was set, `nil` otherwise.
    public func peekPendingLink() -> URL? {
        pendingLink
    }

    /// Checks if there is a pending link waiting to be navigated.
    ///
    /// - Returns: `true` if a pending link exists, `false` otherwise.
    public var hasPendingLink: Bool {
        pendingLink != nil
    }

    /// Clears any pending link without consuming it.
    ///
    /// Use this when the pending link should be discarded, for example when
    /// the user navigates elsewhere before the link could be processed.
    public func clearPendingLink() {
        pendingLink = nil
    }

    // MARK: - URL Activity Handling

    /// Handles an NSUserActivity for universal links.
    ///
    /// This is a convenience method for handling `NSUserActivityTypeBrowsingWeb`
    /// activities received in `scene(_:continue:)` or similar lifecycle methods.
    ///
    /// - Parameter activity: The user activity to handle.
    /// - Returns: `true` if the activity was handled, `false` otherwise.
    public func handleUserActivity(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else
        {
            return false
        }

        guard canHandle(url: url) else {
            return false
        }

        setPendingLink(url)
        return true
    }

    // MARK: - Private Methods

    /// Checks if a URL matches any of the allowed origins.
    private func matchesAllowedOrigin(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        return allowedOrigins.contains { pattern in
            matchesDomain(host, pattern: pattern.lowercased())
        }
    }

    /// Matches a hostname against a domain pattern.
    ///
    /// - Parameters:
    ///   - host: The hostname to check.
    ///   - pattern: The domain pattern (may include wildcard `*`).
    /// - Returns: Whether the host matches the pattern.
    private func matchesDomain(_ host: String, pattern: String) -> Bool {
        // Handle path patterns by extracting just the domain part
        let domainPattern: String = if let slashIndex = pattern.firstIndex(of: "/") {
            String(pattern[..<slashIndex])
        } else {
            pattern
        }

        // Wildcard subdomain pattern: *.example.com
        if domainPattern.hasPrefix("*.") {
            let suffix = String(domainPattern.dropFirst(2))
            // Must match exactly or be a subdomain
            return host == suffix || host.hasSuffix(".\(suffix)")
        }

        // Exact match
        return host == domainPattern
    }
}
