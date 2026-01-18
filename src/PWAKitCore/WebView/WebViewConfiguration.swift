import Foundation

// MARK: - PlatformCookieSettings

/// Platform-specific cookie settings for the WebView.
///
/// Controls how the PWA is identified to the web content via cookies.
public struct PlatformCookieSettings: Codable, Sendable, Equatable {
    /// Whether to set the platform identification cookie.
    public let enabled: Bool

    /// The cookie name to use for platform identification.
    ///
    /// Defaults to `"app-platform"`.
    public let name: String

    /// The cookie value to set.
    ///
    /// Defaults to `"ios"`.
    public let value: String

    /// Creates new platform cookie settings.
    ///
    /// - Parameters:
    ///   - enabled: Whether to set the cookie. Defaults to `true`.
    ///   - name: Cookie name. Defaults to `"app-platform"`.
    ///   - value: Cookie value. Defaults to `"ios"`.
    public init(
        enabled: Bool = true,
        name: String = "app-platform",
        value: String = "ios"
    ) {
        self.enabled = enabled
        self.name = name
        self.value = value
    }

    /// Default platform cookie settings with cookie enabled.
    public static let `default` = PlatformCookieSettings()

    /// Platform cookie settings with cookie disabled.
    public static let disabled = PlatformCookieSettings(enabled: false)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case enabled
        case name
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "app-platform"
        self.value = try container.decodeIfPresent(String.self, forKey: .value) ?? "ios"
    }
}

// MARK: - WebViewConfiguration

/// Configuration for the WKWebView.
///
/// Encapsulates all settings needed to configure and initialize the WebView,
/// including the start URL, allowed origins, appearance settings, and
/// platform-specific behaviors.
///
/// ## Example
///
/// ```swift
/// let config = WebViewConfiguration(
///     startURL: URL(string: "https://app.example.com/")!,
///     allowedOrigins: ["app.example.com", "*.example.com"],
///     authOrigins: ["accounts.google.com"],
///     displayMode: .standalone,
///     pullToRefresh: true
/// )
/// ```
public struct WebViewConfiguration: Sendable, Equatable {
    /// The initial URL to load when the WebView is created.
    public let startURL: URL

    /// Origins that are allowed to load within the WebView.
    ///
    /// URLs matching these patterns have full access to the JavaScript bridge.
    /// Supports wildcard patterns like `*.example.com`.
    public let allowedOrigins: [String]

    /// Origins that display the "Done" toolbar for dismissal.
    ///
    /// Useful for OAuth flows where the user navigates to a third-party
    /// authentication provider and needs a way to return to the app.
    public let authOrigins: [String]

    /// Platform cookie settings for identifying the app to web content.
    public let platformCookieSettings: PlatformCookieSettings

    /// Display mode for the WebView content.
    ///
    /// Controls whether browser UI elements are visible and how the
    /// content fills the screen.
    public let displayMode: DisplayMode

    /// Whether pull-to-refresh gesture is enabled.
    ///
    /// When enabled, pulling down on the WebView will trigger a page reload.
    /// This is disabled on macCatalyst.
    public let pullToRefresh: Bool

    /// Whether to adapt the system UI style based on web content.
    ///
    /// When enabled, the app observes the WebView's background color
    /// and automatically sets the system appearance (light/dark) to match.
    public let adaptiveUIStyle: Bool

    /// Creates a new WebView configuration.
    ///
    /// - Parameters:
    ///   - startURL: The initial URL to load.
    ///   - allowedOrigins: Origins allowed in the WebView.
    ///   - authOrigins: Origins that show the "Done" toolbar. Defaults to empty.
    ///   - platformCookieSettings: Cookie settings. Defaults to `.default`.
    ///   - displayMode: Display mode. Defaults to `.standalone`.
    ///   - pullToRefresh: Enable pull-to-refresh. Defaults to `true`.
    ///   - adaptiveUIStyle: Enable adaptive UI style. Defaults to `true`.
    public init(
        startURL: URL,
        allowedOrigins: [String],
        authOrigins: [String] = [],
        platformCookieSettings: PlatformCookieSettings = .default,
        displayMode: DisplayMode = .standalone,
        pullToRefresh: Bool = true,
        adaptiveUIStyle: Bool = true
    ) {
        self.startURL = startURL
        self.allowedOrigins = allowedOrigins
        self.authOrigins = authOrigins
        self.platformCookieSettings = platformCookieSettings
        self.displayMode = displayMode
        self.pullToRefresh = pullToRefresh
        self.adaptiveUIStyle = adaptiveUIStyle
    }
}

// MARK: - Factory Methods

extension WebViewConfiguration {
    /// Creates a WebViewConfiguration from a PWAConfiguration.
    ///
    /// This is the primary way to create a WebViewConfiguration, using
    /// the centralized app configuration as the source of truth.
    ///
    /// - Parameter pwaConfig: The root PWA configuration.
    /// - Returns: A WebViewConfiguration derived from the PWA configuration.
    /// - Throws: An error if the start URL is invalid.
    public static func from(pwaConfig: PWAConfiguration) throws -> WebViewConfiguration {
        guard let startURL = URL(string: pwaConfig.app.startUrl) else {
            throw WebViewConfigurationError.invalidStartURL(pwaConfig.app.startUrl)
        }

        return WebViewConfiguration(
            startURL: startURL,
            allowedOrigins: pwaConfig.origins.allowed,
            authOrigins: pwaConfig.origins.auth,
            platformCookieSettings: .default,
            displayMode: pwaConfig.appearance.displayMode,
            pullToRefresh: pwaConfig.appearance.pullToRefresh,
            adaptiveUIStyle: pwaConfig.appearance.adaptiveStyle
        )
    }
}

// MARK: - WebViewConfigurationError

/// Errors that can occur when creating a WebViewConfiguration.
public enum WebViewConfigurationError: Error, LocalizedError, Sendable {
    /// The start URL string could not be parsed as a valid URL.
    case invalidStartURL(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidStartURL(urlString):
            "Invalid start URL: '\(urlString)'"
        }
    }
}
