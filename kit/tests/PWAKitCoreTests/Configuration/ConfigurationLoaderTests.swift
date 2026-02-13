import Foundation
@testable import PWAKitApp
import Testing

// MARK: - ConfigurationLoaderTests

@Suite("ConfigurationLoader Tests")
struct ConfigurationLoaderTests {
    // MARK: - Bundle Loading Tests

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
        let loader = ConfigurationLoader()
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
        let loader = ConfigurationLoader()
        let config = try await loader.loadFromData(data)

        // Check defaults are applied
        #expect(config.features.notifications == true)
        #expect(config.features.haptics == true)
        #expect(config.appearance.displayMode == .standalone)
        #expect(config.appearance.pullToRefresh == false)
        #expect(config.notifications.provider == .apns)
    }

    // MARK: - Missing File Fallback Tests

    @Test("Returns default configuration when no file exists")
    func returnsDefaultWhenNoFile() async throws {
        // Create a loader with an empty bundle that has no config file
        let loader = ConfigurationLoader(bundle: Bundle(for: BundleToken.self))
        let config = try await loader.load()

        // Should return the default configuration
        #expect(config.app.name == "PWA App")
        #expect(config.app.bundleId == "com.example.pwa")
        #expect(config.app.startUrl == "https://example.com/")
    }

    @Test("loadFromDocuments throws fileNotFound when file missing")
    func documentsThrowsWhenMissing() async throws {
        let loader = ConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromDocuments()
        }
    }

    @Test("loadFromBundle throws fileNotFound when file missing")
    func bundleThrowsWhenMissing() async throws {
        // Use the test bundle which doesn't have a pwa-config.json
        let loader = ConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromBundle(Bundle(for: BundleToken.self))
        }
    }

    // MARK: - Invalid JSON Handling Tests

    @Test("Throws invalidJSON for malformed JSON")
    func throwsForMalformedJSON() async throws {
        let json = "{ invalid json }"
        let data = Data(json.utf8)
        let loader = ConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromData(data)
        }
    }

    @Test("Throws invalidJSON for missing required fields")
    func throwsForMissingFields() async throws {
        // Missing "app" field
        let json = """
        {
          "version": 1,
          "origins": {
            "allowed": ["example.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = ConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromData(data)
        }
    }

    @Test("Throws invalidJSON for wrong types")
    func throwsForWrongTypes() async throws {
        // version should be Int, not String
        let json = """
        {
          "version": "one",
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://test.com/"
          },
          "origins": {
            "allowed": ["test.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = ConfigurationLoader()

        await #expect(throws: ConfigurationError.self) {
            try await loader.loadFromData(data)
        }
    }

    // MARK: - Validation Integration Tests

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
        let loader = ConfigurationLoader()

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
        let loader = ConfigurationLoader()

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

    @Test("Throws validation error when startUrl host doesn't match allowed origins")
    func throwsForMismatchedOrigin() async throws {
        let json = """
        {
          "version": 1,
          "app": {
            "name": "Test",
            "bundleId": "com.test",
            "startUrl": "https://different.com/"
          },
          "origins": {
            "allowed": ["example.com"]
          }
        }
        """

        let data = Data(json.utf8)
        let loader = ConfigurationLoader()

        do {
            _ = try await loader.loadFromData(data)
            Issue.record("Expected validation error for mismatched origin")
        } catch let error as ConfigurationError {
            if case .validation = error {
                // Expected
            } else {
                Issue.record("Expected validation error, got: \(error)")
            }
        }
    }

    // MARK: - Caching Tests

    @Test("Caches configuration after first load")
    func cachesConfiguration() async throws {
        let loader = ConfigurationLoader()

        // Load first time
        let config1 = try await loader.load()

        // Load again (should return cached value, not reload)
        let config2 = try await loader.load()

        // Both should be the same cached configuration
        #expect(config1.app.name == config2.app.name)
        #expect(config1 == config2)
    }

    @Test("clearCache invalidates cached configuration")
    func clearCacheInvalidates() async throws {
        let loader = ConfigurationLoader()

        // Load to populate cache
        let config1 = try await loader.load()

        // Clear cache
        await loader.clearCache()

        // Next load should reload
        let config2 = try await loader.load()

        // Should still load the same configuration (verifies reload works)
        #expect(config1 == config2)
    }

    @Test("ignoreCache bypasses cached configuration")
    func ignoreCacheBypassesCache() async throws {
        let loader = ConfigurationLoader()

        // Load first time
        let config1 = try await loader.load()

        // Load again with ignoreCache (should reload)
        let config2 = try await loader.load(ignoreCache: true)

        // Should load the same configuration (verifies ignoreCache works)
        #expect(config1 == config2)
    }

    // MARK: - Default Configuration Tests

    @Test("Default configuration is valid")
    func defaultConfigurationIsValid() throws {
        let defaultConfig = ConfigurationLoader.defaultConfiguration

        // Should not throw
        try ConfigurationValidator.validate(defaultConfig)

        #expect(defaultConfig.version == 1)
        #expect(defaultConfig.app.name == "PWA App")
        #expect(defaultConfig.app.startUrl == "https://example.com/")
        #expect(defaultConfig.origins.allowed == ["example.com"])
    }

    @Test("Config file name is correct")
    func configFileNameIsCorrect() {
        #expect(ConfigurationLoader.configFileName == "pwa-config.json")
    }
}

// MARK: - ConfigurationErrorTests

@Suite("ConfigurationError Tests")
struct ConfigurationErrorTests {
    @Test("Error descriptions are informative")
    func errorDescriptions() {
        let errors: [(ConfigurationError, String)] = [
            (.fileNotFound(source: "test.json"), "Configuration file not found: test.json"),
            (
                .unableToRead(source: "test.json", reason: "Permission denied"),
                "Unable to read configuration from test.json: Permission denied"
            ),
            (.invalidJSON(reason: "Unexpected token"), "Invalid JSON in configuration file: Unexpected token"),
            (.unexpected(reason: "Unknown error"), "Unexpected configuration error: Unknown error"),
        ]

        for (error, expectedDescription) in errors {
            #expect(error.localizedDescription == expectedDescription)
        }
    }

    @Test("Validation error wrapping preserves original error")
    func validationErrorWrapping() {
        let validationError = ConfigurationValidationError.emptyAllowedOrigins
        let configError = ConfigurationError.validation(validationError)

        if case let .validation(wrapped) = configError {
            #expect(wrapped == validationError)
        } else {
            Issue.record("Expected validation error case")
        }
    }

    @Test("Errors are Equatable")
    func errorsAreEquatable() {
        let error1 = ConfigurationError.fileNotFound(source: "test.json")
        let error2 = ConfigurationError.fileNotFound(source: "test.json")
        let error3 = ConfigurationError.fileNotFound(source: "other.json")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Errors are Sendable")
    func errorsAreSendable() async {
        let error = ConfigurationError.fileNotFound(source: "test.json")

        // This compiles if ConfigurationError is Sendable
        await Task {
            _ = error
        }.value
    }
}

// MARK: - BundleToken

/// Helper class to get the test bundle
private final class BundleToken {}
