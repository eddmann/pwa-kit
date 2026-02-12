import Foundation
import Testing

@testable import PWAKitApp

@Suite("NavigationPolicy Tests")
struct NavigationPolicyTests {
    // MARK: - Allowed Origins Matching

    @Suite("Allowed Origins")
    struct AllowedOriginsTests {
        @Test("Exact domain match allows navigation")
        func exactDomainMatchAllows() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://example.com/page")!
            #expect(resolver.resolve(for: url) == .allow)
        }

        @Test("Non-matching domain opens externally")
        func nonMatchingDomainOpensExternally() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://other.com/page")!
            #expect(resolver.resolve(for: url) == .external)
        }

        @Test("Wildcard subdomain matches subdomains")
        func wildcardSubdomainMatches() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["*.example.com"]
            )

            let urls = [
                URL(string: "https://app.example.com/page")!,
                URL(string: "https://www.example.com/")!,
                URL(string: "https://api.v2.example.com/data")!,
            ]

            for url in urls {
                #expect(resolver.resolve(for: url) == .allow, "Expected \(url) to be allowed")
            }
        }

        @Test("Wildcard pattern also matches root domain")
        func wildcardMatchesRootDomain() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["*.example.com"]
            )

            let url = URL(string: "https://example.com/page")!
            #expect(resolver.resolve(for: url) == .allow)
        }

        @Test("Wildcard does not match unrelated domains")
        func wildcardDoesNotMatchUnrelatedDomains() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["*.example.com"]
            )

            let urls = [
                URL(string: "https://notexample.com/")!,
                URL(string: "https://example.org/")!,
                URL(string: "https://fakeexample.com/")!,
            ]

            for url in urls {
                #expect(resolver.resolve(for: url) == .external, "Expected \(url) to open externally")
            }
        }

        @Test("Multiple allowed origins work correctly")
        func multipleAllowedOriginsWork() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com", "app.example.org", "*.test.io"]
            )

            let allowedURLs = [
                URL(string: "https://example.com/page")!,
                URL(string: "https://app.example.org/dashboard")!,
                URL(string: "https://api.test.io/data")!,
            ]

            for url in allowedURLs {
                #expect(resolver.resolve(for: url) == .allow, "Expected \(url) to be allowed")
            }

            let externalURL = URL(string: "https://other.com/")!
            #expect(resolver.resolve(for: externalURL) == .external)
        }

        @Test("Path pattern matching works")
        func pathPatternMatchingWorks() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com/app/*"]
            )

            let allowedURLs = [
                URL(string: "https://example.com/app/page")!,
                URL(string: "https://example.com/app/sub/page")!,
                URL(string: "https://example.com/app/")!,
            ]

            for url in allowedURLs {
                #expect(resolver.resolve(for: url) == .allow, "Expected \(url) to be allowed")
            }

            let externalURLs = [
                URL(string: "https://example.com/other/page")!,
                URL(string: "https://example.com/")!,
            ]

            for url in externalURLs {
                #expect(resolver.resolve(for: url) == .external, "Expected \(url) to open externally")
            }
        }

        @Test("Case insensitive matching")
        func caseInsensitiveMatching() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["Example.COM"]
            )

            let url = URL(string: "https://EXAMPLE.com/page")!
            #expect(resolver.resolve(for: url) == .allow)
        }
    }

    // MARK: - Auth Origins Matching

    @Suite("Auth Origins")
    struct AuthOriginsTests {
        @Test("Auth origin shows toolbar")
        func authOriginShowsToolbar() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                authOrigins: ["accounts.google.com"]
            )

            let url = URL(string: "https://accounts.google.com/signin")!
            #expect(resolver.resolve(for: url) == .allowWithToolbar)
        }

        @Test("Multiple auth origins work")
        func multipleAuthOriginsWork() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                authOrigins: ["accounts.google.com", "auth0.com", "*.okta.com"]
            )

            let authURLs = [
                URL(string: "https://accounts.google.com/signin")!,
                URL(string: "https://auth0.com/authorize")!,
                URL(string: "https://dev-123.okta.com/login")!,
            ]

            for url in authURLs {
                #expect(resolver.resolve(for: url) == .allowWithToolbar, "Expected \(url) to show toolbar")
            }
        }

        @Test("Auth origin with wildcard subdomain")
        func authOriginWithWildcardSubdomain() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                authOrigins: ["*.auth0.com"]
            )

            let url = URL(string: "https://myapp.auth0.com/authorize")!
            #expect(resolver.resolve(for: url) == .allowWithToolbar)
        }
    }

    // MARK: - External URL Detection

    @Suite("External URLs")
    struct ExternalURLTests {
        @Test("External origin opens externally")
        func externalOriginOpensExternally() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                externalOrigins: ["external.com"]
            )

            let url = URL(string: "https://external.com/page")!
            #expect(resolver.resolve(for: url) == .external)
        }

        @Test("External takes precedence over allowed")
        func externalTakesPrecedence() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["*.example.com"],
                externalOrigins: ["docs.example.com"]
            )

            let url = URL(string: "https://docs.example.com/help")!
            #expect(resolver.resolve(for: url) == .external)

            let allowedUrl = URL(string: "https://app.example.com/")!
            #expect(resolver.resolve(for: allowedUrl) == .allow)
        }

        @Test("External takes precedence over auth")
        func externalTakesPrecedenceOverAuth() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                authOrigins: ["auth.example.com"],
                externalOrigins: ["auth.example.com/external/*"]
            )

            let externalUrl = URL(string: "https://auth.example.com/external/link")!
            #expect(resolver.resolve(for: externalUrl) == .external)

            let authUrl = URL(string: "https://auth.example.com/login")!
            #expect(resolver.resolve(for: authUrl) == .allowWithToolbar)
        }

        @Test("Unrecognized URLs open externally by default")
        func unrecognizedURLsOpenExternally() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://random-site.com/page")!
            #expect(resolver.resolve(for: url) == .external)
        }
    }

    // MARK: - System URL Schemes

    @Suite("System URL Schemes")
    struct SystemURLTests {
        @Test("Tel scheme is handled by system")
        func telSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "tel:+1234567890")!
            #expect(resolver.resolve(for: url) == .system)
        }

        @Test("Mailto scheme is handled by system")
        func mailtoSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "mailto:test@example.com")!
            #expect(resolver.resolve(for: url) == .system)
        }

        @Test("SMS scheme is handled by system")
        func smsSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "sms:+1234567890")!
            #expect(resolver.resolve(for: url) == .system)
        }

        @Test("FaceTime scheme is handled by system")
        func facetimeSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let urls = [
                URL(string: "facetime:+1234567890")!,
                URL(string: "facetime-audio:+1234567890")!,
            ]

            for url in urls {
                #expect(resolver.resolve(for: url) == .system, "Expected \(url) to be system")
            }
        }

        @Test("Maps scheme is handled by system")
        func mapsSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "maps://?q=Apple+Park")!
            #expect(resolver.resolve(for: url) == .system)
        }

        @Test("App Store scheme is handled by system")
        func appStoreSchemeIsSystem() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let urls = [
                URL(string: "itms-apps://apps.apple.com/app/id123456789")!,
                URL(string: "itms-appss://apps.apple.com/app/id123456789")!,
            ]

            for url in urls {
                #expect(resolver.resolve(for: url) == .system, "Expected \(url) to be system")
            }
        }

        @Test("Unknown scheme opens externally")
        func unknownSchemeOpensExternally() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "customapp://action")!
            #expect(resolver.resolve(for: url) == .external)
        }
    }

    // MARK: - Origins Configuration Integration

    @Suite("OriginsConfiguration Integration")
    struct OriginsConfigurationTests {
        @Test("Resolver can be created from OriginsConfiguration")
        func resolverFromOriginsConfiguration() {
            let origins = OriginsConfiguration(
                allowed: ["example.com", "*.app.io"],
                auth: ["accounts.google.com"],
                external: ["external.com"]
            )

            let resolver = NavigationPolicyResolver(origins: origins)

            #expect(resolver.resolve(for: URL(string: "https://example.com/")!) == .allow)
            #expect(resolver.resolve(for: URL(string: "https://api.app.io/")!) == .allow)
            #expect(resolver.resolve(for: URL(string: "https://accounts.google.com/")!) == .allowWithToolbar)
            #expect(resolver.resolve(for: URL(string: "https://external.com/")!) == .external)
            #expect(resolver.resolve(for: URL(string: "https://random.com/")!) == .external)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCasesTests {
        @Test("Empty path defaults to root")
        func emptyPathDefaultsToRoot() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com/app/*"]
            )

            // URL with no explicit path
            let url = URL(string: "https://example.com")!
            #expect(resolver.resolve(for: url) == .external)
        }

        @Test("URL without host opens externally")
        func urlWithoutHostOpensExternally() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            // File URLs and similar don't have a host in the traditional sense
            let url = URL(string: "file:///Users/test/file.txt")!
            #expect(resolver.resolve(for: url) == .external)
        }

        @Test("HTTP URLs are handled same as HTTPS")
        func httpUrlsHandledSameAsHttps() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )

            let httpUrl = URL(string: "http://example.com/page")!
            let httpsUrl = URL(string: "https://example.com/page")!

            #expect(resolver.resolve(for: httpUrl) == .allow)
            #expect(resolver.resolve(for: httpsUrl) == .allow)
        }
    }
}
