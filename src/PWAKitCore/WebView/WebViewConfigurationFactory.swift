import Foundation
import WebKit

// MARK: - WebViewConfigurationFactory

/// Factory for creating configured WKWebViewConfiguration instances.
///
/// This factory creates WKWebViewConfiguration objects with appropriate settings
/// for PWA hosting, including:
/// - App-bound domains for enhanced security
/// - Inline media playback support
/// - JavaScript window opening capabilities
/// - Standalone display mode preferences
/// - Bridge message handler registration
/// - Web inspector in DEBUG builds
///
/// ## Example
///
/// ```swift
/// let webViewConfig = WebViewConfiguration(
///     startURL: URL(string: "https://app.example.com/")!,
///     allowedOrigins: ["app.example.com"]
/// )
///
/// let wkConfig = WebViewConfigurationFactory.makeConfiguration(
///     webViewConfiguration: webViewConfig,
///     messageHandler: myHandler
/// )
/// let webView = WKWebView(frame: .zero, configuration: wkConfig)
/// ```
public enum WebViewConfigurationFactory {
    /// The name of the message handler for the JavaScript bridge.
    ///
    /// JavaScript calls `window.webkit.messageHandlers.pwakit.postMessage()`
    /// to communicate with Swift.
    public static let bridgeHandlerName = "pwakit"

    /// Creates a WKWebViewConfiguration with PWA-appropriate settings.
    ///
    /// - Parameters:
    ///   - webViewConfiguration: The PWAKit WebView configuration.
    ///   - messageHandler: The script message handler for the JavaScript bridge.
    /// - Returns: A configured WKWebViewConfiguration ready for use.
    @MainActor
    public static func makeConfiguration(
        webViewConfiguration: WebViewConfiguration,
        messageHandler: WKScriptMessageHandler
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()

        // Configure content controller with message handler
        let contentController = WKUserContentController()
        contentController.add(messageHandler, name: bridgeHandlerName)
        configuration.userContentController = contentController

        // Configure preferences
        configurePreferences(configuration)

        // Configure web page preferences for standalone mode
        configureWebPagePreferences(configuration, displayMode: webViewConfiguration.displayMode)

        // Configure media playback
        configureMediaPlayback(configuration)

        // Enable web inspector in DEBUG builds
        configureWebInspector(configuration)

        // Set app-bound domains for enhanced security
        configuration.limitsNavigationsToAppBoundDomains = true

        return configuration
    }

    /// Creates a WKWebViewConfiguration without a message handler.
    ///
    /// Useful for testing or when the bridge is configured separately.
    ///
    /// - Parameter webViewConfiguration: The PWAKit WebView configuration.
    /// - Returns: A configured WKWebViewConfiguration.
    @MainActor
    public static func makeConfiguration(
        webViewConfiguration: WebViewConfiguration
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()

        // Configure preferences
        configurePreferences(configuration)

        // Configure web page preferences for standalone mode
        configureWebPagePreferences(configuration, displayMode: webViewConfiguration.displayMode)

        // Configure media playback
        configureMediaPlayback(configuration)

        // Enable web inspector in DEBUG builds
        configureWebInspector(configuration)

        // Set app-bound domains for enhanced security
        configuration.limitsNavigationsToAppBoundDomains = true

        return configuration
    }

    // MARK: - Private Configuration Methods

    /// Configures general preferences for the WKWebViewConfiguration.
    @MainActor
    private static func configurePreferences(_ configuration: WKWebViewConfiguration) {
        let preferences = WKPreferences()

        // Allow JavaScript to open new windows (for target="_blank" links)
        preferences.javaScriptCanOpenWindowsAutomatically = true

        // Enable standalone display mode for CSS @media (display-mode: standalone) queries
        // This allows web content to detect it's running in a PWA shell
        preferences.setValue(true, forKey: "standalone")

        // Enable text interaction (selection, context menus)
        if #available(iOS 15.0, *) {
            preferences.isTextInteractionEnabled = true
        }

        // Fraud protection for enhanced security
        preferences.isFraudulentWebsiteWarningEnabled = true

        configuration.preferences = preferences
    }

    /// Configures web page preferences based on display mode.
    @MainActor
    private static func configureWebPagePreferences(
        _ configuration: WKWebViewConfiguration,
        displayMode: DisplayMode
    ) {
        let webPagePreferences = WKWebpagePreferences()

        // Enable JavaScript for all pages
        webPagePreferences.allowsContentJavaScript = true

        // Set content mode based on display mode
        switch displayMode {
        case .standalone,
             .fullscreen:
            // Mobile content mode for app-like experience
            webPagePreferences.preferredContentMode = .mobile
        }

        configuration.defaultWebpagePreferences = webPagePreferences
    }

    /// Configures media playback settings.
    @MainActor
    private static func configureMediaPlayback(_ configuration: WKWebViewConfiguration) {
        // Allow inline media playback (videos don't go fullscreen automatically)
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true

        // Allow media playback to begin without user interaction
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Allow AirPlay for media streaming
        configuration.allowsAirPlayForMediaPlayback = true
    }

    /// Configures web inspector for DEBUG builds.
    @MainActor
    private static func configureWebInspector(_ configuration: WKWebViewConfiguration) {
        #if DEBUG
            // Enable Web Inspector in debug builds
            // This allows Safari Developer Tools to inspect the web content
            if #available(iOS 16.4, *) {
                configuration.preferences.isElementFullscreenEnabled = true
            }
        #endif
    }
}

// MARK: - Message Handler Registration

extension WebViewConfigurationFactory {
    /// Adds a script message handler to an existing WKWebViewConfiguration.
    ///
    /// Use this when you need to add the bridge handler after initial configuration.
    ///
    /// - Parameters:
    ///   - configuration: The configuration to modify.
    ///   - messageHandler: The script message handler to add.
    @MainActor
    public static func addMessageHandler(
        to configuration: WKWebViewConfiguration,
        messageHandler: WKScriptMessageHandler
    ) {
        configuration.userContentController.add(messageHandler, name: bridgeHandlerName)
    }

    /// Removes the bridge message handler from a WKWebViewConfiguration.
    ///
    /// Call this before deallocating the WKWebView to avoid retain cycles.
    ///
    /// - Parameter configuration: The configuration to modify.
    @MainActor
    public static func removeMessageHandler(from configuration: WKWebViewConfiguration) {
        configuration.userContentController.removeScriptMessageHandler(forName: bridgeHandlerName)
    }
}
