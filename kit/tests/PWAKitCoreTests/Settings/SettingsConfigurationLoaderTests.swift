import Foundation
@testable import PWAKitApp
import Testing

// MARK: - SettingsConfigurationLoaderTests

@Suite("SettingsConfigurationLoader Tests")
struct SettingsConfigurationLoaderTests {
    // MARK: - Configuration Loading Tests

    @Test("Loads configuration from valid JSON data")
    func loadsFromValidData() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test App",
            "bundleId": "com.test.app",
            "startUrl": "https://test.example.com/"
          },
          "origins": {
            "allowed": ["test.example.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)

        #expect(config.version == 1)
        #expect(config.app.name == "Test App")
        #expect(config.app.bundleId == "com.test.app")
        #expect(config.app.startUrl == "https://test.example.com/")
        #expect(config.origins.allowed == ["test.example.com"])
    }

    @Test("Applies default values when loading partial configuration")
    func appliesDefaultsForPartialConfig() async throws {
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
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)

        #expect(config.features.notifications == true)
        #expect(config.features.haptics == true)
        #expect(config.appearance.displayMode == .standalone)
        #expect(config.appearance.pullToRefresh == false)
        #expect(config.notifications.provider == .apns)
    }

    // MARK: - Fallback Tests

    @Test("Returns default configuration when no file exists")
    func returnsDefaultWhenNoFile() async throws {
        let loader = SettingsConfigurationLoader(bundle: Bundle(for: BundleToken.self))
        let config = try await loader.loadConfiguration()

        #expect(config.app.name == "PWA App")
        #expect(config.app.bundleId == "com.example.pwa")
        #expect(config.app.startUrl == "https://example.com/")
    }

    @Test("loadFromDocuments throws fileNotFound when file missing")
    func documentsThrowsWhenMissing() async throws {
        let loader = SettingsConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromDocuments()
        }
    }

    @Test("loadFromBundle throws fileNotFound when file missing in test bundle")
    func bundleThrowsWhenMissing() async throws {
        let loader = SettingsConfigurationLoader(bundle: Bundle(for: BundleToken.self))

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromBundle()
        }
    }

    // MARK: - Invalid JSON Handling Tests

    @Test("Throws invalidJSON for malformed JSON")
    func throwsForMalformedJSON() async throws {
        let json = "{ invalid json }"
        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromData(data)
        }
    }

    @Test("Throws invalidJSON for missing required fields")
    func throwsForMissingFields() async throws {
        let json = """
        {
          "version": 1,
          "origins": {
            "allowed": ["example.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromData(data)
        }
    }

    // MARK: - Validation Tests

    @Test("Throws validation error for invalid startUrl")
    func throwsForInvalidStartUrl() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "http://insecure.com/"
          },
          "origins": {
            "allowed": ["insecure.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()

        do {
            _ = try await loader.loadFromData(data)
            Issue.record("Expected validation error for non-HTTPS URL")
        } catch let error as ConfigurationError {
            if case let .validation(validationError) = error {
                #expect(validationError == .startUrlNotHttps("http://insecure.com/"))
            } else {
                Issue.record("Expected validation error, got: \(error)")
            }
        }
    }

    @Test("Throws validation error for empty allowed origins")
    func throwsForEmptyAllowedOrigins() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://test.com/"
          },
          "origins": {
            "allowed": []
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()

        do {
            _ = try await loader.loadFromData(data)
            Issue.record("Expected validation error for empty allowed origins")
        } catch let error as ConfigurationError {
            if case let .validation(validationError) = error {
                #expect(validationError == .emptyAllowedOrigins)
            } else {
                Issue.record("Expected validation error, got: \(error)")
            }
        }
    }

    // MARK: - Caching Tests

    @Test("Caches configuration after first load")
    func cachesConfiguration() async throws {
        let loader = SettingsConfigurationLoader(bundle: Bundle(for: BundleToken.self))

        let config1 = try await loader.loadConfiguration()
        #expect(config1.app.name == "PWA App")

        let config2 = try await loader.loadConfiguration()
        #expect(config1 == config2)
    }

    @Test("clearCache invalidates cached configuration")
    func clearCacheInvalidates() async throws {
        let loader = SettingsConfigurationLoader(bundle: Bundle(for: BundleToken.self))

        _ = try await loader.loadConfiguration()
        await loader.clearCache()

        let config = try await loader.loadConfiguration()
        #expect(config.app.name == "PWA App")
    }

    @Test("ignoreCache bypasses cached configuration")
    func ignoreCacheBypassesCache() async throws {
        let loader = SettingsConfigurationLoader(bundle: Bundle(for: BundleToken.self))

        let config1 = try await loader.loadConfiguration()
        let config2 = try await loader.loadConfiguration(ignoreCache: true)
        #expect(config1 == config2)
    }

    // MARK: - WebViewConfiguration Factory Tests

    @Test("Creates WebViewConfiguration from loaded config")
    func createsWebViewConfiguration() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test App",
            "bundleId": "com.test.app",
            "startUrl": "https://test.example.com/"
          },
          "origins": {
            "allowed": ["test.example.com"],
            "auth": ["accounts.google.com"]
          },
          "appearance": {
            "displayMode": "standalone",
            "pullToRefresh": true,
            "adaptiveStyle": false
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)
        let webViewConfig = try loader.webViewConfiguration(from: config)

        #expect(webViewConfig.startURL == URL(string: "https://test.example.com/"))
        #expect(webViewConfig.allowedOrigins == ["test.example.com"])
        #expect(webViewConfig.authOrigins == ["accounts.google.com"])
        #expect(webViewConfig.displayMode == .standalone)
        #expect(webViewConfig.pullToRefresh == true)
        #expect(webViewConfig.adaptiveUIStyle == false)
    }

    // MARK: - Origins Parsing Tests

    @Test("Parses allowed origins correctly")
    func parsesAllowedOrigins() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com", "*.example.com", "sub.domain.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        _ = try await loader.loadFromData(data)

        // Cache the config and verify origins
        let config = try await loader.loadFromData(data)
        #expect(config.origins.allowed.count == 3)
        #expect(config.origins.allowed.contains("app.example.com"))
        #expect(config.origins.allowed.contains("*.example.com"))
    }

    @Test("Parses auth origins correctly")
    func parsesAuthOrigins() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com"],
            "auth": ["accounts.google.com", "auth0.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)

        #expect(config.origins.auth.count == 2)
        #expect(config.origins.auth.contains("accounts.google.com"))
        #expect(config.origins.auth.contains("auth0.com"))
    }

    @Test("Parses external origins correctly")
    func parsesExternalOrigins() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com"],
            "external": ["external.site.com", "other.com/path/*"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)

        #expect(config.origins.external.count == 2)
        #expect(config.origins.external.contains("external.site.com"))
    }

    // MARK: - Display Mode and Features Tests

    @Test("Parses display mode correctly")
    func parsesDisplayMode() async throws {
        let standaloneJson = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com"]
          },
          "appearance": {
            "displayMode": "standalone"
          }
        }
        """

        let fullscreenJson = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com"]
          },
          "appearance": {
            "displayMode": "fullscreen"
          }
        }
        """

        let loader = SettingsConfigurationLoader()

        let standaloneConfig = try await loader.loadFromData(Data(standaloneJson.utf8))
        #expect(standaloneConfig.appearance.displayMode == .standalone)

        let fullscreenConfig = try await loader.loadFromData(Data(fullscreenJson.utf8))
        #expect(fullscreenConfig.appearance.displayMode == .fullscreen)
    }

    @Test("Parses features correctly")
    func parsesFeatures() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://app.example.com/"
          },
          "origins": {
            "allowed": ["app.example.com"]
          },
          "features": {
            "notifications": false,
            "haptics": true,
            "biometrics": false,
            "healthkit": true,
            "iap": true
          }
        }
        """

        let data = Data(json.utf8)
        let loader = SettingsConfigurationLoader()
        let config = try await loader.loadFromData(data)

        #expect(config.features.notifications == false)
        #expect(config.features.haptics == true)
        #expect(config.features.biometrics == false)
        #expect(config.features.healthkit == true)
        #expect(config.features.iap == true)
    }

    // MARK: - Default Configuration Tests

    @Test("Default configuration is valid")
    func defaultConfigurationIsValid() throws {
        let defaultConfig = SettingsConfigurationLoader.defaultConfiguration

        try ConfigurationValidator.validate(defaultConfig)

        #expect(defaultConfig.version == 1)
        #expect(defaultConfig.app.name == "PWA App")
        #expect(defaultConfig.app.startUrl == "https://example.com/")
        #expect(defaultConfig.origins.allowed == ["example.com"])
    }

    @Test("Config file name is correct")
    func configFileNameIsCorrect() {
        #expect(SettingsConfigurationLoader.configFileName == "pwa-config.json")
    }
}

// MARK: - BundleToken

/// Helper class to get the test bundle
private final class BundleToken {}
