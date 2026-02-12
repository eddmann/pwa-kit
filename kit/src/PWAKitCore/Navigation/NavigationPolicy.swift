import Foundation

// MARK: - NavigationPolicy

/// Navigation policy for URL handling decisions.
///
/// Determines how a URL navigation should be handled by the WebView:
/// - `allow`: Load within the WebView with full bridge access
/// - `allowWithToolbar`: Load within the WebView with a "Done" toolbar (for OAuth flows)
/// - `external`: Open in SFSafariViewController
/// - `system`: Let the system handle it (tel:, mailto:, etc.)
/// - `cancel`: Block the navigation entirely
public enum NavigationPolicy: String, Sendable, Equatable {
    /// Load within the WebView with full bridge access.
    case allow

    /// Load within the WebView with a "Done" toolbar.
    /// Useful for OAuth flows that navigate to third-party domains.
    case allowWithToolbar

    /// Open in SFSafariViewController or Safari.
    case external

    /// Let the system handle the URL (tel:, mailto:, maps:, etc.).
    case system

    /// Block the navigation entirely.
    case cancel
}

// MARK: - NavigationPolicyResolver

/// Resolves navigation policies based on URL and origin configuration.
///
/// The resolver checks URLs against configured origin patterns to determine
/// the appropriate navigation policy.
public struct NavigationPolicyResolver: Sendable {
    /// Origins that are allowed within the WebView.
    private let allowedOrigins: [String]

    /// Origins that show the "Done" toolbar (auth flows).
    private let authOrigins: [String]

    /// Origins that should open externally.
    private let externalOrigins: [String]

    /// Creates a new navigation policy resolver.
    ///
    /// - Parameters:
    ///   - allowedOrigins: Origins that load within the WebView.
    ///   - authOrigins: Origins that show the "Done" toolbar.
    ///   - externalOrigins: Origins that open externally.
    public init(
        allowedOrigins: [String],
        authOrigins: [String] = [],
        externalOrigins: [String] = []
    ) {
        self.allowedOrigins = allowedOrigins
        self.authOrigins = authOrigins
        self.externalOrigins = externalOrigins
    }

    /// Creates a resolver from an origins configuration.
    ///
    /// - Parameter origins: The origins configuration.
    public init(origins: OriginsConfiguration) {
        self.allowedOrigins = origins.allowed
        self.authOrigins = origins.auth
        self.externalOrigins = origins.external
    }

    /// Resolves the navigation policy for a given URL.
    ///
    /// The resolution order is:
    /// 1. System URL schemes (tel:, mailto:, etc.) → `.system`
    /// 2. Non-HTTP(S) URLs with app-specific schemes → `.external`
    /// 3. External origins → `.external`
    /// 4. Auth origins → `.allowWithToolbar`
    /// 5. Allowed origins → `.allow`
    /// 6. All other URLs → `.external`
    ///
    /// - Parameter url: The URL to resolve a policy for.
    /// - Returns: The appropriate navigation policy.
    public func resolve(for url: URL) -> NavigationPolicy {
        // Handle system URL schemes
        if isSystemScheme(url) {
            return .system
        }

        // Only allow http and https schemes in WebView
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else
        {
            return .external
        }

        // Check external origins first (takes precedence)
        if matchesAnyOrigin(url, origins: externalOrigins) {
            return .external
        }

        // Check auth origins (shows toolbar)
        if matchesAnyOrigin(url, origins: authOrigins) {
            return .allowWithToolbar
        }

        // Check allowed origins
        if matchesAnyOrigin(url, origins: allowedOrigins) {
            return .allow
        }

        // Default: open externally
        return .external
    }

    // MARK: - Private Methods

    /// Checks if the URL uses a system scheme that should be handled by the OS.
    private func isSystemScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        let systemSchemes: Set<String> = [
            "tel",
            "mailto",
            "sms",
            "facetime",
            "facetime-audio",
            "maps",
            "itms-apps",
            "itms-appss",
        ]

        return systemSchemes.contains(scheme)
    }

    /// Checks if a URL matches any of the given origin patterns.
    private func matchesAnyOrigin(_ url: URL, origins: [String]) -> Bool {
        origins.contains { matchesOrigin(url, pattern: $0) }
    }

    /// Checks if a URL matches a specific origin pattern.
    ///
    /// Supports patterns:
    /// - `example.com` - Exact domain match
    /// - `*.example.com` - Wildcard subdomain match
    /// - `example.com/path/*` - Path prefix match
    private func matchesOrigin(_ url: URL, pattern: String) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        // Parse the pattern
        let patternLowercased = pattern.lowercased()

        // Check for path patterns (e.g., "example.com/path/*")
        if let slashIndex = patternLowercased.firstIndex(of: "/") {
            let domainPattern = String(patternLowercased[..<slashIndex])
            let pathPattern = String(patternLowercased[slashIndex...])

            // Check domain first
            guard matchesDomain(host, pattern: domainPattern) else {
                return false
            }

            // Then check path
            return matchesPath(url.path, pattern: pathPattern)
        }

        // Domain-only pattern
        return matchesDomain(host, pattern: patternLowercased)
    }

    /// Matches a hostname against a domain pattern.
    ///
    /// - Parameters:
    ///   - host: The hostname to check.
    ///   - pattern: The domain pattern (may include wildcard `*`).
    /// - Returns: Whether the host matches the pattern.
    private func matchesDomain(_ host: String, pattern: String) -> Bool {
        // Wildcard subdomain pattern: *.example.com
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            // Must match exactly or be a subdomain
            return host == suffix || host.hasSuffix(".\(suffix)")
        }

        // Exact match
        return host == pattern
    }

    /// Matches a URL path against a path pattern.
    ///
    /// - Parameters:
    ///   - path: The URL path to check.
    ///   - pattern: The path pattern (may include trailing `*`).
    /// - Returns: Whether the path matches the pattern.
    private func matchesPath(_ path: String, pattern: String) -> Bool {
        let normalizedPath = path.isEmpty ? "/" : path

        // Wildcard path pattern: /path/*
        if pattern.hasSuffix("/*") {
            let prefix = String(pattern.dropLast(1)) // Keep the trailing /
            return normalizedPath.hasPrefix(prefix) || normalizedPath == String(pattern.dropLast(2))
        }

        // Exact match
        return normalizedPath == pattern
    }
}
