import Foundation
import Testing
import WebKit

@testable import PWAKitApp

// MARK: - MockScriptMessageHandler

/// Mock message handler for testing.
@MainActor
final class MockScriptMessageHandler: NSObject, WKScriptMessageHandler {
    var receivedMessages: [WKScriptMessage] = []

    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        receivedMessages.append(message)
    }
}

// MARK: - WebViewConfigurationFactoryTests

@Suite("WebViewConfigurationFactory Tests")
@MainActor
struct WebViewConfigurationFactoryTests {
    // MARK: - Test Fixtures

    let defaultWebViewConfig = WebViewConfiguration(
        startURL: URL(string: "https://app.example.com/")!,
        allowedOrigins: ["app.example.com"]
    )

    // MARK: - Basic Configuration Tests

    @Test("Creates configuration with message handler")
    func createsConfigurationWithMessageHandler() {
        let handler = MockScriptMessageHandler()

        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig,
            messageHandler: handler
        )

        #expect(config.userContentController.value(forKey: "userScripts") != nil)
    }

    @Test("Creates configuration without message handler")
    func createsConfigurationWithoutMessageHandler() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        // Configuration should still be valid
        #expect(config.preferences != nil)
    }

    @Test("Bridge handler name is pwakit")
    func bridgeHandlerNameIsPwakit() {
        #expect(WebViewConfigurationFactory.bridgeHandlerName == "pwakit")
    }

    // MARK: - App-Bound Domains Tests

    @Test("Limits navigations to app-bound domains")
    func limitsNavigationsToAppBoundDomains() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.limitsNavigationsToAppBoundDomains == true)
    }

    // MARK: - Media Playback Tests

    @Test("Allows inline media playback")
    func allowsInlineMediaPlayback() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.allowsInlineMediaPlayback == true)
    }

    @Test("Allows picture-in-picture playback")
    func allowsPictureInPicturePlayback() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.allowsPictureInPictureMediaPlayback == true)
    }

    @Test("Allows media playback without user action")
    func allowsMediaPlaybackWithoutUserAction() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.mediaTypesRequiringUserActionForPlayback == [])
    }

    @Test("Allows AirPlay for media playback")
    func allowsAirPlayForMediaPlayback() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.allowsAirPlayForMediaPlayback == true)
    }

    // MARK: - Preferences Tests

    @Test("JavaScript can open windows automatically")
    func javaScriptCanOpenWindowsAutomatically() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.preferences.javaScriptCanOpenWindowsAutomatically == true)
    }

    @Test("Text interaction is enabled")
    func textInteractionIsEnabled() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )
        #expect(config.preferences.isTextInteractionEnabled == true)
    }

    @Test("Fraudulent website warning is enabled")
    func fraudulentWebsiteWarningIsEnabled() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.preferences.isFraudulentWebsiteWarningEnabled == true)
    }

    // MARK: - Web Page Preferences Tests

    @Test("JavaScript is allowed for content")
    func javaScriptIsAllowedForContent() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )

        #expect(config.defaultWebpagePreferences.allowsContentJavaScript == true)
    }

    @Test("Standalone mode uses mobile content mode")
    func standaloneModeUsesMobileContentMode() {
        let standaloneConfig = WebViewConfiguration(
            startURL: URL(string: "https://app.example.com/")!,
            allowedOrigins: ["app.example.com"],
            displayMode: .standalone
        )

        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: standaloneConfig
        )

        #expect(config.defaultWebpagePreferences.preferredContentMode == .mobile)
    }

    @Test("Fullscreen mode uses mobile content mode")
    func fullscreenModeUsesMobileContentMode() {
        let fullscreenConfig = WebViewConfiguration(
            startURL: URL(string: "https://app.example.com/")!,
            allowedOrigins: ["app.example.com"],
            displayMode: .fullscreen
        )

        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: fullscreenConfig
        )

        #expect(config.defaultWebpagePreferences.preferredContentMode == .mobile)
    }

    // MARK: - Message Handler Management Tests

    @Test("Can add message handler to existing configuration")
    func canAddMessageHandlerToExistingConfiguration() {
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig
        )
        let handler = MockScriptMessageHandler()

        WebViewConfigurationFactory.addMessageHandler(to: config, messageHandler: handler)

        // Configuration should be modified (no crash indicates success)
        #expect(config.userContentController.value(forKey: "userScripts") != nil)
    }

    @Test("Can remove message handler from configuration")
    func canRemoveMessageHandlerFromConfiguration() {
        let handler = MockScriptMessageHandler()
        let config = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig,
            messageHandler: handler
        )

        // Should not crash when removing
        WebViewConfigurationFactory.removeMessageHandler(from: config)
    }

    // MARK: - Configuration Consistency Tests

    @Test("Multiple configurations are independent")
    func multipleConfigurationsAreIndependent() {
        let handler1 = MockScriptMessageHandler()
        let handler2 = MockScriptMessageHandler()

        let config1 = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig,
            messageHandler: handler1
        )

        let config2 = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: defaultWebViewConfig,
            messageHandler: handler2
        )

        // Configurations should be distinct objects
        #expect(config1 !== config2)
        #expect(config1.userContentController !== config2.userContentController)
    }
}
