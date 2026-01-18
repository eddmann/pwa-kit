import Foundation
import SafariServices
import UIKit
import WebKit

// MARK: - NavigationDelegate

/// WKNavigationDelegate implementation for applying navigation policies.
///
/// `NavigationDelegate` uses `NavigationPolicyResolver` to determine how URLs should be handled:
/// - Allowed URLs are loaded within the WebView
/// - Auth URLs are loaded with a "Done" toolbar for OAuth flows
/// - External URLs are opened in SFSafariViewController
/// - System URLs (tel:, mailto:, etc.) are passed to the system
///
/// ## Usage
///
/// ```swift
/// let delegate = NavigationDelegate(
///     policyResolver: NavigationPolicyResolver(
///         allowedOrigins: ["app.example.com"],
///         authOrigins: ["accounts.google.com"]
///     )
/// )
/// delegate.viewController = myViewController
/// webView.navigationDelegate = delegate
/// ```
///
/// ## Auth Origins Toolbar
///
/// When navigating to an auth origin, the delegate displays a toolbar with a "Done" button.
/// When the user taps "Done", the WebView navigates back to the start URL.
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated since all WKNavigationDelegate methods and
/// UI presentations must occur on the main thread.
@MainActor
public final class NavigationDelegate: NSObject {
    /// The policy resolver for determining navigation behavior.
    private let policyResolver: NavigationPolicyResolver

    /// The start URL to return to when dismissing auth flows.
    private let startURL: URL

    /// The view controller used to present external browsers and toolbars.
    ///
    /// This must be set to a valid view controller for external URLs to be opened
    /// and for auth toolbars to be displayed.
    public weak var viewController: UIViewController?

    /// The web view being managed (set after navigation starts).
    public weak var webView: WKWebView?

    /// The toolbar view for auth origins (created lazily).
    private var authToolbar: UIToolbar?

    /// Whether the auth toolbar is currently visible.
    private var isAuthToolbarVisible = false

    /// Callback when navigation starts.
    public var onNavigationStarted: (() -> Void)?

    /// Callback when navigation finishes.
    public var onNavigationFinished: (() -> Void)?

    /// Callback when navigation fails.
    public var onNavigationFailed: ((Error) -> Void)?

    /// Creates a new navigation delegate.
    ///
    /// - Parameters:
    ///   - policyResolver: The resolver for navigation policies.
    ///   - startURL: The URL to return to when dismissing auth flows.
    ///   - viewController: The view controller for presenting UI.
    public init(
        policyResolver: NavigationPolicyResolver,
        startURL: URL,
        viewController: UIViewController? = nil
    ) {
        self.policyResolver = policyResolver
        self.startURL = startURL
        self.viewController = viewController
        super.init()
    }

    /// Creates a navigation delegate from a WebView configuration.
    ///
    /// - Parameters:
    ///   - configuration: The WebView configuration.
    ///   - viewController: The view controller for presenting UI.
    public convenience init(
        configuration: WebViewConfiguration,
        viewController: UIViewController? = nil
    ) {
        let resolver = NavigationPolicyResolver(
            allowedOrigins: configuration.allowedOrigins,
            authOrigins: configuration.authOrigins,
            externalOrigins: []
        )
        self.init(
            policyResolver: resolver,
            startURL: configuration.startURL,
            viewController: viewController
        )
    }

    /// Creates a navigation delegate from an origins configuration.
    ///
    /// - Parameters:
    ///   - origins: The origins configuration.
    ///   - startURL: The URL to return to when dismissing auth flows.
    ///   - viewController: The view controller for presenting UI.
    public convenience init(
        origins: OriginsConfiguration,
        startURL: URL,
        viewController: UIViewController? = nil
    ) {
        let resolver = NavigationPolicyResolver(origins: origins)
        self.init(
            policyResolver: resolver,
            startURL: startURL,
            viewController: viewController
        )
    }

    // MARK: - Auth Toolbar Management

    /// Shows the auth toolbar at the top of the WebView.
    private func showAuthToolbar() {
        guard !isAuthToolbarVisible, let webView else {
            return
        }

        let toolbar = makeAuthToolbar(width: webView.bounds.width)
        webView.superview?.addSubview(toolbar)

        // Position toolbar at top of webview
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: webView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
        ])

        // Adjust webview content inset
        webView.scrollView.contentInset.top = toolbar.bounds.height

        authToolbar = toolbar
        isAuthToolbarVisible = true
    }

    /// Hides the auth toolbar.
    private func hideAuthToolbar() {
        guard isAuthToolbarVisible else {
            return
        }

        authToolbar?.removeFromSuperview()
        authToolbar = nil
        webView?.scrollView.contentInset.top = 0
        isAuthToolbarVisible = false
    }

    /// Creates the auth toolbar with a "Done" button.
    private func makeAuthToolbar(width: CGFloat) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: width, height: 44))
        toolbar.barTintColor = .systemBackground

        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let doneButton = UIBarButtonItem(
            title: NSLocalizedString("Done", comment: "Auth toolbar Done button"),
            style: .done,
            target: self,
            action: #selector(authToolbarDoneTapped)
        )

        toolbar.items = [flexibleSpace, doneButton]
        return toolbar
    }

    /// Called when the "Done" button is tapped on the auth toolbar.
    @objc private func authToolbarDoneTapped() {
        hideAuthToolbar()
        webView?.load(URLRequest(url: startURL))
    }

    // MARK: - External Navigation

    /// Opens a URL in SFSafariViewController.
    ///
    /// - Parameter url: The URL to open.
    private func openInSafariViewController(_ url: URL) {
        guard let presenter = viewController else {
            // Fallback to system handler if no presenter
            openWithSystemHandler(url)
            return
        }

        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue
        presenter.present(safariVC, animated: true)
    }

    /// Opens a URL using the system handler (for tel:, mailto:, etc.).
    ///
    /// - Parameter url: The URL to open.
    private func openWithSystemHandler(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    // MARK: - Policy Updates

    /// Updates the toolbar visibility based on the current URL.
    ///
    /// Call this when the WebView URL changes to show/hide the auth toolbar.
    private func updateAuthToolbarVisibility(for url: URL?) {
        guard let url else {
            hideAuthToolbar()
            return
        }

        let policy = policyResolver.resolve(for: url)
        if policy == .allowWithToolbar {
            showAuthToolbar()
        } else {
            hideAuthToolbar()
        }
    }
}

// MARK: WKNavigationDelegate

extension NavigationDelegate: WKNavigationDelegate {
    /// Determines the navigation policy for a navigation action.
    ///
    /// This method applies the `NavigationPolicyResolver` to decide whether to:
    /// - Allow the navigation within the WebView
    /// - Cancel and open externally in SFSafariViewController
    /// - Cancel and open with the system handler (tel:, mailto:, etc.)
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        self.webView = webView

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let policy = policyResolver.resolve(for: url)

        switch policy {
        case .allow:
            hideAuthToolbar()
            decisionHandler(.allow)

        case .allowWithToolbar:
            showAuthToolbar()
            decisionHandler(.allow)

        case .external:
            decisionHandler(.cancel)
            openInSafariViewController(url)

        case .system:
            decisionHandler(.cancel)
            openWithSystemHandler(url)

        case .cancel:
            decisionHandler(.cancel)
        }
    }

    /// Handles the start of a provisional navigation.
    public func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation _: WKNavigation!
    ) {
        self.webView = webView
        onNavigationStarted?()
    }

    /// Handles successful completion of a navigation.
    public func webView(
        _ webView: WKWebView,
        didFinish _: WKNavigation!
    ) {
        // Update toolbar visibility based on final URL
        updateAuthToolbarVisibility(for: webView.url)
        onNavigationFinished?()
    }

    /// Handles navigation failure after the response has been received.
    public func webView(
        _: WKWebView,
        didFail _: WKNavigation!,
        withError error: Error
    ) {
        onNavigationFailed?(error)
    }

    /// Handles navigation failure during the initial loading phase.
    public func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        // Ignore cancelled navigations (e.g., user tapped a link while loading)
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled {
            return
        }

        onNavigationFailed?(error)
    }

    /// Handles server redirects.
    public func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation _: WKNavigation!
    ) {
        // Update toolbar visibility in case redirect goes to auth origin
        updateAuthToolbarVisibility(for: webView.url)
    }
}
