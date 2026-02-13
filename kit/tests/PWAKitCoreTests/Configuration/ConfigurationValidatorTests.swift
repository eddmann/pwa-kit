import Foundation
@testable import PWAKitApp
import Testing

@Suite("ConfigurationValidator Tests")
struct ConfigurationValidatorTests {
    // MARK: - Valid Configuration Tests

    @Test("Validates a complete valid configuration")
    func validatesCompleteConfiguration() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com"],
                auth: ["accounts.google.com"],
                external: ["docs.example.com"]
            )
        )

        // Should not throw
        try ConfigurationValidator.validate(config)
    }

    @Test("Validates configuration with wildcard origins")
    func validatesWildcardOrigins() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["*.example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Validates configuration with path patterns")
    func validatesPathPatterns() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://example.com/app/"
            ),
            origins: OriginsConfiguration(
                allowed: ["example.com/app/*"],
                auth: [],
                external: ["example.com/external/*"]
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Validates configuration with multiple allowed origins")
    func validatesMultipleAllowedOrigins() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com", "api.example.com", "cdn.example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    // MARK: - Invalid URL Tests

    @Test("Rejects invalid start URL")
    func rejectsInvalidStartUrl() throws {
        // Test a truly malformed URL that cannot be parsed
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "ht tp://bad url"
            ),
            origins: OriginsConfiguration(allowed: ["example.com"])
        )

        #expect(throws: ConfigurationValidationError.invalidStartUrl("ht tp://bad url")) {
            try ConfigurationValidator.validate(config)
        }
    }

    @Test("Rejects start URL without proper scheme")
    func rejectsStartUrlWithoutProperScheme() throws {
        // "not a valid url" is parsed as a URL without a scheme
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "not-a-valid-url"
            ),
            origins: OriginsConfiguration(allowed: ["example.com"])
        )

        #expect(throws: ConfigurationValidationError.startUrlNotHttps("not-a-valid-url")) {
            try ConfigurationValidator.validate(config)
        }
    }

    @Test("Rejects HTTP start URL")
    func rejectsHttpStartUrl() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "http://app.example.com/"
            ),
            origins: OriginsConfiguration(allowed: ["app.example.com"])
        )

        #expect(throws: ConfigurationValidationError.startUrlNotHttps("http://app.example.com/")) {
            try ConfigurationValidator.validate(config)
        }
    }

    @Test("Rejects URL without scheme")
    func rejectsUrlWithoutScheme() throws {
        #expect(throws: ConfigurationValidationError.startUrlNotHttps("app.example.com/")) {
            try ConfigurationValidator.validateStartUrl("app.example.com/")
        }
    }

    @Test("Rejects URL with only scheme")
    func rejectsUrlWithOnlyScheme() throws {
        #expect(throws: ConfigurationValidationError.invalidStartUrl("https://")) {
            try ConfigurationValidator.validateStartUrl("https://")
        }
    }

    @Test("Rejects empty URL")
    func rejectsEmptyUrl() throws {
        #expect(throws: ConfigurationValidationError.invalidStartUrl("")) {
            try ConfigurationValidator.validateStartUrl("")
        }
    }

    @Test("Accepts HTTPS URL with port")
    func acceptsHttpsUrlWithPort() throws {
        try ConfigurationValidator.validateStartUrl("https://app.example.com:8443/")
    }

    @Test("Accepts HTTPS URL with path")
    func acceptsHttpsUrlWithPath() throws {
        try ConfigurationValidator.validateStartUrl("https://app.example.com/app/index.html")
    }

    @Test("Accepts HTTPS URL with query parameters")
    func acceptsHttpsUrlWithQuery() throws {
        try ConfigurationValidator.validateStartUrl("https://app.example.com/?lang=en")
    }

    // MARK: - Empty Origins Tests

    @Test("Rejects empty allowed origins")
    func rejectsEmptyAllowedOrigins() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(allowed: [])
        )

        #expect(throws: ConfigurationValidationError.emptyAllowedOrigins) {
            try ConfigurationValidator.validate(config)
        }
    }

    // MARK: - Wildcard Pattern Tests

    @Test("Validates simple wildcard pattern")
    func validatesSimpleWildcard() throws {
        try ConfigurationValidator.validateOriginPattern("*.example.com")
    }

    @Test("Validates nested subdomain wildcard pattern")
    func validatesNestedWildcard() throws {
        try ConfigurationValidator.validateOriginPattern("*.sub.example.com")
    }

    @Test("Rejects wildcard in middle of domain")
    func rejectsMiddleWildcard() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("exam*.com")) {
            try ConfigurationValidator.validateOriginPattern("exam*.com")
        }
    }

    @Test("Rejects wildcard without dot")
    func rejectsWildcardWithoutDot() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("*example.com")) {
            try ConfigurationValidator.validateOriginPattern("*example.com")
        }
    }

    @Test("Rejects standalone wildcard")
    func rejectsStandaloneWildcard() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("*.")) {
            try ConfigurationValidator.validateOriginPattern("*.")
        }
    }

    @Test("Rejects double wildcard")
    func rejectsDoubleWildcard() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("*.*.example.com")) {
            try ConfigurationValidator.validateOriginPattern("*.*.example.com")
        }
    }

    // MARK: - Invalid Origin Pattern Tests

    @Test("Rejects empty origin pattern")
    func rejectsEmptyPattern() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("")) {
            try ConfigurationValidator.validateOriginPattern("")
        }
    }

    @Test("Rejects whitespace-only origin pattern")
    func rejectsWhitespacePattern() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("   ")) {
            try ConfigurationValidator.validateOriginPattern("   ")
        }
    }

    @Test("Rejects pattern with http scheme")
    func rejectsHttpSchemePattern() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("http://example.com")) {
            try ConfigurationValidator.validateOriginPattern("http://example.com")
        }
    }

    @Test("Rejects pattern with https scheme")
    func rejectsHttpsSchemePattern() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("https://example.com")) {
            try ConfigurationValidator.validateOriginPattern("https://example.com")
        }
    }

    @Test("Rejects pattern with invalid characters")
    func rejectsInvalidCharacters() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("example@.com")) {
            try ConfigurationValidator.validateOriginPattern("example@.com")
        }
    }

    @Test("Rejects domain part starting with hyphen")
    func rejectsDomainStartingWithHyphen() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("-example.com")) {
            try ConfigurationValidator.validateOriginPattern("-example.com")
        }
    }

    @Test("Rejects domain part ending with hyphen")
    func rejectsDomainEndingWithHyphen() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("example-.com")) {
            try ConfigurationValidator.validateOriginPattern("example-.com")
        }
    }

    @Test("Accepts domain with hyphen in middle")
    func acceptsDomainWithHyphen() throws {
        try ConfigurationValidator.validateOriginPattern("my-example.com")
    }

    @Test("Rejects pattern with empty domain parts")
    func rejectsEmptyDomainParts() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("example..com")) {
            try ConfigurationValidator.validateOriginPattern("example..com")
        }
    }

    // MARK: - Path Pattern Tests

    @Test("Validates path with trailing wildcard")
    func validatesPathWithWildcard() throws {
        try ConfigurationValidator.validateOriginPattern("example.com/api/*")
    }

    @Test("Validates path without wildcard")
    func validatesPathWithoutWildcard() throws {
        try ConfigurationValidator.validateOriginPattern("example.com/app/")
    }

    @Test("Validates deep path with wildcard")
    func validatesDeepPathWithWildcard() throws {
        try ConfigurationValidator.validateOriginPattern("example.com/api/v1/users/*")
    }

    @Test("Rejects path with wildcard not at end")
    func rejectsWildcardNotAtEnd() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("example.com/*/api")) {
            try ConfigurationValidator.validateOriginPattern("example.com/*/api")
        }
    }

    @Test("Rejects path with multiple wildcards")
    func rejectsMultiplePathWildcards() throws {
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("example.com/api/*/*")) {
            try ConfigurationValidator.validateOriginPattern("example.com/api/*/*")
        }
    }

    // MARK: - Conflicting Configuration Tests

    @Test("Rejects start URL host not in allowed origins")
    func rejectsStartUrlNotInAllowed() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["other.example.com"],
                auth: [],
                external: []
            )
        )

        #expect {
            try ConfigurationValidator.validate(config)
        } throws: { error in
            guard let validationError = error as? ConfigurationValidationError,
                  case let .conflictingConfiguration(message) = validationError else
            {
                return false
            }
            return message.contains("app.example.com") && message.contains("does not match")
        }
    }

    @Test("Accepts start URL host matching wildcard origin")
    func acceptsStartUrlMatchingWildcard() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["*.example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Accepts start URL host matching exact origin")
    func acceptsStartUrlMatchingExact() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Rejects origin in both allowed and external")
    func rejectsOverlappingOrigins() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com", "api.example.com"],
                auth: [],
                external: ["api.example.com"]
            )
        )

        #expect {
            try ConfigurationValidator.validate(config)
        } throws: { error in
            guard let validationError = error as? ConfigurationValidationError,
                  case let .conflictingConfiguration(message) = validationError else
            {
                return false
            }
            return message.contains("api.example.com") && message.contains("both allowed and external")
        }
    }

    // MARK: - Error Description Tests

    @Test("Error descriptions are localized")
    func errorDescriptionsAreLocalized() throws {
        let errors: [ConfigurationValidationError] = [
            .invalidStartUrl("bad-url"),
            .startUrlNotHttps("http://example.com"),
            .invalidOriginPattern("bad*pattern"),
            .emptyAllowedOrigins,
            .conflictingConfiguration("test conflict"),
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(try !(#require(description?.isEmpty)))
        }
    }

    @Test("Invalid URL error contains the URL")
    func invalidUrlErrorContainsUrl() {
        let error = ConfigurationValidationError.invalidStartUrl("bad-url")
        #expect(error.errorDescription?.contains("bad-url") == true)
    }

    @Test("Not HTTPS error contains the URL")
    func notHttpsErrorContainsUrl() {
        let error = ConfigurationValidationError.startUrlNotHttps("http://example.com")
        #expect(error.errorDescription?.contains("http://example.com") == true)
    }

    @Test("Invalid pattern error contains the pattern")
    func invalidPatternErrorContainsPattern() {
        let error = ConfigurationValidationError.invalidOriginPattern("bad*pattern")
        #expect(error.errorDescription?.contains("bad*pattern") == true)
    }

    // MARK: - Edge Cases

    @Test("Validates subdomain matching base domain with wildcard")
    func validatesSubdomainMatchingWildcard() throws {
        // *.example.com should match sub.example.com
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://sub.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["*.example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Validates base domain matching wildcard")
    func validatesBaseDomainMatchingWildcard() throws {
        // *.example.com should also match example.com
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["*.example.com"],
                auth: [],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Validates numeric domain parts")
    func validatesNumericDomainParts() throws {
        try ConfigurationValidator.validateOriginPattern("192.168.1.1")
    }

    @Test("Validates single-part TLD-like domain")
    func validatesSinglePartDomain() throws {
        try ConfigurationValidator.validateOriginPattern("localhost")
    }

    @Test("Validates international characters rejected")
    func rejectsInternationalCharacters() throws {
        // Domain names with special characters should be rejected
        // (punycode should be used instead)
        #expect(throws: ConfigurationValidationError.invalidOriginPattern("例え.jp")) {
            try ConfigurationValidator.validateOriginPattern("例え.jp")
        }
    }

    @Test("Validates auth origins")
    func validatesAuthOrigins() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com"],
                auth: ["accounts.google.com", "*.auth0.com"],
                external: []
            )
        )

        try ConfigurationValidator.validate(config)
    }

    @Test("Rejects invalid auth origin")
    func rejectsInvalidAuthOrigin() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com"],
                auth: ["https://invalid-auth.com"],
                external: []
            )
        )

        #expect(throws: ConfigurationValidationError.invalidOriginPattern("https://invalid-auth.com")) {
            try ConfigurationValidator.validate(config)
        }
    }

    @Test("Rejects invalid external origin")
    func rejectsInvalidExternalOrigin() throws {
        let config = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://app.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["app.example.com"],
                auth: [],
                external: ["bad*pattern"]
            )
        )

        #expect(throws: ConfigurationValidationError.invalidOriginPattern("bad*pattern")) {
            try ConfigurationValidator.validate(config)
        }
    }
}
