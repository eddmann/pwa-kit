import UIKit

/// Delegate for handling scene lifecycle events and deep linking.
///
/// `SceneDelegate` integrates the deep linking handlers with the UIKit scene lifecycle:
/// - Universal links via `NSUserActivity`
/// - Custom URL schemes via URL contexts
/// - App shortcuts via shortcut items
///
/// ## Configuration
///
/// To use SceneDelegate with SwiftUI, configure the app to use a scene delegate:
///
/// 1. In Info.plist, add or modify the scene configuration:
/// ```xml
/// <key>UIApplicationSceneManifest</key>
/// <dict>
///     <key>UIApplicationSupportsMultipleScenes</key>
///     <false/>
///     <key>UISceneConfigurations</key>
///     <dict>
///         <key>UIWindowSceneSessionRoleApplication</key>
///         <array>
///             <dict>
///                 <key>UISceneConfigurationName</key>
///                 <string>Default Configuration</string>
///                 <key>UISceneDelegateClassName</key>
///                 <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
///             </dict>
///         </array>
///     </dict>
/// </dict>
/// ```
///
/// ## Deep Link Flow
///
/// 1. **Launch Links**: When app launches from a deep link, `scene(_:willConnectTo:options:)`
///    receives the URL/activity and stores it as pending.
///
/// 2. **Universal Links**: `scene(_:continue:)` is called for universal links when the app
///    is already running.
///
/// 3. **Custom Schemes**: `scene(_:openURLContexts:)` handles custom URL scheme links.
///
/// 4. **Shortcuts**: `windowScene(_:performActionFor:completionHandler:)` handles
///    3D Touch / long press shortcuts.
///
/// The pending URLs are stored in the respective handlers until the WebView is ready
/// to navigate to them.
@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // MARK: - Properties

    /// The main window for this scene.
    var window: UIWindow?

    /// Handler for universal links.
    private var universalLinkHandler: UniversalLinkHandler?

    /// Handler for custom URL schemes.
    private var customSchemeHandler: CustomSchemeHandler?

    /// Handler for app shortcuts.
    private var appShortcutHandler: AppShortcutHandler?

    /// Flag indicating whether handlers have been initialized.
    private var handlersInitialized = false

    // MARK: - Scene Lifecycle

    /// Called when a new scene session is being created.
    ///
    /// This method handles deep links present at launch time:
    /// - URL contexts (custom scheme URLs)
    /// - User activities (universal links)
    /// - Shortcut items (3D Touch / long press actions)
    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Initialize handlers once configuration is available
        Task {
            await initializeHandlersIfNeeded()

            // Handle launch URL contexts (custom schemes)
            for urlContext in connectionOptions.urlContexts {
                handleIncomingURL(urlContext.url)
            }

            // Handle launch user activity (universal links)
            if let userActivity = connectionOptions.userActivities.first {
                handleUserActivity(userActivity)
            }

            // Handle launch shortcut
            if let shortcutItem = connectionOptions.shortcutItem {
                handleShortcut(shortcutItem)
            }
        }

        // Store reference to window scene for later use
        _ = windowScene
    }

    /// Called when the scene becomes active.
    func sceneDidBecomeActive(_: UIScene) {
        // No-op for now; can be used for analytics or refresh
    }

    /// Called when the scene is about to move to the background.
    func sceneWillResignActive(_: UIScene) {
        // No-op for now; can be used to save state
    }

    /// Called when the scene enters the background.
    func sceneDidEnterBackground(_: UIScene) {
        // No-op for now; can be used for cleanup
    }

    /// Called when the scene is about to enter the foreground.
    func sceneWillEnterForeground(_: UIScene) {
        // No-op for now; can be used to refresh UI
    }

    // MARK: - Universal Links

    /// Handles universal link continuation.
    ///
    /// Called when the app receives a universal link while running.
    /// The URL is extracted from the user activity and passed to the handler.
    ///
    /// - Parameters:
    ///   - scene: The scene receiving the activity.
    ///   - userActivity: The user activity containing the universal link.
    func scene(_: UIScene, continue userActivity: NSUserActivity) {
        Task {
            await initializeHandlersIfNeeded()
            handleUserActivity(userActivity)
        }
    }

    // MARK: - Custom URL Schemes

    /// Handles custom URL scheme opens.
    ///
    /// Called when the app is opened via a custom URL scheme while running.
    /// Each URL context is processed and converted to an HTTPS URL.
    ///
    /// - Parameters:
    ///   - scene: The scene receiving the URLs.
    ///   - URLContexts: The URL contexts to process.
    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        Task {
            await initializeHandlersIfNeeded()
            for urlContext in URLContexts {
                handleIncomingURL(urlContext.url)
            }
        }
    }

    // MARK: - App Shortcuts

    /// Handles app shortcut actions.
    ///
    /// Called when the user activates a 3D Touch / long press shortcut
    /// while the app is running.
    ///
    /// - Parameters:
    ///   - windowScene: The window scene handling the shortcut.
    ///   - shortcutItem: The shortcut item that was activated.
    ///   - completionHandler: Callback to indicate if the shortcut was handled.
    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task {
            await initializeHandlersIfNeeded()
            let handled = handleShortcut(shortcutItem)
            completionHandler(handled)
        }
    }

    // MARK: - Handler Initialization

    /// Initializes the deep link handlers from configuration.
    ///
    /// This method loads the configuration and creates the appropriate handlers
    /// based on the app and origins settings.
    private func initializeHandlersIfNeeded() async {
        guard !handlersInitialized else { return }

        do {
            let config = try await ConfigurationStore.shared.configuration

            // Initialize universal link handler
            universalLinkHandler = UniversalLinkHandler(origins: config.origins)

            // Initialize custom scheme handler
            customSchemeHandler = CustomSchemeHandler(appConfig: config.app)

            // Initialize app shortcut handler
            // Note: Shortcut mappings can be configured here or via a separate config
            appShortcutHandler = AppShortcutHandler(
                appConfig: config.app,
                shortcutMappings: [:]
            )

            handlersInitialized = true
        } catch {
            // Log error but don't crash - deep linking will be unavailable
            print("[SceneDelegate] Failed to initialize handlers: \(error)")
        }
    }

    // MARK: - URL Handling

    /// Handles an incoming URL from any source.
    ///
    /// Determines the URL type and routes to the appropriate handler:
    /// - HTTPS URLs → Universal link handler
    /// - Custom scheme URLs → Custom scheme handler
    ///
    /// - Parameter url: The URL to handle.
    private func handleIncomingURL(_ url: URL) {
        // Try custom scheme first (more specific)
        if let handler = customSchemeHandler, handler.handleURL(url) {
            return
        }

        // Try as universal link
        if let handler = universalLinkHandler, handler.canHandle(url: url) {
            handler.setPendingLink(url)
            return
        }

        // URL not handled - could be logged for debugging
        print("[SceneDelegate] Unhandled URL: \(url)")
    }

    /// Handles a user activity (typically from universal links).
    ///
    /// - Parameter userActivity: The user activity to process.
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        guard let handler = universalLinkHandler else { return }

        if handler.handleUserActivity(userActivity) {
            return
        }

        // Activity not handled - could be from other sources
        print("[SceneDelegate] Unhandled user activity: \(userActivity.activityType)")
    }

    /// Handles an app shortcut.
    ///
    /// - Parameter shortcutItem: The shortcut item to process.
    /// - Returns: `true` if the shortcut was handled, `false` otherwise.
    @discardableResult
    private func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let handler = appShortcutHandler else { return false }
        return handler.handleShortcut(shortcutItem)
    }
}
