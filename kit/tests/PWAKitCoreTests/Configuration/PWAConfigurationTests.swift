import Foundation
@testable import PWAKitApp
import Testing

@Suite("PWAConfiguration Tests")
struct PWAConfigurationTests {
    // MARK: - Full Configuration Decoding

    @Test("Decodes complete configuration from JSON")
    func decodesCompleteConfiguration() throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "My PWA",
            "bundleId": "com.example.mypwa",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com", "*.example.com"],
            "auth": ["accounts.google.com", "auth0.com"],
            "external": ["example.com/external/*"]
          },
          "features": {
            "notifications": true,
            "haptics": true,
            "biometrics": true,
            "secureStorage": true,
            "healthkit": false,
            "iap": false,
            "share": true,
            "print": true,
            "clipboard": true
          },
          "appearance": {
            "displayMode": "standalone",
            "pullToRefresh": true,
            "adaptiveStyle": true,
            "statusBarStyle": "default"
          },
          "notifications": {
            "provider": "apns"
          }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(PWAConfiguration.self, from: data)

        #expect(config.version == 1)
        #expect(config.app.name == "My PWA")
        #expect(config.app.bundleId == "com.example.mypwa")
        #expect(config.app.startUrl == "https://app.example.com/")
        #expect(config.origins.allowed == ["app.example.com", "*.example.com"])
        #expect(config.origins.auth == ["accounts.google.com", "auth0.com"])
        #expect(config.origins.external == ["example.com/external/*"])
        #expect(config.features.notifications == true)
        #expect(config.features.healthkit == false)
        #expect(config.appearance.displayMode == .standalone)
        #expect(config.appearance.pullToRefresh == true)
        #expect(config.notifications.provider == .apns)
    }

    @Test("Encodes configuration to JSON")
    func encodesToJSON() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://test.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["test.example.com"],
                auth: ["auth.example.com"],
                external: []
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(PWAConfiguration.self, from: data)

        #expect(decoded == config)
    }

    // MARK: - Partial Configuration (Default Values)

    @Test("Applies default values for optional sections")
    func appliesDefaultValues() throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Minimal App",
            "bundleId": "com.minimal.app",
            "startUrl": "https://minimal.example.com/"
          },
          "origins": {
            "allowed": ["minimal.example.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(PWAConfiguration.self, from: data)

        // Required fields
        #expect(config.version == 1)
        #expect(config.app.name == "Minimal App")
        #expect(config.origins.allowed == ["minimal.example.com"])

        // Default values for optional origins
        #expect(config.origins.auth == [])
        #expect(config.origins.external == [])

        // Default values for features
        #expect(config.features.notifications == true)
        #expect(config.features.haptics == true)
        #expect(config.features.biometrics == true)
        #expect(config.features.secureStorage == true)
        #expect(config.features.healthkit == false)
        #expect(config.features.iap == false)
        #expect(config.features.share == true)
        #expect(config.features.print == true)
        #expect(config.features.clipboard == true)

        // Default values for appearance
        #expect(config.appearance.displayMode == .standalone)
        #expect(config.appearance.pullToRefresh == false)
        #expect(config.appearance.adaptiveStyle == true)
        #expect(config.appearance.statusBarStyle == .default)

        // Default values for notifications
        #expect(config.notifications.provider == .apns)
    }

    @Test("Decodes partial features configuration")
    func decodesPartialFeatures() throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://test.com/"
          },
          "origins": {
            "allowed": ["test.com"]
          },
          "features": {
            "healthkit": true,
            "iap": true
          }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(PWAConfiguration.self, from: data)

        // Explicitly set values
        #expect(config.features.healthkit == true)
        #expect(config.features.iap == true)

        // Default values for unspecified features
        #expect(config.features.notifications == true)
        #expect(config.features.haptics == true)
    }

    @Test("Decodes partial appearance configuration")
    func decodesPartialAppearance() throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://test.com/"
          },
          "origins": {
            "allowed": ["test.com"]
          },
          "appearance": {
            "displayMode": "fullscreen",
            "statusBarStyle": "lightContent"
          }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(PWAConfiguration.self, from: data)

        #expect(config.appearance.displayMode == .fullscreen)
        #expect(config.appearance.statusBarStyle == .lightContent)
        #expect(config.appearance.pullToRefresh == false)
        #expect(config.appearance.adaptiveStyle == true)
    }

    // MARK: - Default Static Properties

    @Test("FeaturesConfiguration.default has correct values")
    func featuresDefaultValues() {
        let features = FeaturesConfiguration.default

        #expect(features.notifications == true)
        #expect(features.haptics == true)
        #expect(features.biometrics == true)
        #expect(features.secureStorage == true)
        #expect(features.healthkit == false)
        #expect(features.iap == false)
        #expect(features.share == true)
        #expect(features.print == true)
        #expect(features.clipboard == true)
    }

    @Test("AppearanceConfiguration.default has correct values")
    func appearanceDefaultValues() {
        let appearance = AppearanceConfiguration.default

        #expect(appearance.displayMode == .standalone)
        #expect(appearance.pullToRefresh == false)
        #expect(appearance.adaptiveStyle == true)
        #expect(appearance.statusBarStyle == .default)
    }

    @Test("NotificationsConfiguration.default has correct values")
    func notificationsDefaultValues() {
        let notifications = NotificationsConfiguration.default

        #expect(notifications.provider == .apns)
    }

    // MARK: - Enum Encoding/Decoding

    @Test("DisplayMode encodes and decodes correctly")
    func displayModeEncoding() throws {
        let modes: [DisplayMode] = [.standalone, .fullscreen]

        for mode in modes {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(DisplayMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("StatusBarStyle encodes and decodes correctly")
    func statusBarStyleEncoding() throws {
        let styles: [StatusBarStyle] = [.default, .lightContent, .darkContent]

        for style in styles {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(StatusBarStyle.self, from: data)
            #expect(decoded == style)
        }
    }

    @Test("NotificationProvider encodes and decodes correctly")
    func notificationProviderEncoding() throws {
        let providers: [NotificationProvider] = [.apns]

        for provider in providers {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(NotificationProvider.self, from: data)
            #expect(decoded == provider)
        }
    }

    // MARK: - Round Trip Encoding

    @Test("Full configuration round-trips through JSON")
    func roundTripEncoding() throws {
        let original = PWAConfiguration(
            version: 2,
            app: AppConfiguration(
                name: "Round Trip Test",
                bundleId: "com.roundtrip.test",
                startUrl: "https://roundtrip.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["roundtrip.example.com", "*.example.com"],
                auth: ["auth.example.com"],
                external: ["external.example.com"]
            ),
            features: FeaturesConfiguration(
                notifications: false,
                haptics: true,
                biometrics: false,
                secureStorage: true,
                healthkit: true,
                iap: true,
                share: false,
                print: true,
                clipboard: false
            ),
            appearance: AppearanceConfiguration(
                displayMode: .fullscreen,
                pullToRefresh: false,
                adaptiveStyle: false,
                statusBarStyle: .darkContent
            ),
            notifications: NotificationsConfiguration(
                provider: .apns
            )
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PWAConfiguration.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Individual Type Tests

    @Test("AppConfiguration initializes correctly")
    func appConfigurationInit() {
        let config = AppConfiguration(
            name: "Test",
            bundleId: "com.test",
            startUrl: "https://test.com/"
        )

        #expect(config.name == "Test")
        #expect(config.bundleId == "com.test")
        #expect(config.startUrl == "https://test.com/")
    }

    @Test("OriginsConfiguration initializes with defaults")
    func originsConfigurationInit() {
        let config = OriginsConfiguration(allowed: ["example.com"])

        #expect(config.allowed == ["example.com"])
        #expect(config.auth == [])
        #expect(config.external == [])
    }

    @Test("OriginsConfiguration initializes with all parameters")
    func originsConfigurationFullInit() {
        let config = OriginsConfiguration(
            allowed: ["allowed.com"],
            auth: ["auth.com"],
            external: ["external.com"]
        )

        #expect(config.allowed == ["allowed.com"])
        #expect(config.auth == ["auth.com"])
        #expect(config.external == ["external.com"])
    }
}
