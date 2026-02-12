import Foundation

/// Configuration for URL handling behavior.
///
/// Controls how different URLs are handled within the app:
/// - **Allowed**: Load inside the WebView with full bridge access
/// - **Auth**: Load inside the WebView with a "Done" toolbar (for OAuth flows)
/// - **External**: Open in Safari or the system browser
public struct OriginsConfiguration: Codable, Sendable, Equatable {
    /// Origins that load within the WebView with full bridge access.
    ///
    /// Supports wildcard patterns:
    /// - `example.com` - Exact domain match
    /// - `*.example.com` - Any subdomain
    /// - `example.com/path/*` - Path prefix match
    public let allowed: [String]

    /// Origins that show the "Done" toolbar.
    ///
    /// Useful for OAuth flows that navigate to third-party domains.
    /// Defaults to an empty array.
    public let auth: [String]

    /// Origins that open in Safari or the system browser.
    ///
    /// URLs matching these patterns bypass the WebView entirely.
    /// Defaults to an empty array.
    public let external: [String]

    /// Creates a new origins configuration.
    ///
    /// - Parameters:
    ///   - allowed: Origins that load within the WebView.
    ///   - auth: Origins that show the "Done" toolbar.
    ///   - external: Origins that open externally.
    public init(
        allowed: [String],
        auth: [String] = [],
        external: [String] = []
    ) {
        self.allowed = allowed
        self.auth = auth
        self.external = external
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case allowed
        case auth
        case external
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.allowed = try container.decode([String].self, forKey: .allowed)
        self.auth = try container.decodeIfPresent([String].self, forKey: .auth) ?? []
        self.external = try container.decodeIfPresent([String].self, forKey: .external) ?? []
    }
}
