import Foundation
import Testing

@testable import PWAKitApp

@Suite("UniversalLinkHandler Tests")
struct UniversalLinkHandlerTests {
    // MARK: - URL Handling

    @Suite("URL Handling")
    struct URLHandlingTests {
        @Test("Can handle HTTPS URLs matching allowed origins")
        @MainActor
        func canHandleAllowedOrigins() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com", "app.example.org"]
            )

            let urls = [
                URL(string: "https://example.com/page")!,
                URL(string: "https://example.com/path/to/resource")!,
                URL(string: "https://app.example.org/dashboard")!,
            ]

            for url in urls {
                #expect(handler.canHandle(url: url), "Expected \(url) to be handleable")
            }
        }

        @Test("Cannot handle non-HTTPS URLs")
        @MainActor
        func cannotHandleNonHttpsUrls() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let urls = [
                URL(string: "http://example.com/page")!,
                URL(string: "ftp://example.com/file")!,
                URL(string: "file:///Users/test/file.txt")!,
            ]

            for url in urls {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Cannot handle URLs not matching allowed origins")
        @MainActor
        func cannotHandleNonMatchingUrls() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let urls = [
                URL(string: "https://other.com/page")!,
                URL(string: "https://notexample.com/")!,
                URL(string: "https://example.org/")!,
            ]

            for url in urls {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Wildcard subdomain matching works")
        @MainActor
        func wildcardSubdomainMatching() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["*.example.com"]
            )

            let matchingURLs = [
                URL(string: "https://example.com/page")!,
                URL(string: "https://app.example.com/dashboard")!,
                URL(string: "https://api.v2.example.com/data")!,
                URL(string: "https://www.example.com/")!,
            ]

            for url in matchingURLs {
                #expect(handler.canHandle(url: url), "Expected \(url) to be handleable")
            }

            let nonMatchingURLs = [
                URL(string: "https://notexample.com/")!,
                URL(string: "https://example.org/")!,
                URL(string: "https://fakeexample.com/")!,
            ]

            for url in nonMatchingURLs {
                #expect(!handler.canHandle(url: url), "Expected \(url) to not be handleable")
            }
        }

        @Test("Case insensitive matching")
        @MainActor
        func caseInsensitiveMatching() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["Example.COM"]
            )

            let url = URL(string: "https://EXAMPLE.com/page")!
            #expect(handler.canHandle(url: url))
        }
    }

    // MARK: - Pending Link Management

    @Suite("Pending Link Management")
    struct PendingLinkTests {
        @Test("Setting and consuming pending link")
        @MainActor
        func setAndConsumePendingLink() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://example.com/page")!
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
        func settingNewLinkReplaces() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let firstURL = URL(string: "https://example.com/first")!
            let secondURL = URL(string: "https://example.com/second")!

            handler.setPendingLink(firstURL)
            handler.setPendingLink(secondURL)

            let consumed = handler.consumePendingLink()
            #expect(consumed == secondURL)
        }

        @Test("Clearing pending link")
        @MainActor
        func clearPendingLink() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://example.com/page")!
            handler.setPendingLink(url)

            #expect(handler.hasPendingLink)
            handler.clearPendingLink()
            #expect(!handler.hasPendingLink)
            #expect(handler.consumePendingLink() == nil)
        }

        @Test("Callback invoked when pending link is set")
        @MainActor
        func callbackInvokedOnSet() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            var callbackURL: URL?
            handler.onPendingLinkSet = { url in
                callbackURL = url
            }

            let url = URL(string: "https://example.com/page")!
            handler.setPendingLink(url)

            #expect(callbackURL == url)
        }
    }

    // MARK: - User Activity Handling

    @Suite("User Activity Handling")
    struct UserActivityTests {
        @Test("Handles browsing web activity with valid URL")
        @MainActor
        func handlesBrowsingWebActivity() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            activity.webpageURL = URL(string: "https://example.com/page")!

            let handled = handler.handleUserActivity(activity)
            #expect(handled)
            #expect(handler.hasPendingLink)
            #expect(handler.peekPendingLink() == activity.webpageURL)
        }

        @Test("Does not handle non-browsing activities")
        @MainActor
        func doesNotHandleNonBrowsingActivities() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: "com.example.custom")
            activity.webpageURL = URL(string: "https://example.com/page")!

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
        func doesNotHandleNonMatchingURL() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            activity.webpageURL = URL(string: "https://other.com/page")!

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
        func handlerFromOriginsConfiguration() {
            let origins = OriginsConfiguration(
                allowed: ["example.com", "*.app.io"],
                auth: ["accounts.google.com"],
                external: ["external.com"]
            )

            let handler = UniversalLinkHandler(origins: origins)

            // Should handle allowed origins
            #expect(handler.canHandle(url: URL(string: "https://example.com/")!))
            #expect(handler.canHandle(url: URL(string: "https://api.app.io/")!))

            // Should not handle auth/external origins (they use allowed origins only)
            #expect(!handler.canHandle(url: URL(string: "https://accounts.google.com/")!))
            #expect(!handler.canHandle(url: URL(string: "https://external.com/")!))
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        @Test("Handles URL with path pattern in allowed origins")
        @MainActor
        func handlesPathPatternInAllowedOrigins() {
            // Path patterns in allowed origins should still match the domain
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com/app/*"]
            )

            // Domain matching should still work
            let url = URL(string: "https://example.com/other/page")!
            #expect(handler.canHandle(url: url))
        }

        @Test("Handles URL without path")
        @MainActor
        func handlesURLWithoutPath() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://example.com")!
            #expect(handler.canHandle(url: url))
        }

        @Test("Multiple consume calls return nil after first")
        @MainActor
        func multipleConsumeCallsReturnNil() {
            let handler = UniversalLinkHandler(
                allowedOrigins: ["example.com"]
            )

            let url = URL(string: "https://example.com/page")!
            handler.setPendingLink(url)

            _ = handler.consumePendingLink()
            #expect(handler.consumePendingLink() == nil)
            #expect(handler.consumePendingLink() == nil)
        }
    }
}
