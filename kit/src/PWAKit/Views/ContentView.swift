import SwiftUI
import WebKit

/// Main content view for the PWAKit application.
///
/// `ContentView` is the primary view that orchestrates the WebView display,
/// loading states, error handling, and retry logic. It connects to the
/// `AppState` for configuration and state management.
///
/// ## View Hierarchy
///
/// ```
/// ContentView
/// ├── WebViewContainer (main content)
/// ├── LoadingView (overlay while loading)
/// └── ConnectionErrorView (overlay on connection failure)
/// ```
///
/// ## State Flow
///
/// 1. App launches → shows LoadingView while configuration loads
/// 2. Configuration loads → creates WebViewConfiguration
/// 3. WebView starts loading → LoadingView shows progress
/// 4. Navigation succeeds → LoadingView fades out, WebView visible
/// 5. Navigation fails → ConnectionErrorView shows with auto-retry
struct ContentView: View {
    // MARK: - Environment

    /// The shared app state containing configuration and loading state.
    @EnvironmentObject private var appState: AppState

    // MARK: - Properties

    /// The bridge dispatcher for JavaScript communication.
    let dispatcher: BridgeDispatcher

    /// Callback when the WebView is created and ready.
    /// Used by PWAKitApp to connect the WebView to AppDelegate for notification dispatch.
    var onWebViewConnected: ((WKWebView) -> Void)?

    // MARK: - State

    /// Whether the WebView is currently loading content.
    @State private var isLoading = true

    /// Current loading progress (0.0 to 1.0).
    @State private var loadingProgress = 0.0

    /// Whether a connection error has occurred.
    @State private var hasConnectionError = false

    /// Progress towards automatic retry (0.0 to 1.0).
    @State private var retryProgress = 0.0

    /// Task for automatic retry countdown.
    @State private var retryTask: Task<Void, Never>?

    /// Reference to the WebView for retry operations.
    @State private var webViewRef: WKWebView?

    /// Current URL being displayed.
    @State private var currentURL: URL?

    /// Whether we're currently on an auth origin.
    @State private var isOnAuthOrigin = false

    /// The retry interval in seconds.
    private let retryInterval: TimeInterval = 6.0

    // MARK: - Theme Colors

    /// Resolved background color from pwa-config appearance.
    private var themeBackgroundColor: Color? {
        appState.configuration?.appearance.backgroundColor.flatMap { Color(hex: $0) }
    }

    /// Resolved color scheme from statusBarStyle configuration.
    ///
    /// Maps the configured status bar style to a SwiftUI color scheme:
    /// - `adaptive`: `nil` (AdaptiveStyleObserver handles it via window style)
    /// - `light`: `.light` (forces light appearance with dark status bar text)
    /// - `dark`: `.dark` (forces dark appearance with light status bar text)
    private var statusBarColorScheme: ColorScheme? {
        switch appState.configuration?.appearance.statusBarStyle ?? .adaptive {
        case .adaptive:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// Resolved accent color from pwa-config appearance.
    private var themeAccentColor: Color? {
        appState.configuration?.appearance.themeColor.flatMap { Color(hex: $0) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Auth toolbar (shown when on auth origin)
                if isOnAuthOrigin {
                    AuthToolbar(onDone: handleAuthToolbarDone)
                }

                // Main content
                if let config = appState.configuration {
                    webViewContent(config: config)
                } else if appState.isLoadingConfiguration {
                    // Show loading while configuration is loading
                    LoadingView(
                        progress: 0,
                        showProgress: false,
                        backgroundColor: themeBackgroundColor,
                        accentColor: themeAccentColor
                    )
                } else if let error = appState.configurationError {
                    // Show configuration error
                    configurationErrorView(error: error)
                } else {
                    // Fallback loading state
                    LoadingView(
                        progress: 0,
                        showProgress: false,
                        backgroundColor: themeBackgroundColor,
                        accentColor: themeAccentColor
                    )
                }
            }

            // Loading overlay
            if isLoading, !hasConnectionError, appState.configuration != nil {
                LoadingView(
                    progress: loadingProgress,
                    backgroundColor: themeBackgroundColor,
                    accentColor: themeAccentColor
                )
                .transition(.opacity)
            }

            // Connection error overlay
            if hasConnectionError {
                ConnectionErrorView(retryProgress: retryProgress)
                    .transition(.opacity)
            }
        }
        .background(
            (themeBackgroundColor ?? Color(UIColor.systemBackground))
                .ignoresSafeArea()
        )
        .preferredColorScheme(statusBarColorScheme)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: hasConnectionError)
        .animation(.easeInOut(duration: 0.2), value: isOnAuthOrigin)
        .onDisappear {
            cancelRetryTimer()
        }
    }

    // MARK: - Subviews

    /// Creates the WebView content with the given configuration.
    @ViewBuilder
    private func webViewContent(config: PWAConfiguration) -> some View {
        if let webViewConfig = try? WebViewConfiguration.from(pwaConfig: config) {
            WebViewContainer(
                configuration: webViewConfig,
                dispatcher: dispatcher,
                onWebViewCreated: { webView in
                    webViewRef = webView
                    appState.webView = webView
                    onWebViewConnected?(webView)
                },
                onNavigationStarted: {
                    isLoading = true
                    hasConnectionError = false
                    cancelRetryTimer()
                },
                onNavigationFinished: {
                    // Complete progress to 100%
                    loadingProgress = 1.0
                    hasConnectionError = false
                    cancelRetryTimer()

                    // Flush any queued notification events now that the page is loaded
                    NotificationCenter.default.post(name: .webViewPageLoaded, object: nil)

                    // Delay before hiding loading view for smoother transition
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                        isLoading = false
                    }
                },
                onNavigationFailed: { _ in
                    isLoading = false
                    hasConnectionError = true
                    startRetryTimer()
                },
                onProgressChanged: { progress in
                    loadingProgress = progress
                },
                onURLChanged: { url in
                    handleURLChange(url, config: config)
                }
            )
            .opacity(isLoading ? 0 : 1)
            .ignoresSafeArea()
        } else {
            // Invalid configuration
            Text("Invalid configuration: Could not create WebView")
                .foregroundColor(.red)
        }
    }

    /// Creates the configuration error view.
    private func configurationErrorView(error: ConfigurationError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Configuration Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await appState.loadConfiguration(forceReload: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Retry Logic

    /// Starts the automatic retry countdown using async/await.
    private func startRetryTimer() {
        cancelRetryTimer()
        retryProgress = 0.0

        // Use a Task for the retry countdown
        retryTask = Task { @MainActor in
            let updateInterval: TimeInterval = 0.1
            let totalUpdates = Int(retryInterval / updateInterval)

            for i in 1 ... totalUpdates {
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                if Task.isCancelled { return }
                retryProgress = Double(i) / Double(totalUpdates)
            }

            // Trigger retry when complete
            if !Task.isCancelled {
                retryWebView()
            }
        }
    }

    /// Cancels the retry countdown.
    private func cancelRetryTimer() {
        retryTask?.cancel()
        retryTask = nil
        retryProgress = 0.0
    }

    /// Triggers a WebView reload.
    private func retryWebView() {
        guard let webView = webViewRef else { return }

        hasConnectionError = false
        isLoading = true
        loadingProgress = 0.0

        // Reload the current page or load the start URL
        if let url = webView.url {
            webView.load(URLRequest(url: url))
        } else if let config = appState.configuration,
                  let startURL = URL(string: config.app.startUrl)
        {
            webView.load(URLRequest(url: startURL))
        }
    }

    // MARK: - Auth Toolbar Handling

    /// Handles URL changes to update auth origin state.
    private func handleURLChange(_ url: URL?, config: PWAConfiguration) {
        currentURL = url

        guard let url else {
            isOnAuthOrigin = false
            return
        }

        // Use NavigationPolicyResolver to determine if we're on an auth origin
        let resolver = NavigationPolicyResolver(origins: config.origins)
        let policy = resolver.resolve(for: url)
        isOnAuthOrigin = (policy == .allowWithToolbar)
    }

    /// Handles the auth toolbar Done button tap.
    private func handleAuthToolbarDone() {
        guard let webView = webViewRef,
              let config = appState.configuration,
              let startURL = URL(string: config.app.startUrl) else
        {
            return
        }

        // Navigate back to the start URL
        webView.load(URLRequest(url: startURL))
    }
}
