import Foundation
import Testing
import WebKit

@testable import PWAKitApp

// MARK: - PlatformCookieManagerTests

@Suite("PlatformCookieManager Tests")
struct PlatformCookieManagerTests {
    // MARK: - Cookie Creation

    @Test("Creates cookie with default settings")
    func createsCookieWithDefaultSettings() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie != nil)
        #expect(cookie?.name == "app-platform")
        #expect(cookie?.value == "ios")
        #expect(cookie?.path == "/")
        #expect(cookie?.isSecure == true)
    }

    @Test("Creates cookie with custom settings")
    func createsCookieWithCustomSettings() {
        let settings = PlatformCookieSettings(
            enabled: true,
            name: "my-platform",
            value: "ios-native"
        )
        let manager = PlatformCookieManager(settings: settings)
        let url = URL(string: "https://test.example.com/path")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie != nil)
        #expect(cookie?.name == "my-platform")
        #expect(cookie?.value == "ios-native")
    }

    @Test("Returns nil when settings are disabled")
    func returnsNilWhenSettingsDisabled() {
        let manager = PlatformCookieManager(settings: .disabled)
        let url = URL(string: "https://app.example.com/")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie == nil)
    }

    @Test("Returns nil for URL without host")
    func returnsNilForURLWithoutHost() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "about:blank")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie == nil)
    }

    @Test("Creates non-secure cookie for HTTP URL")
    func createsNonSecureCookieForHTTP() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "http://localhost:3000/")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie != nil)
        #expect(cookie?.isSecure == false)
    }

    // MARK: - Cookie Expiration

    @Test("Cookie expires in approximately one year")
    func cookieExpiresInOneYear() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/")!
        let now = Date()

        let cookie = manager.makeCookie(for: url)

        #expect(cookie != nil)
        guard let expiresDate = cookie?.expiresDate else {
            Issue.record("Cookie should have expiration date")
            return
        }

        // Should be approximately 365 days from now (with small tolerance for test execution time)
        let expectedExpiration = now.addingTimeInterval(365 * 24 * 60 * 60)
        let tolerance: TimeInterval = 60 // 1 minute tolerance

        #expect(abs(expiresDate.timeIntervalSince(expectedExpiration)) < tolerance)
    }

    @Test("Respects custom expiration date")
    func respectsCustomExpirationDate() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/")!
        let customExpiration = Date().addingTimeInterval(60 * 60) // 1 hour from now

        let cookie = manager.makeCookie(for: url, expirationDate: customExpiration)

        #expect(cookie != nil)
        guard let expiresDate = cookie?.expiresDate else {
            Issue.record("Cookie should have expiration date")
            return
        }

        let tolerance: TimeInterval = 1 // 1 second tolerance
        #expect(abs(expiresDate.timeIntervalSince(customExpiration)) < tolerance)
    }

    // MARK: - Domain Extraction

    @Test("Extracts domain from simple host")
    func extractsDomainFromSimpleHost() {
        let manager = PlatformCookieManager(settings: .default)

        let domain = manager.extractCookieDomain(from: "example.com")

        #expect(domain == ".example.com")
    }

    @Test("Extracts domain from subdomain")
    func extractsDomainFromSubdomain() {
        let manager = PlatformCookieManager(settings: .default)

        let domain = manager.extractCookieDomain(from: "app.example.com")

        #expect(domain == ".example.com")
    }

    @Test("Extracts domain from deep subdomain")
    func extractsDomainFromDeepSubdomain() {
        let manager = PlatformCookieManager(settings: .default)

        let domain = manager.extractCookieDomain(from: "dev.app.example.com")

        #expect(domain == ".example.com")
    }

    @Test("Preserves localhost as-is")
    func preservesLocalhost() {
        let manager = PlatformCookieManager(settings: .default)

        let domain = manager.extractCookieDomain(from: "localhost")

        #expect(domain == "localhost")
    }

    @Test("Preserves IP address as-is")
    func preservesIPAddress() {
        let manager = PlatformCookieManager(settings: .default)

        let domain = manager.extractCookieDomain(from: "192.168.1.1")

        #expect(domain == "192.168.1.1")
    }

    // MARK: - Domain Matching

    @Test("Matches exact origin")
    func matchesExactOrigin() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/page")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["app.example.com"])

        #expect(shouldSet == true)
    }

    @Test("Matches wildcard origin")
    func matchesWildcardOrigin() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/page")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["*.example.com"])

        #expect(shouldSet == true)
    }

    @Test("Wildcard matches base domain")
    func wildcardMatchesBaseDomain() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://example.com/page")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["*.example.com"])

        #expect(shouldSet == true)
    }

    @Test("Does not match different domain")
    func doesNotMatchDifferentDomain() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://other.com/page")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["example.com", "*.example.com"])

        #expect(shouldSet == false)
    }

    @Test("Case insensitive matching")
    func caseInsensitiveMatching() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://APP.Example.COM/page")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["app.example.com"])

        #expect(shouldSet == true)
    }

    @Test("Returns false when settings disabled")
    func returnsFalseWhenSettingsDisabled() {
        let manager = PlatformCookieManager(settings: .disabled)
        let url = URL(string: "https://app.example.com/")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["app.example.com"])

        #expect(shouldSet == false)
    }

    @Test("Returns false for URL without host")
    func returnsFalseForURLWithoutHostInMatching() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "about:blank")!

        let shouldSet = manager.shouldSetCookie(for: url, allowedOrigins: ["example.com"])

        #expect(shouldSet == false)
    }

    // MARK: - Script Creation

    @Test("Creates cookie script with default settings")
    @MainActor
    func createsCookieScriptWithDefaultSettings() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/")!

        let script = manager.makeCookieScript(for: url)

        #expect(script != nil)
        #expect(script?.source.contains("app-platform=ios") == true)
        #expect(script?.source.contains("domain=.example.com") == true)
        #expect(script?.source.contains("path=/") == true)
        #expect(script?.source.contains("Secure") == true)
        #expect(script?.source.contains("SameSite=Lax") == true)
        #expect(script?.injectionTime == .atDocumentStart)
    }

    @Test("Cookie script omits Secure for HTTP")
    @MainActor
    func cookieScriptOmitsSecureForHTTP() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "http://localhost:3000/")!

        let script = manager.makeCookieScript(for: url)

        #expect(script != nil)
        #expect(script?.source.contains("; Secure") == false)
    }

    @Test("Returns nil script when settings disabled")
    @MainActor
    func returnsNilScriptWhenSettingsDisabled() {
        let manager = PlatformCookieManager(settings: .disabled)
        let url = URL(string: "https://app.example.com/")!

        let script = manager.makeCookieScript(for: url)

        #expect(script == nil)
    }

    @Test("Returns nil script for URL without host")
    @MainActor
    func returnsNilScriptForURLWithoutHost() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "about:blank")!

        let script = manager.makeCookieScript(for: url)

        #expect(script == nil)
    }

    // MARK: - Referrer Script

    @Test("Creates referrer script")
    @MainActor
    func createsReferrerScript() {
        let manager = PlatformCookieManager(settings: .default)

        let script = manager.makeReferrerScript(referrer: "https://app.example.com/")

        #expect(script.source.contains("'referrer'"))
        #expect(script.source.contains("https://app.example.com/"))
        #expect(script.source.contains("Object.defineProperty"))
        #expect(script.injectionTime == .atDocumentStart)
        #expect(script.isForMainFrameOnly == true)
    }

    @Test("Escapes special characters in referrer")
    @MainActor
    func escapesSpecialCharactersInReferrer() {
        let manager = PlatformCookieManager(settings: .default)

        let script = manager.makeReferrerScript(referrer: "https://example.com/?q='test'")

        // The single quotes should be escaped
        #expect(script.source.contains("\\'"))
    }
}

// MARK: - PlatformCookieManagerIntegrationTests

@Suite("PlatformCookieManager Integration Tests")
struct PlatformCookieManagerIntegrationTests {
    @Test("Cookie has correct properties for web use")
    func cookieHasCorrectPropertiesForWebUse() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://myapp.example.com/dashboard")!

        let cookie = manager.makeCookie(for: url)

        #expect(cookie != nil)

        // Verify all required properties for a functional cookie
        #expect(cookie?.name == "app-platform")
        #expect(cookie?.value == "ios")
        #expect(cookie?.domain == ".example.com")
        #expect(cookie?.path == "/")
        #expect(cookie?.isSecure == true)
        #expect(cookie?.isHTTPOnly == false) // Should be accessible to JavaScript
        #expect(cookie?.expiresDate != nil)
    }

    @Test("Cookie script produces valid JavaScript")
    @MainActor
    func cookieScriptProducesValidJavaScript() {
        let manager = PlatformCookieManager(settings: .default)
        let url = URL(string: "https://app.example.com/")!

        let script = manager.makeCookieScript(for: url)

        #expect(script != nil)

        // Verify the script structure
        let source = script?.source ?? ""
        #expect(source.hasPrefix("document.cookie"))
        #expect(source.contains("="))
        #expect(source.hasSuffix("\";"))
    }

    @Test("Manager preserves settings")
    func managerPreservesSettings() {
        let customSettings = PlatformCookieSettings(
            enabled: true,
            name: "test-platform",
            value: "test-ios"
        )
        let manager = PlatformCookieManager(settings: customSettings)

        #expect(manager.settings == customSettings)
        #expect(manager.settings.name == "test-platform")
        #expect(manager.settings.value == "test-ios")
    }
}
