import Foundation
import WebKit

// MARK: - PlatformCookieManager

/// Manages platform cookies for the WKWebView.
///
/// The PlatformCookieManager sets cookies that identify the app as a native iOS
/// wrapper to the web content. This allows web applications to detect when they're
/// running inside the PWAKit shell and adapt their behavior accordingly.
///
/// The manager also supports injecting a referrer script that sets the document
/// referrer, which can be useful for analytics and origin tracking.
///
/// ## Cookie Details
///
/// The platform cookie is set with the following properties:
/// - **Name**: Configurable, defaults to `"app-platform"`
/// - **Value**: Configurable, defaults to `"ios"`
/// - **Expiration**: 1 year from the current date
/// - **Domain**: Matches the configured domain or URL host
/// - **Path**: Root path `"/"`
/// - **Secure**: Yes (HTTPS only)
/// - **SameSite**: Lax (allows same-site and top-level navigation)
///
/// ## Example
///
/// ```swift
/// let cookieManager = PlatformCookieManager(settings: .default)
///
/// // Set cookie for a specific URL
/// await cookieManager.setCookie(
///     for: URL(string: "https://app.example.com/")!,
///     in: webView.configuration.websiteDataStore.httpCookieStore
/// )
///
/// // Or inject as a user script
/// let script = cookieManager.makeCookieScript(for: URL(string: "https://app.example.com/")!)
/// webView.configuration.userContentController.addUserScript(script)
/// ```
public final class PlatformCookieManager: Sendable {
    /// The settings for the platform cookie.
    public let settings: PlatformCookieSettings

    /// The number of seconds in one year, used for cookie expiration.
    private static let oneYearInSeconds: TimeInterval = 365 * 24 * 60 * 60

    /// Creates a new platform cookie manager.
    ///
    /// - Parameter settings: The cookie settings to use. Defaults to `.default`.
    public init(settings: PlatformCookieSettings = .default) {
        self.settings = settings
    }

    // MARK: - Cookie Creation

    /// Creates an HTTPCookie for the platform identifier.
    ///
    /// - Parameters:
    ///   - url: The URL to create the cookie for. The cookie domain is derived from this.
    ///   - expirationDate: Optional custom expiration date. Defaults to 1 year from now.
    /// - Returns: An HTTPCookie configured for platform identification, or nil if creation fails.
    public func makeCookie(
        for url: URL,
        expirationDate: Date? = nil
    ) -> HTTPCookie? {
        guard settings.enabled else { return nil }
        guard let host = url.host else { return nil }

        let domain = extractCookieDomain(from: host)
        let expiration = expirationDate ?? Date().addingTimeInterval(Self.oneYearInSeconds)

        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: settings.name,
            .value: settings.value,
            .domain: domain,
            .path: "/",
            .expires: expiration,
            .sameSitePolicy: HTTPCookieStringPolicy.sameSiteLax,
        ]

        // Set secure flag for HTTPS URLs
        if url.scheme?.lowercased() == "https" {
            properties[.secure] = true
        }

        return HTTPCookie(properties: properties)
    }

    /// Extracts the cookie domain from a host string.
    ///
    /// For hosts with multiple subdomains, returns the top-level domain with a
    /// leading dot to allow cookie sharing across subdomains.
    /// For simple hosts, returns the host as-is.
    ///
    /// - Parameter host: The host string from a URL.
    /// - Returns: The domain string suitable for cookie use.
    public func extractCookieDomain(from host: String) -> String {
        let components = host.split(separator: ".").map(String.init)

        // For localhost or single-component hosts, return as-is
        guard components.count >= 2 else { return host }

        // Check if it looks like an IP address
        if components.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return host
        }

        // For regular domains, prefix with dot to apply to subdomains
        // e.g., "app.example.com" -> ".example.com"
        if components.count > 2 {
            let topLevel = components.suffix(2).joined(separator: ".")
            return ".\(topLevel)"
        }

        // For two-component domains, prefix with dot
        // e.g., "example.com" -> ".example.com"
        return ".\(host)"
    }

    // MARK: - Cookie Store Integration

    /// Sets the platform cookie in a WKHTTPCookieStore.
    ///
    /// - Parameters:
    ///   - url: The URL to set the cookie for.
    ///   - cookieStore: The WKHTTPCookieStore to add the cookie to.
    @MainActor
    public func setCookie(for url: URL, in cookieStore: WKHTTPCookieStore) async {
        guard let cookie = makeCookie(for: url) else { return }
        await cookieStore.setCookie(cookie)
    }

    /// Sets the platform cookie in the website data store of a WKWebView configuration.
    ///
    /// - Parameters:
    ///   - url: The URL to set the cookie for.
    ///   - configuration: The WKWebViewConfiguration whose data store should receive the cookie.
    @MainActor
    public func setCookie(for url: URL, in configuration: WKWebViewConfiguration) async {
        await setCookie(for: url, in: configuration.websiteDataStore.httpCookieStore)
    }

    // MARK: - Script Injection

    /// Creates a user script that sets the platform cookie via JavaScript.
    ///
    /// This is an alternative to using the cookie store API and can be useful
    /// for ensuring the cookie is set immediately when the page loads.
    ///
    /// - Parameters:
    ///   - url: The URL the script will run on. Used to derive the cookie domain.
    ///   - expirationDate: Optional custom expiration date. Defaults to 1 year from now.
    /// - Returns: A WKUserScript that sets the cookie, or nil if settings are disabled.
    @MainActor
    public func makeCookieScript(
        for url: URL,
        expirationDate: Date? = nil
    ) -> WKUserScript? {
        guard settings.enabled else { return nil }
        guard let host = url.host else { return nil }

        let domain = extractCookieDomain(from: host)
        let expiration = expirationDate ?? Date().addingTimeInterval(Self.oneYearInSeconds)
        let expirationString = Self.cookieExpirationDateFormatter.string(from: expiration)

        let isSecure = url.scheme?.lowercased() == "https"
        let secureFlag = isSecure ? "; Secure" : ""

        let script = """
        document.cookie = "\(settings.name)=\(settings.value); \
        path=/; \
        domain=\(domain); \
        expires=\(expirationString); \
        SameSite=Lax\(secureFlag)";
        """

        return WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    /// Creates a user script that sets the document referrer.
    ///
    /// This script injects a custom referrer value, which can be useful for
    /// analytics tracking or origin identification.
    ///
    /// - Parameter referrer: The referrer URL string to inject.
    /// - Returns: A WKUserScript that sets the referrer.
    @MainActor
    public func makeReferrerScript(referrer: String) -> WKUserScript {
        // Use Object.defineProperty to override the read-only document.referrer
        let script = """
        (function() {
            Object.defineProperty(document, 'referrer', {
                get: function() { return '\(Self.escapeJavaScriptString(referrer))'; }
            });
        })();
        """

        return WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    // MARK: - Helper Methods

    /// Date formatter for cookie expiration dates.
    ///
    /// Uses the HTTP date format: "EEE, dd MMM yyyy HH:mm:ss zzz"
    private static let cookieExpirationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Escapes a string for safe inclusion in JavaScript.
    ///
    /// - Parameter string: The string to escape.
    /// - Returns: The escaped string safe for JavaScript inclusion.
    private static func escapeJavaScriptString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - Domain Matching

extension PlatformCookieManager {
    /// Checks if a URL matches the allowed domains for the cookie.
    ///
    /// This is useful for determining whether to set the platform cookie
    /// for a given navigation request.
    ///
    /// - Parameters:
    ///   - url: The URL to check.
    ///   - allowedOrigins: Array of allowed origin patterns (supports wildcards).
    /// - Returns: `true` if the URL matches any allowed origin.
    public func shouldSetCookie(for url: URL, allowedOrigins: [String]) -> Bool {
        guard settings.enabled else { return false }
        guard let host = url.host?.lowercased() else { return false }

        for pattern in allowedOrigins {
            let lowercasePattern = pattern.lowercased()

            // Exact match
            if host == lowercasePattern {
                return true
            }

            // Wildcard match (e.g., "*.example.com")
            if lowercasePattern.hasPrefix("*.") {
                let suffix = String(lowercasePattern.dropFirst(2))
                if host == suffix || host.hasSuffix(".\(suffix)") {
                    return true
                }
            }
        }

        return false
    }
}
