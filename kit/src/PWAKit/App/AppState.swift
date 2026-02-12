import Combine
import WebKit

/// Centralized state management for the PWAKit application.
///
/// AppState serves as the single source of truth for app-wide state,
/// providing reactive updates to SwiftUI views through the ObservableObject protocol.
///
/// ## Configuration Integration
///
/// AppState loads and exposes the app's configuration on launch. The configuration
/// is loaded asynchronously and errors are handled gracefully with appropriate
/// error state exposed to the UI.
///
/// ## Example
///
/// ```swift
/// struct ContentView: View {
///     @EnvironmentObject var appState: AppState
///
///     var body: some View {
///         Group {
///             if let error = appState.configurationError {
///                 Text("Configuration error: \(error.localizedDescription)")
///             } else if let config = appState.configuration {
///                 Text("App: \(config.app.name)")
///             } else {
///                 ProgressView("Loading...")
///             }
///         }
///     }
/// }
/// ```
@MainActor
final class AppState: ObservableObject {
    // MARK: - Loading State

    /// Indicates whether the webview is currently loading content.
    @Published var isLoading = true

    /// Current loading progress (0.0 to 1.0).
    @Published var loadingProgress = 0.0

    // MARK: - Configuration State

    /// The loaded configuration, or `nil` if not yet loaded.
    @Published private(set) var configuration: PWAConfiguration?

    /// Whether configuration is currently being loaded.
    @Published private(set) var isLoadingConfiguration = false

    /// The configuration error, if loading failed.
    @Published private(set) var configurationError: ConfigurationError?

    // MARK: - WebView Reference

    /// Weak reference to the WKWebView instance.
    /// This is populated once the webview is created.
    /// Other components (like AppDelegate) can access it directly.
    /// Note: We use a non-Published weak var because @Published doesn't support weak.
    weak var webView: WKWebView? {
        didSet {
            webViewSubject.send(webView)
        }
    }

    /// Publisher for observing webView changes.
    let webViewSubject = PassthroughSubject<WKWebView?, Never>()

    // MARK: - Initialization

    /// Creates a new AppState instance with default values.
    ///
    /// Loads bundled pwa-config.json synchronously to ensure theme colors
    /// are available before the first frame renders.
    init() {
        // Load bundled config synchronously for immediate theme colors
        if let url = Bundle.main.url(forResource: "pwa-config", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(PWAConfiguration.self, from: data)
        {
            self.configuration = config
        }
    }

    // MARK: - Configuration Loading

    /// Loads the configuration from the configuration store.
    ///
    /// This method is typically called once on app launch. It loads the configuration
    /// asynchronously and updates the published properties accordingly.
    ///
    /// - Note: Multiple calls are safe; if configuration is already loaded,
    ///         subsequent calls are no-ops unless `forceReload` is `true`.
    /// - Parameter forceReload: If `true`, reloads the configuration even if already loaded.
    func loadConfiguration(forceReload: Bool = false) async {
        // Skip if already loaded and not forcing reload
        guard configuration == nil || forceReload else { return }

        // Skip if already loading
        guard !isLoadingConfiguration else { return }

        isLoadingConfiguration = true
        configurationError = nil

        do {
            if forceReload {
                configuration = try await ConfigurationStore.shared.reload()
            } else {
                configuration = try await ConfigurationStore.shared.load()
            }
        } catch let error as ConfigurationError {
            configurationError = error
        } catch {
            configurationError = .unexpected(reason: error.localizedDescription)
        }

        isLoadingConfiguration = false
    }

    /// Checks if a feature is enabled in the current configuration.
    ///
    /// - Parameter feature: The feature to check.
    /// - Returns: `true` if the feature is enabled, or the default value if
    ///            configuration is not loaded.
    func isFeatureEnabled(_ feature: ConfigurationStore.Feature) -> Bool {
        guard let config = configuration else {
            return feature.defaultValue
        }
        return feature.isEnabled(in: config.features)
    }
}
