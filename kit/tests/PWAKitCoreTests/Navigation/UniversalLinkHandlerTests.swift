import Foundation
@testable import PWAKitApp
import Testing

@Suite("UniversalLinkHandler Tests")
struct UniversalLinkHandlerTests {
    // MARK: - URL Handling

    @Suite("URL Handling")
    struct URLHandlingTests {
        @Test("Can handle HTTPS URLs matching allowed origins")
        @MainActor
        func canHandleAllowedOrigins() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com", "app.example.org"]
            )

            let urls = try [
                #require(URL(string: "https://example.com/page")),
                #require(URL(string: "https://example.com/path/to/resource")),
                #require(URL(string: "https://app.example.org/dashboard")),
            ]

            for url in urls {
                #expect(handler.canHandle(url: url), "Expected \(url) to be handleable")
            }
        }

        @Test("Cannot handle non-HTTPS URLs")
        @MainActor
        func cannotHandleNonHttpsUrls() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let urls = try [
                #require(URL(string: "http://example.com/page")),
                #require(URL(string: "ftp://example.com/file")),
                #require(URL(string: "file:///Users/test/file.txt")),
            ]

            for url in urls {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Cannot handle URLs not matching allowed origins")
        @MainActor
        func cannotHandleNonMatchingUrls() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let urls = try [
                #require(URL(string: "https://other.com/page")),
                #require(URL(string: "https://notexample.com/")),
                #require(URL(string: "https://example.org/")),
            ]

            for url in urls {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Wildcard subdomain matching works")
        @MainActor
        func wildcardSubdomainMatching() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["*.example.com"]
            )

            let matchingURLs = try [
                #require(URL(string: "https://example.com/page")),
                #require(URL(string: "https://app.example.com/dashboard")),
                #require(URL(string: "https://api.v2.example.com/data")),
                #require(URL(string: "https://www.example.com/")),
            ]

            for url in matchingURLs {
                #expect(handler.canHandle(url: url), "Expected \(url) to be handleable")
            }

            let nonMatchingURLs = try [
                #require(URL(string: "https://notexample.com/")),
                #require(URL(string: "https://example.org/")),
                #require(URL(string: "https://fakeexample.com/")),
            ]

            for url in nonMatchingURLs {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Case insensitive matching")
        @MainActor
        func caseInsensitiveMatching() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["Example.COM"]
            )

            let url = try #require(URL(string: "https://EXAMPLE.com/page"))
            #expect(handler.canHandle(url: url))
        }
    }

    // MARK: - Pending Link Management

    @Suite("Pending Link Management")
    struct PendingLinkTests {
        @Test("Setting and consuming pending link")
        @MainActor
        func setAndConsumePendingLink() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = try #require(URL(string: "https://example.com/page"))
            handler.setPendingLink(url)

            #expect(handler.hasPendingLink)
            #expect(handler.peekPendingLink() == url)
            #expect(handler.hasPendingLink) // Peek should not consume

            let consumed = handler.consumePendingLink()
            #expect(consumed == url)
            #expect(!handler.hasPendingLink)
            #expect(handler.peekPendingLink() == nil)
        }

        @Test("Consuming returns nil when no pending link")
        @MainActor
        func consumeReturnsNilWhenEmpty() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            #expect(handler.consumePendingLink() == nil)
            #expect(!handler.hasPendingLink)
        }

        @Test("Setting new link replaces existing")
        @MainActor
        func settingNewLinkReplaces() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let firstURL = try #require(URL(string: "https://example.com/first"))
            let secondURL = try #require(URL(string: "https://example.com/second"))

            handler.setPendingLink(firstURL)
            handler.setPendingLink(secondURL)

            let consumed = handler.consumePendingLink()
            #expect(consumed == secondURL)
        }

        @Test("Clearing pending link")
        @MainActor
        func clearPendingLink() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = try #require(URL(string: "https://example.com/page"))
            handler.setPendingLink(url)

            #expect(handler.hasPendingLink)
            handler.clearPendingLink()
            #expect(!handler.hasPendingLink)
            #expect(handler.consumePendingLink() == nil)
        }

        @Test("Callback invoked when pending link is set")
        @MainActor
        func callbackInvokedOnSet() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            var callbackURL: URL?
            handler.onPendingLinkSet = { url in
                callbackURL = url
            }

            let url = try #require(URL(string: "https://example.com/page"))
            handler.setPendingLink(url)

            #expect(callbackURL == url)
        }
    }

    // MARK: - User Activity Handling

    @Suite("User Activity Handling")
    struct UserActivityTests {
        @Test("Handles browsing web activity with valid URL")
        @MainActor
        func handlesBrowsingWebActivity() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            activity.webpageURL = try #require(URL(string: "https://example.com/page"))

            let handled = handler.handleUserActivity(activity)
            #expect(handled)
            #expect(handler.hasPendingLink)
            #expect(handler.peekPendingLink() == activity.webpageURL)
        }

        @Test("Does not handle non-browsing activities")
        @MainActor
        func doesNotHandleNonBrowsingActivities() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: "com.example.custom")
            activity.webpageURL = try #require(URL(string: "https://example.com/page"))

            let handled = handler.handleUserActivity(activity)
            #expect(!handled)
            #expect(!handler.hasPendingLink)
        }

        @Test("Does not handle activity without webpage URL")
        @MainActor
        func doesNotHandleActivityWithoutURL() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            // No webpageURL set

            let handled = handler.handleUserActivity(activity)
            #expect(!handled)
            #expect(!handler.hasPendingLink)
        }

        @Test("Does not handle activity with non-matching URL")
        @MainActor
        func doesNotHandleNonMatchingURL() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            activity.webpageURL = try #require(URL(string: "https://other.com/page"))

            let handled = handler.handleUserActivity(activity)
            #expect(!handled)
            #expect(!handler.hasPendingLink)
        }
    }

    // MARK: - OriginsConfiguration Integration

    @Suite("OriginsConfiguration Integration")
    struct OriginsConfigurationTests {
        @Test("Handler can be created from OriginsConfiguration")
        @MainActor
        func handlerFromOriginsConfiguration() throws {
            let origins = OriginsConfiguration(
                allowed: ["example.com", "*.app.io"],
                auth: ["accounts.google.com"],
                external: ["external.com"]
            )

            let handler = UniversalLinkHandler(origins: origins)

            // Should handle allowed origins
            #expect(try handler.canHandle(url: #require(URL(string: "https://example.com/"))))
            #expect(try handler.canHandle(url: #require(URL(string: "https://api.app.io/"))))

            // Should not handle auth/external origins (they use allowed origins only)
            #expect(try !handler.canHandle(url: #require(URL(string: "https://accounts.google.com/"))))
            #expect(try !handler.canHandle(url: #require(URL(string: "https://external.com/"))))
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        @Test("Handles URL with path pattern in allowed origins")
        @MainActor
        func handlesPathPatternInAllowedOrigins() throws {
            // Path patterns in allowed origins should still match the domain
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com/app/*"]
            )

            // Domain matching should still work
            let url = try #require(URL(string: "https://example.com/other/page"))
            #expect(handler.canHandle(url: url))
        }

        @Test("Handles URL without path")
        @MainActor
        func handlesURLWithoutPath() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = try #require(URL(string: "https://example.com"))
            #expect(handler.canHandle(url: url))
        }

        @Test("Multiple consume calls return nil after first")
        @MainActor
        func multipleConsumeCallsReturnNil() throws {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = try #require(URL(string: "https://example.com/page"))
            handler.setPendingLink(url)

            _ = handler.consumePendingLink()
            #expect(handler.consumePendingLink() == nil)
            #expect(handler.consumePendingLink() == nil)
        }
    }
}
