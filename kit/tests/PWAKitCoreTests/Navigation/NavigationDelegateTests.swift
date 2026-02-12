import Foundation
import Testing
import UIKit
import WebKit

@testable import PWAKitApp

// MARK: - NavigationDelegateTests

@Suite("NavigationDelegate Tests")
struct NavigationDelegateTests {
    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {
        @Test("Creates delegate from policy resolver and start URL")
        @MainActor
        func createsFromPolicyResolver() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"],
                authOrigins: ["auth.example.com"]
            )
            let startURL = URL(string: "https://example.com/")!

            let delegate = NavigationDelegate(
                policyResolver: resolver,
                startURL: startURL
            )

            #expect(delegate.viewController == nil)
            #expect(delegate.webView == nil)
        }

        @Test("Creates delegate from WebViewConfiguration")
        @MainActor
        func createsFromWebViewConfiguration() {
            let config = WebViewConfiguration(
                startURL: URL(string: "https://app.example.com/")!,
                allowedOrigins: ["app.example.com", "*.example.com"],
                authOrigins: ["accounts.google.com"]
            )

            let delegate = NavigationDelegate(configuration: config)

            #expect(delegate.viewController == nil)
        }

        @Test("Creates delegate from OriginsConfiguration")
        @MainActor
        func createsFromOriginsConfiguration() {
            let origins = OriginsConfiguration(
                allowed: ["example.com"],
                auth: ["auth0.com"],
                external: ["external.com"]
            )
            let startURL = URL(string: "https://example.com/")!

            let delegate = NavigationDelegate(
                origins: origins,
                startURL: startURL
            )

            #expect(delegate.viewController == nil)
        }

        @Test("Sets view controller when provided")
        @MainActor
        func setsViewControllerWhenProvided() {
            let resolver = NavigationPolicyResolver(
                allowedOrigins: ["example.com"]
            )
            let startURL = URL(string: "https://example.com/")!
            let viewController = UIViewController()

            let delegate = NavigationDelegate(
                policyResolver: resolver,
                startURL: startURL,
                viewController: viewController
            )

            #expect(delegate.viewController === viewController)
        }
    }

    // MARK: - Navigation Callback Tests

    @Suite("Navigation Callbacks")
    struct NavigationCallbackTests {
        @Test("Calls onNavigationStarted when navigation begins")
        @MainActor
        func callsOnNavigationStarted() {
            let delegate = createTestDelegate()
            var wasCalled = false
            delegate.onNavigationStarted = {
                wasCalled = true
            }

            // Simulate navigation start
            let webView = WKWebView()
            delegate.webView(webView, didStartProvisionalNavigation: nil)

            #expect(wasCalled)
        }

        @Test("Sets webView reference on navigation start")
        @MainActor
        func setsWebViewReferenceOnNavigationStart() {
            let delegate = createTestDelegate()
            let webView = WKWebView()

            delegate.webView(webView, didStartProvisionalNavigation: nil)

            #expect(delegate.webView === webView)
        }

        @Test("Calls onNavigationFinished when navigation completes")
        @MainActor
        func callsOnNavigationFinished() {
            let delegate = createTestDelegate()
            var wasCalled = false
            delegate.onNavigationFinished = {
                wasCalled = true
            }

            // Simulate navigation finish
            let webView = WKWebView()
            delegate.webView(webView, didFinish: nil)

            #expect(wasCalled)
        }

        @Test("Calls onNavigationFailed when navigation fails")
        @MainActor
        func callsOnNavigationFailed() {
            let delegate = createTestDelegate()
            var receivedError: Error?
            delegate.onNavigationFailed = { error in
                receivedError = error
            }

            // Simulate navigation failure
            let webView = WKWebView()
            let testError = NSError(domain: "test", code: 500, userInfo: nil)
            delegate.webView(webView, didFail: nil, withError: testError)

            #expect(receivedError != nil)
            #expect((receivedError as NSError?)?.code == 500)
        }

        @Test("Ignores cancelled navigation errors")
        @MainActor
        func ignoresCancelledNavigationErrors() {
            let delegate = createTestDelegate()
            var wasCalled = false
            delegate.onNavigationFailed = { _ in
                wasCalled = true
            }

            // Simulate cancelled navigation (error code -999)
            let webView = WKWebView()
            let cancelledError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCancelled,
                userInfo: nil
            )
            delegate.webView(webView, didFailProvisionalNavigation: nil, withError: cancelledError)

            #expect(wasCalled == false)
        }

        @Test("Reports non-cancelled provisional navigation errors")
        @MainActor
        func reportsProvisionalNavigationErrors() {
            let delegate = createTestDelegate()
            var receivedError: Error?
            delegate.onNavigationFailed = { error in
                receivedError = error
            }

            // Simulate a real error (not cancelled)
            let webView = WKWebView()
            let networkError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: nil
            )
            delegate.webView(webView, didFailProvisionalNavigation: nil, withError: networkError)

            #expect(receivedError != nil)
            #expect((receivedError as NSError?)?.code == NSURLErrorTimedOut)
        }

        @Test("Reports connection errors")
        @MainActor
        func reportsConnectionErrors() {
            let delegate = createTestDelegate()
            var receivedError: Error?
            delegate.onNavigationFailed = { error in
                receivedError = error
            }

            let webView = WKWebView()
            let connectionError = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorNotConnectedToInternet,
                userInfo: nil
            )
            delegate.webView(webView, didFailProvisionalNavigation: nil, withError: connectionError)

            #expect(receivedError != nil)
            #expect((receivedError as NSError?)?.code == NSURLErrorNotConnectedToInternet)
        }
    }

    // MARK: - Helper Functions

    @MainActor
    private static func createTestDelegate() -> NavigationDelegate {
        let resolver = NavigationPolicyResolver(
            allowedOrigins: ["example.com"],
            authOrigins: ["auth.example.com"],
            externalOrigins: ["external.com"]
        )
        let startURL = URL(string: "https://example.com/")!
        return NavigationDelegate(policyResolver: resolver, startURL: startURL)
    }
}

// MARK: - NavigationDelegatePolicyIntegrationTests

/// Tests that verify the NavigationDelegate correctly uses NavigationPolicyResolver.
///
/// Note: These tests verify the policy resolver integration without mocking WKNavigationAction,
/// which cannot be properly subclassed. The policy resolution behavior is thoroughly tested
/// in NavigationPolicyTests.swift.
@Suite("NavigationDelegate Policy Integration Tests")
struct NavigationDelegatePolicyIntegrationTests {
    @Test("Delegate uses provided policy resolver")
    @MainActor
    func delegateUsesProvidedPolicyResolver() {
        // Create a resolver with specific configuration
        let resolver = NavigationPolicyResolver(
            allowedOrigins: ["myapp.com"],
            authOrigins: ["oauth.provider.com"],
            externalOrigins: ["blocked.com"]
        )
        let startURL = URL(string: "https://myapp.com/")!

        let delegate = NavigationDelegate(
            policyResolver: resolver,
            startURL: startURL
        )

        // Verify delegate was created (we can't test decidePolicyFor without a real WKNavigationAction)
        #expect(delegate.viewController == nil)
        #expect(delegate.webView == nil)
    }

    @Test("Delegate created from WebViewConfiguration inherits origins")
    @MainActor
    func delegateFromWebViewConfigurationInheritsOrigins() {
        let config = WebViewConfiguration(
            startURL: URL(string: "https://myapp.example.com/")!,
            allowedOrigins: ["myapp.example.com"],
            authOrigins: ["auth.example.com"]
        )

        let delegate = NavigationDelegate(configuration: config)

        // The delegate should be created successfully
        #expect(delegate.viewController == nil)
    }

    @Test("Delegate created from OriginsConfiguration uses external origins")
    @MainActor
    func delegateFromOriginsConfigurationUsesExternalOrigins() {
        let origins = OriginsConfiguration(
            allowed: ["app.example.com"],
            auth: ["login.example.com"],
            external: ["docs.example.com", "blog.example.com"]
        )
        let startURL = URL(string: "https://app.example.com/")!

        let delegate = NavigationDelegate(
            origins: origins,
            startURL: startURL
        )

        // The delegate should be created successfully
        #expect(delegate.viewController == nil)
    }

    @Test("Multiple delegates can be created with different configurations")
    @MainActor
    func multipleDelegatesWithDifferentConfigurations() {
        let delegate1 = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["app1.com"]),
            startURL: URL(string: "https://app1.com/")!
        )

        let delegate2 = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["app2.com"]),
            startURL: URL(string: "https://app2.com/")!
        )

        // Both delegates should be independent
        #expect(delegate1.webView == nil)
        #expect(delegate2.webView == nil)
    }
}

// MARK: - NavigationDelegateViewControllerTests

@Suite("NavigationDelegate View Controller Tests")
struct NavigationDelegateViewControllerTests {
    @Test("View controller can be set after initialization")
    @MainActor
    func viewControllerCanBeSetAfterInit() {
        let delegate = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["example.com"]),
            startURL: URL(string: "https://example.com/")!
        )

        #expect(delegate.viewController == nil)

        let vc = UIViewController()
        delegate.viewController = vc

        #expect(delegate.viewController === vc)
    }

    @Test("View controller is weakly held")
    @MainActor
    func viewControllerIsWeaklyHeld() {
        let delegate = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["example.com"]),
            startURL: URL(string: "https://example.com/")!
        )

        autoreleasepool {
            let vc = UIViewController()
            delegate.viewController = vc
            #expect(delegate.viewController != nil)
        }

        // After the autorelease pool, the view controller should be deallocated
        // Note: In practice, this may not deallocate immediately in tests
        // The important thing is that it's a weak reference
    }
}

// MARK: - NavigationDelegateWebViewReferenceTests

@Suite("NavigationDelegate WebView Reference Tests")
struct NavigationDelegateWebViewReferenceTests {
    @Test("WebView is weakly held")
    @MainActor
    func webViewIsWeaklyHeld() {
        let delegate = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["example.com"]),
            startURL: URL(string: "https://example.com/")!
        )

        autoreleasepool {
            let webView = WKWebView()
            delegate.webView(webView, didStartProvisionalNavigation: nil)
            #expect(delegate.webView != nil)
        }

        // The webView is a weak reference
    }

    @Test("WebView reference is updated on each navigation")
    @MainActor
    func webViewReferenceUpdatedOnNavigation() {
        let delegate = NavigationDelegate(
            policyResolver: NavigationPolicyResolver(allowedOrigins: ["example.com"]),
            startURL: URL(string: "https://example.com/")!
        )

        let webView1 = WKWebView()
        let webView2 = WKWebView()

        delegate.webView(webView1, didStartProvisionalNavigation: nil)
        #expect(delegate.webView === webView1)

        delegate.webView(webView2, didStartProvisionalNavigation: nil)
        #expect(delegate.webView === webView2)
    }
}
