import Foundation
@testable import PWAKitApp
import Testing

// MARK: - WebViewConfigurationTests

@Suite("WebViewConfiguration Tests")
struct WebViewConfigurationTests {
    // MARK: - Basic Initialization

    @Test("Initializes with required parameters")
    func initializesWithRequiredParameters() throws {
        let config = try WebViewConfiguration(
            startURL: #require(URL(string: "https://example.com/")),
            allowedOrigins: ["example.com"]
        )

        #expect(config.startURL.absoluteString == "https://example.com/")
        #expect(config.allowedOrigins == ["example.com"])
        #expect(config.authOrigins == [])
        #expect(config.platformCookieSettings == .default)
        #expect(config.displayMode == .standalone)
        #expect(config.pullToRefresh == false)
        #expect(config.statusBarStyle == .adaptive)
    }

    @Test("Initializes with all parameters")
    func initializesWithAllParameters() throws {
        let cookieSettings = PlatformCookieSettings(
            enabled: true,
            name: "custom-cookie",
            value: "custom-value"
        )

        let config = try WebViewConfiguration(
            startURL: #require(URL(string: "https://app.example.com/start")),
            allowedOrigins: ["app.example.com", "*.example.com"],
            authOrigins: ["accounts.google.com", "auth0.com"],
            platformCookieSettings: cookieSettings,
            displayMode: .fullscreen,
            pullToRefresh: false,
            statusBarStyle: .dark
        )

        #expect(config.startURL.absoluteString == "https://app.example.com/start")
        #expect(config.allowedOrigins == ["app.example.com", "*.example.com"])
        #expect(config.authOrigins == ["accounts.google.com", "auth0.com"])
        #expect(config.platformCookieSettings == cookieSettings)
        #expect(config.displayMode == .fullscreen)
        #expect(config.pullToRefresh == false)
        #expect(config.statusBarStyle == .dark)
    }

    // MARK: - Factory Method from PWAConfiguration

    @Test("Creates from PWAConfiguration")
    func createsFromPWAConfiguration() throws {
        let pwaConfig = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://test.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["test.example.com", "*.example.com"],
                auth: ["auth.example.com"],
                external: ["external.example.com"]
            ),
            features: .default,
            appearance: AppearanceConfiguration(
                displayMode: .fullscreen,
                pullToRefresh: false,
                statusBarStyle: .light
            ),
            notifications: .default
        )

        let webViewConfig = try WebViewConfiguration.from(pwaConfig: pwaConfig)

        #expect(webViewConfig.startURL.absoluteString == "https://test.example.com/")
        #expect(webViewConfig.allowedOrigins == ["test.example.com", "*.example.com"])
        #expect(webViewConfig.authOrigins == ["auth.example.com"])
        #expect(webViewConfig.displayMode == .fullscreen)
        #expect(webViewConfig.pullToRefresh == false)
        #expect(webViewConfig.statusBarStyle == .light)
        #expect(webViewConfig.platformCookieSettings == .default)
    }

    @Test("Throws error for invalid start URL")
    func throwsErrorForInvalidStartURL() throws {
        let pwaConfig = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Invalid App",
                bundleId: "com.invalid.app",
                startUrl: ""
            ),
            origins: OriginsConfiguration(
                allowed: ["example.com"]
            )
        )

        #expect(throws: WebViewConfigurationError.self) {
            _ = try WebViewConfiguration.from(pwaConfig: pwaConfig)
        }
    }

    // MARK: - Equatable

    @Test("Equals when all properties match")
    func equalsWhenAllPropertiesMatch() throws {
        let config1 = try WebViewConfiguration(
            startURL: #require(URL(string: "https://example.com/")),
            allowedOrigins: ["example.com"],
            authOrigins: ["auth.com"],
            platformCookieSettings: .default,
            displayMode: .standalone,
            pullToRefresh: true,
            statusBarStyle: .adaptive
        )

        let config2 = try WebViewConfiguration(
            startURL: #require(URL(string: "https://example.com/")),
            allowedOrigins: ["example.com"],
            authOrigins: ["auth.com"],
            platformCookieSettings: .default,
            displayMode: .standalone,
            pullToRefresh: true,
            statusBarStyle: .adaptive
        )

        #expect(config1 == config2)
    }

    @Test("Not equal when properties differ")
    func notEqualWhenPropertiesDiffer() throws {
        let config1 = try WebViewConfiguration(
            startURL: #require(URL(string: "https://example1.com/")),
            allowedOrigins: ["example1.com"]
        )

        let config2 = try WebViewConfiguration(
            startURL: #require(URL(string: "https://example2.com/")),
            allowedOrigins: ["example2.com"]
        )

        #expect(config1 != config2)
    }
}

// MARK: - PlatformCookieSettingsTests

@Suite("PlatformCookieSettings Tests")
struct PlatformCookieSettingsTests {
    // MARK: - Default Values

    @Test("Default settings have expected values")
    func defaultSettingsHaveExpectedValues() {
        let settings = PlatformCookieSettings.default

        #expect(settings.enabled == true)
        #expect(settings.name == "app-platform")
        #expect(settings.value == "ios")
    }

    @Test("Disabled settings have cookie disabled")
    func disabledSettingsHaveCookieDisabled() {
        let settings = PlatformCookieSettings.disabled

        #expect(settings.enabled == false)
    }

    // MARK: - Custom Initialization

    @Test("Initializes with custom values")
    func initializesWithCustomValues() {
        let settings = PlatformCookieSettings(
            enabled: true,
            name: "custom-name",
            value: "custom-value"
        )

        #expect(settings.enabled == true)
        #expect(settings.name == "custom-name")
        #expect(settings.value == "custom-value")
    }

    @Test("Initializes with defaults when no parameters")
    func initializesWithDefaults() {
        let settings = PlatformCookieSettings()

        #expect(settings.enabled == true)
        #expect(settings.name == "app-platform")
        #expect(settings.value == "ios")
    }

    // MARK: - JSON Encoding/Decoding

    @Test("Decodes from complete JSON")
    func decodesFromCompleteJSON() throws {
        let json = """
        {
            "enabled": false,
            "name": "my-platform",
            "value": "ios-native"
        }
        """

        let data = Data(json.utf8)
        let settings = try JSONDecoder().decode(PlatformCookieSettings.self, from: data)

        #expect(settings.enabled == false)
        #expect(settings.name == "my-platform")
        #expect(settings.value == "ios-native")
    }

    @Test("Applies defaults for missing JSON keys")
    func appliesDefaultsForMissingKeys() throws {
        let json = "{}"

        let data = Data(json.utf8)
        let settings = try JSONDecoder().decode(PlatformCookieSettings.self, from: data)

        #expect(settings.enabled == true)
        #expect(settings.name == "app-platform")
        #expect(settings.value == "ios")
    }

    @Test("Applies defaults for partial JSON")
    func appliesDefaultsForPartialJSON() throws {
        let json = """
        {
            "enabled": false
        }
        """

        let data = Data(json.utf8)
        let settings = try JSONDecoder().decode(PlatformCookieSettings.self, from: data)

        #expect(settings.enabled == false)
        #expect(settings.name == "app-platform")
        #expect(settings.value == "ios")
    }

    @Test("Encodes to JSON")
    func encodesToJSON() throws {
        let settings = PlatformCookieSettings(
            enabled: true,
            name: "test-cookie",
            value: "test-value"
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PlatformCookieSettings.self, from: data)

        #expect(decoded == settings)
    }

    // MARK: - Equatable

    @Test("Equals when all properties match")
    func equalsWhenAllPropertiesMatch() {
        let settings1 = PlatformCookieSettings(enabled: true, name: "test", value: "value")
        let settings2 = PlatformCookieSettings(enabled: true, name: "test", value: "value")

        #expect(settings1 == settings2)
    }

    @Test("Not equal when properties differ")
    func notEqualWhenPropertiesDiffer() {
        let settings1 = PlatformCookieSettings(enabled: true, name: "test1", value: "value1")
        let settings2 = PlatformCookieSettings(enabled: false, name: "test2", value: "value2")

        #expect(settings1 != settings2)
    }
}

// MARK: - WebViewConfigurationErrorTests

@Suite("WebViewConfigurationError Tests")
struct WebViewConfigurationErrorTests {
    @Test("Invalid URL error has descriptive message")
    func invalidURLErrorHasDescriptiveMessage() {
        let error = WebViewConfigurationError.invalidStartURL("bad url")

        #expect(error.errorDescription == "Invalid start URL: 'bad url'")
    }

    @Test("Error conforms to LocalizedError")
    func errorConformsToLocalizedError() {
        let error: LocalizedError = WebViewConfigurationError.invalidStartURL("test")

        #expect(error.errorDescription != nil)
    }
}
