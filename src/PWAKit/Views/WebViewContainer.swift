import SwiftUI
import UIKit
import WebKit

// MARK: - WebViewContainer

/// A SwiftUI view that wraps WKWebView for PWA content display.
///
/// `WebViewContainer` is a `UIViewRepresentable` that provides a complete
/// WKWebView integration for SwiftUI, including:
/// - Configuration injection for customizing WebView behavior
/// - Bridge dispatcher injection for JavaScript-to-Swift communication
/// - Coordinator for managing WKNavigationDelegate and WKUIDelegate callbacks
/// - Automatic message handler cleanup to prevent retain cycles
///
/// ## Usage
///
/// ```swift
/// struct ContentView: View {
///     @StateObject private var dispatcher = BridgeDispatcherWrapper()
///
///     var body: some View {
///         WebViewContainer(
///             configuration: webViewConfig,
///             dispatcher: dispatcher.dispatcher
///         )
///     }
/// }
/// ```
///
/// ## Configuration
///
/// The container accepts a `WebViewConfiguration` that controls:
/// - Start URL
/// - Allowed origins for JavaScript bridge access
/// - Display mode (standalone/fullscreen)
/// - Pull-to-refresh behavior
/// - Adaptive UI styling
public struct WebViewContainer: UIViewRepresentable {
    /// The configuration for the WebView.
    private let configuration: WebViewConfiguration

    /// The bridge dispatcher for handling JavaScript messages.
    private let dispatcher: BridgeDispatcher

    /// Callback invoked when the WebView is created.
    ///
    /// Use this to store a reference to the WebView for later use.
    private let onWebViewCreated: ((WKWebView) -> Void)?

    /// Callback invoked when navigation starts.
    private let onNavigationStarted: (() -> Void)?

    /// Callback invoked when navigation finishes.
    private let onNavigationFinished: (() -> Void)?

    /// Callback invoked when navigation fails.
    private let onNavigationFailed: ((Error) -> Void)?

    /// Callback invoked when loading progress changes.
    private let onProgressChanged: ((Double) -> Void)?

    /// Callback invoked when the URL changes.
    private let onURLChanged: ((URL?) -> Void)?

    /// Creates a new WebView container.
    ///
    /// - Parameters:
    ///   - configuration: The WebView configuration.
    ///   - dispatcher: The bridge dispatcher for JavaScript communication.
    ///   - onWebViewCreated: Optional callback when the WebView is created.
    ///   - onNavigationStarted: Optional callback when navigation starts.
    ///   - onNavigationFinished: Optional callback when navigation finishes.
    ///   - onNavigationFailed: Optional callback when navigation fails.
    ///   - onProgressChanged: Optional callback when loading progress changes.
    ///   - onURLChanged: Optional callback when the URL changes.
    public init(
        configuration: WebViewConfiguration,
        dispatcher: BridgeDispatcher,
        onWebViewCreated: ((WKWebView) -> Void)? = nil,
        onNavigationStarted: (() -> Void)? = nil,
        onNavigationFinished: (() -> Void)? = nil,
        onNavigationFailed: ((Error) -> Void)? = nil,
        onProgressChanged: ((Double) -> Void)? = nil,
        onURLChanged: ((URL?) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.dispatcher = dispatcher
        self.onWebViewCreated = onWebViewCreated
        self.onNavigationStarted = onNavigationStarted
        self.onNavigationFinished = onNavigationFinished
        self.onNavigationFailed = onNavigationFailed
        self.onProgressChanged = onProgressChanged
        self.onURLChanged = onURLChanged
    }

    // MARK: - UIViewRepresentable

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            dispatcher: dispatcher,
            configuration: configuration,
            onNavigationStarted: onNavigationStarted,
            onNavigationFinished: onNavigationFinished,
            onNavigationFailed: onNavigationFailed,
            onProgressChanged: onProgressChanged,
            onURLChanged: onURLChanged
        )
    }

    public func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator

        // Create the WKWebView configuration
        let wkConfig = WebViewConfigurationFactory.makeConfiguration(
            webViewConfiguration: configuration,
            messageHandler: coordinator.messageHandler
        )

        // Create the web view
        let webView = WKWebView(frame: .zero, configuration: wkConfig)

        // Configure delegates
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator.dialogHandler

        // Store references in coordinator
        coordinator.webView = webView
        coordinator.messageHandler.webView = webView

        // Set the view controller for modules that need UI presentation (e.g., Share sheet)
        // In SwiftUI, we get this from the window's root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController
        {
            coordinator.messageHandler.viewController = rootViewController
        }

        // Configure user agent
        configureUserAgent(for: webView)

        // Enable back/forward swipe gestures for navigation history
        webView.allowsBackForwardNavigationGestures = true

        // Disable scroll view bounces for app-like feel (pull-to-refresh will re-enable if needed)
        webView.scrollView.bounces = false

        // Enable Web Inspector in DEBUG builds
        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif

        // Set up progress observation
        coordinator.observeProgress(on: webView)

        // Set up URL observation
        coordinator.observeURL(on: webView)

        // Set up pull-to-refresh if enabled
        coordinator.setupPullToRefresh(on: webView)

        // Notify that the web view was created
        onWebViewCreated?(webView)

        // Load the start URL
        let request = URLRequest(url: configuration.startURL)
        webView.load(request)

        return webView
    }

    public func updateUIView(_: WKWebView, context _: Context) {
        // Currently no dynamic updates needed
        // Future: handle configuration changes if needed
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Remove the message handler to prevent retain cycles
        WebViewConfigurationFactory.removeMessageHandler(from: webView.configuration)

        // Cancel any pending navigation
        webView.stopLoading()

        // Remove progress observer
        coordinator.removeProgressObservation()

        // Remove URL observer
        coordinator.removeURLObservation()

        // Remove pull-to-refresh handler
        coordinator.removePullToRefresh()
    }

    // MARK: - Private Helpers

    /// Configures the custom user agent for the WebView.
    private func configureUserAgent(for webView: WKWebView) {
        // Set our custom user agent that includes PWAKit identifier
        let customUserAgent = UserAgentBuilder.buildUserAgent()
        webView.customUserAgent = customUserAgent
    }
}

// MARK: WebViewContainer.Coordinator

extension WebViewContainer {
    /// Coordinator that manages WKWebView delegates and message handling.
    ///
    /// The coordinator acts as the bridge between UIKit callbacks and SwiftUI,
    /// handling navigation events, UI delegate methods, and script message routing.
    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {
        /// The message handler for JavaScript bridge communication.
        let messageHandler: BridgeScriptMessageHandler

        /// The dialog handler for JavaScript alert/confirm/prompt.
        let dialogHandler: JavaScriptDialogHandler

        /// Weak reference to the web view.
        weak var webView: WKWebView?

        /// Progress observation token.
        private var progressObservation: NSKeyValueObservation?

        /// URL observation token.
        private var urlObservation: NSKeyValueObservation?

        /// Pull-to-refresh handler.
        var pullToRefreshHandler: PullToRefreshHandler?

        /// Callback when navigation starts.
        private let onNavigationStarted: (() -> Void)?

        /// Callback when navigation finishes.
        private let onNavigationFinished: (() -> Void)?

        /// Callback when navigation fails.
        private let onNavigationFailed: ((Error) -> Void)?

        /// Callback when progress changes.
        private let onProgressChanged: ((Double) -> Void)?

        /// Callback when URL changes.
        private let onURLChanged: ((URL?) -> Void)?

        /// Whether pull-to-refresh is enabled.
        private let pullToRefreshEnabled: Bool

        /// Creates a new coordinator.
        ///
        /// - Parameters:
        ///   - dispatcher: The bridge dispatcher for message routing.
        ///   - configuration: The WebView configuration.
        ///   - onNavigationStarted: Callback when navigation starts.
        ///   - onNavigationFinished: Callback when navigation finishes.
        ///   - onNavigationFailed: Callback when navigation fails.
        ///   - onProgressChanged: Callback when progress changes.
        ///   - onURLChanged: Callback when URL changes.
        init(
            dispatcher: BridgeDispatcher,
            configuration: WebViewConfiguration,
            onNavigationStarted: (() -> Void)?,
            onNavigationFinished: (() -> Void)?,
            onNavigationFailed: ((Error) -> Void)?,
            onProgressChanged: ((Double) -> Void)?,
            onURLChanged: ((URL?) -> Void)?
        ) {
            // Convert WebViewConfiguration to PWAConfiguration for the message handler
            let pwaConfig = PWAConfiguration(
                version: 1,
                app: AppConfiguration(
                    name: "PWAKit",
                    bundleId: Bundle.main.bundleIdentifier ?? "com.pwakit.app",
                    startUrl: configuration.startURL.absoluteString
                ),
                origins: OriginsConfiguration(
                    allowed: configuration.allowedOrigins,
                    auth: configuration.authOrigins,
                    external: []
                )
            )

            self.messageHandler = BridgeScriptMessageHandler(
                dispatcher: dispatcher,
                configuration: pwaConfig
            )
            self.dialogHandler = JavaScriptDialogHandler()
            self.onNavigationStarted = onNavigationStarted
            self.onNavigationFinished = onNavigationFinished
            self.onNavigationFailed = onNavigationFailed
            self.onProgressChanged = onProgressChanged
            self.onURLChanged = onURLChanged
            self.pullToRefreshEnabled = configuration.pullToRefresh

            super.init()

            // Create pull-to-refresh handler if enabled
            if pullToRefreshEnabled {
                pullToRefreshHandler = PullToRefreshHandler(isEnabled: true)
            }
        }

        /// Sets up progress observation on the web view.
        ///
        /// - Parameter webView: The web view to observe.
        func observeProgress(on webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.onProgressChanged?(webView.estimatedProgress)
                }
            }
        }

        /// Sets up URL observation on the web view.
        ///
        /// - Parameter webView: The web view to observe.
        func observeURL(on webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.onURLChanged?(webView.url)
                }
            }
        }

        /// Removes the progress observation.
        func removeProgressObservation() {
            progressObservation?.invalidate()
            progressObservation = nil
        }

        /// Removes the URL observation.
        func removeURLObservation() {
            urlObservation?.invalidate()
            urlObservation = nil
        }

        /// Sets up pull-to-refresh on the web view.
        ///
        /// - Parameter webView: The web view to attach pull-to-refresh to.
        func setupPullToRefresh(on webView: WKWebView) {
            pullToRefreshHandler?.attach(to: webView)
        }

        /// Removes pull-to-refresh from the web view.
        func removePullToRefresh() {
            pullToRefreshHandler?.detach()
            pullToRefreshHandler = nil
        }

        // MARK: - WKNavigationDelegate

        public func webView(
            _: WKWebView,
            didStartProvisionalNavigation _: WKNavigation!
        ) {
            onNavigationStarted?()
        }

        public func webView(
            _: WKWebView,
            didFinish _: WKNavigation!
        ) {
            onNavigationFinished?()
        }

        public func webView(
            _: WKWebView,
            didFail _: WKNavigation!,
            withError error: Error
        ) {
            onNavigationFailed?(error)
        }

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

        public func webView(
            _: WKWebView,
            decidePolicyFor _: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // For now, allow all navigations
            // Future: Implement NavigationPolicy-based decisions
            decisionHandler(.allow)
        }

        #if DEBUG
            /// Handles SSL authentication challenges for localhost development.
            ///
            /// This method accepts self-signed certificates for localhost only, enabling
            /// local HTTPS development servers (like the kitchen sink example) to work.
            ///
            /// - Parameters:
            ///   - webView: The web view receiving the challenge.
            ///   - challenge: The authentication challenge.
            ///   - completionHandler: Handler to call with the challenge response.
            public func webView(
                _: WKWebView,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
            ) {
                let host = challenge.protectionSpace.host
                let method = challenge.protectionSpace.authenticationMethod
                print("[WebViewContainer] SSL Challenge for: \(host), method: \(method)")

                // Only handle server trust challenges for localhost
                if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                   challenge.protectionSpace.host == "localhost",
                   let serverTrust = challenge.protectionSpace.serverTrust
                {
                    // Accept the self-signed certificate for localhost
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                    print("[WebViewContainer] Accepted localhost self-signed certificate")
                    return
                }
                // For all other challenges, use default handling
                completionHandler(.performDefaultHandling, nil)
            }
        #endif
    }
}

// MARK: - View Modifier Extensions

extension WebViewContainer {
    /// Creates a WebViewContainer with callbacks for state management.
    ///
    /// - Parameters:
    ///   - configuration: The WebView configuration.
    ///   - dispatcher: The bridge dispatcher.
    ///   - webViewBinding: Binding to store the WebView reference.
    ///   - isLoading: Binding to track loading state.
    ///   - progress: Binding to track loading progress.
    /// - Returns: A configured WebViewContainer.
    public static func withStateBindings(
        configuration: WebViewConfiguration,
        dispatcher: BridgeDispatcher,
        webViewBinding: Binding<WKWebView?>,
        isLoading: Binding<Bool>,
        progress: Binding<Double>
    ) -> WebViewContainer {
        WebViewContainer(
            configuration: configuration,
            dispatcher: dispatcher,
            onWebViewCreated: { webView in
                webViewBinding.wrappedValue = webView
            },
            onNavigationStarted: {
                isLoading.wrappedValue = true
            },
            onNavigationFinished: {
                isLoading.wrappedValue = false
            },
            onNavigationFailed: { _ in
                isLoading.wrappedValue = false
            },
            onProgressChanged: { newProgress in
                progress.wrappedValue = newProgress
            }
        )
    }
}
