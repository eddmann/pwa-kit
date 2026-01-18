import Foundation
import Testing

@testable import PWAKitApp

@Suite("CustomSchemeHandler Tests")
struct CustomSchemeHandlerTests {
    // MARK: - Scheme Detection

    @Suite("Scheme Detection")
    struct SchemeDetectionTests {
        @Test("Detects custom scheme URLs")
        @MainActor
        func detectsCustomScheme() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let urls = [
                URL(string: "mypwa://")!,
                URL(string: "mypwa://dashboard")!,
                URL(string: "mypwa://path/to/page")!,
                URL(string: "mypwa://page?query=value")!,
            ]

            for url in urls {
                #expect(handler.isCustomScheme(url), "Expected \(url) to be custom scheme")
            }
        }

        @Test("Does not detect non-custom scheme URLs")
        @MainActor
        func doesNotDetectOtherSchemes() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let urls = [
                URL(string: "https://app.example.com/")!,
                URL(string: "http://example.com/page")!,
                URL(string: "otherscheme://path")!,
                URL(string: "file:///local/file.txt")!,
            ]

            for url in urls {
                #expect(!handler.isCustomScheme(url), "Expected \(url) to not be custom scheme")
            }
        }

        @Test("Case insensitive scheme matching")
        @MainActor
        func caseInsensitiveScheme() {
            let handler = CustomSchemeHandler(
                customScheme: "MyPWA",
                targetHost: "app.example.com"
            )

            let urls = [
                URL(string: "mypwa://path")!,
                URL(string: "MYPWA://path")!,
                URL(string: "MyPwa://path")!,
            ]

            for url in urls {
                #expect(handler.isCustomScheme(url), "Expected \(url) to be custom scheme")
            }
        }

        @Test("Scheme with :// suffix is normalized")
        @MainActor
        func schemeNormalization() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa://",
                targetHost: "app.example.com"
            )

            let url = URL(string: "mypwa://path")!
            #expect(handler.isCustomScheme(url))
            #expect(handler.scheme == "mypwa")
        }
    }

    // MARK: - URL Conversion

    @Suite("URL Conversion")
    struct URLConversionTests {
        @Test("Converts custom scheme to HTTPS")
        @MainActor
        func convertsToHTTPS() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://dashboard")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.scheme == "https")
            #expect(httpsURL?.host == "app.example.com")
            #expect(httpsURL?.path == "/dashboard")
        }

        @Test("Preserves path components")
        @MainActor
        func preservesPath() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://path/to/deep/page")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.absoluteString == "https://app.example.com/path/to/deep/page")
        }

        @Test("Preserves query parameters")
        @MainActor
        func preservesQuery() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://search?q=hello&page=1")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.scheme == "https")
            #expect(httpsURL?.host == "app.example.com")
            #expect(httpsURL?.path == "/search")
            #expect(httpsURL?.query == "q=hello&page=1")
        }

        @Test("Preserves fragment")
        @MainActor
        func preservesFragment() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://page#section")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.fragment == "section")
        }

        @Test("Returns nil for non-custom scheme URLs")
        @MainActor
        func returnsNilForOtherSchemes() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let httpsURL = URL(string: "https://example.com/page")!
            #expect(handler.convertToHTTPS(httpsURL) == nil)
        }

        @Test("Handles root URL")
        @MainActor
        func handlesRootURL() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.absoluteString == "https://app.example.com")
        }
    }

    // MARK: - Pending URL Management

    @Suite("Pending URL Management")
    struct PendingURLTests {
        @Test("Setting and consuming pending URL")
        @MainActor
        func setAndConsumePendingURL() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let url = URL(string: "https://app.example.com/page")!
            handler.setPendingURL(url)

            #expect(handler.hasPendingURL)
            #expect(handler.peekPendingURL() == url)
            #expect(handler.hasPendingURL) // Peek should not consume

            let consumed = handler.consumePendingURL()
            #expect(consumed == url)
            #expect(!handler.hasPendingURL)
            #expect(handler.peekPendingURL() == nil)
        }

        @Test("Consuming returns nil when no pending URL")
        @MainActor
        func consumeReturnsNilWhenEmpty() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            #expect(handler.consumePendingURL() == nil)
            #expect(!handler.hasPendingURL)
        }

        @Test("Setting new URL replaces existing")
        @MainActor
        func settingNewURLReplaces() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let firstURL = URL(string: "https://app.example.com/first")!
            let secondURL = URL(string: "https://app.example.com/second")!

            handler.setPendingURL(firstURL)
            handler.setPendingURL(secondURL)

            let consumed = handler.consumePendingURL()
            #expect(consumed == secondURL)
        }

        @Test("Clearing pending URL")
        @MainActor
        func clearPendingURL() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let url = URL(string: "https://app.example.com/page")!
            handler.setPendingURL(url)

            #expect(handler.hasPendingURL)
            handler.clearPendingURL()
            #expect(!handler.hasPendingURL)
            #expect(handler.consumePendingURL() == nil)
        }

        @Test("Callback invoked when pending URL is set")
        @MainActor
        func callbackInvokedOnSet() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            var callbackURL: URL?
            handler.onPendingURLSet = { url in
                callbackURL = url
            }

            let url = URL(string: "https://app.example.com/page")!
            handler.setPendingURL(url)

            #expect(callbackURL == url)
        }
    }

    // MARK: - URL Handling

    @Suite("URL Handling")
    struct URLHandlingTests {
        @Test("Handles custom scheme URL and sets pending")
        @MainActor
        func handlesAndSetsPending() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://dashboard")!
            let handled = handler.handleURL(customURL)

            #expect(handled)
            #expect(handler.hasPendingURL)
            #expect(handler.peekPendingURL()?.absoluteString == "https://app.example.com/dashboard")
        }

        @Test("Does not handle non-custom scheme URLs")
        @MainActor
        func doesNotHandleOtherSchemes() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let httpsURL = URL(string: "https://example.com/page")!
            let handled = handler.handleURL(httpsURL)

            #expect(!handled)
            #expect(!handler.hasPendingURL)
        }
    }

    // MARK: - AppConfiguration Integration

    @Suite("AppConfiguration Integration")
    struct AppConfigurationTests {
        @Test("Handler can be created from AppConfiguration")
        @MainActor
        func handlerFromAppConfiguration() {
            let appConfig = AppConfiguration(
                name: "My PWA",
                bundleId: "com.example.mypwa",
                startUrl: "https://app.example.com/"
            )

            let handler = CustomSchemeHandler(appConfig: appConfig)

            #expect(handler != nil)
            #expect(handler?.scheme == "mypwa")
            #expect(handler?.host == "app.example.com")
        }

        @Test("Returns nil for invalid start URL")
        @MainActor
        func returnsNilForInvalidStartURL() {
            let appConfig = AppConfiguration(
                name: "My PWA",
                bundleId: "com.example.mypwa",
                startUrl: "not-a-valid-url"
            )

            let handler = CustomSchemeHandler(appConfig: appConfig)

            #expect(handler == nil)
        }

        @Test("Uses last bundle ID component as scheme")
        @MainActor
        func usesLastBundleIdComponent() {
            let appConfig = AppConfiguration(
                name: "Test App",
                bundleId: "com.company.dept.myapp",
                startUrl: "https://myapp.example.com/"
            )

            let handler = CustomSchemeHandler(appConfig: appConfig)

            #expect(handler?.scheme == "myapp")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        @Test("Multiple consume calls return nil after first")
        @MainActor
        func multipleConsumeCallsReturnNil() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let url = URL(string: "https://app.example.com/page")!
            handler.setPendingURL(url)

            _ = handler.consumePendingURL()
            #expect(handler.consumePendingURL() == nil)
            #expect(handler.consumePendingURL() == nil)
        }

        @Test("Handles URL with complex query and fragment")
        @MainActor
        func handlesComplexURL() {
            let handler = CustomSchemeHandler(
                customScheme: "mypwa",
                targetHost: "app.example.com"
            )

            let customURL = URL(string: "mypwa://search?q=hello%20world&filter=active&sort=date#results")!
            let httpsURL = handler.convertToHTTPS(customURL)

            #expect(httpsURL?.scheme == "https")
            #expect(httpsURL?.host == "app.example.com")
            #expect(httpsURL?.path == "/search")
            // URL decodes %20 to space, check for decoded value
            #expect(httpsURL?.query?.contains("q=hello") == true)
            #expect(httpsURL?.query?.contains("filter=active") == true)
            #expect(httpsURL?.fragment == "results")
        }

        @Test("Properties return correct values")
        @MainActor
        func propertiesReturnCorrectValues() {
            let handler = CustomSchemeHandler(
                customScheme: "testscheme",
                targetHost: "test.example.com"
            )

            #expect(handler.scheme == "testscheme")
            #expect(handler.host == "test.example.com")
        }
    }
}
