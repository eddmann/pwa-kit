import SwiftUI

/// Main entry point for the PWAKit application.
///
/// PWAKitApp initializes the app's shared state, loads configuration, registers
/// all bridge modules, and wires together the WebView, bridge, and notifications.
///
/// ## Initialization Flow
///
/// 1. App launches and creates `AppState` and `BridgeDispatcher`
/// 2. Configuration is loaded from `pwa-config.json`
/// 3. Modules are registered with the dispatcher based on feature flags
/// 4. WebView is created and connected to the bridge
/// 5. AppDelegate receives notification callbacks and dispatches events
///
/// ## Push Notifications
///
/// The `AppDelegate` is connected via `@UIApplicationDelegateAdaptor` to handle
/// APNs registration callbacks. When a device token is received, it's stored
/// and made available to the `NotificationsModule`. The AppDelegate's `webView`
/// property is set when the WebViewContainer creates the WKWebView.
///
/// ## Module Registration
///
/// Modules are registered conditionally based on the `features` configuration:
/// - Platform and App modules are always registered
/// - Other modules (haptics, notifications, share, etc.) depend on feature flags
@main
struct PWAKitApp: App {
    /// The app delegate adaptor for handling UIKit app lifecycle events.
    /// This is required for receiving APNs device token callbacks.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// The shared app state, including configuration.
    @StateObject private var appState = AppState()

    /// The bridge dispatcher for routing JavaScript messages to modules.
    @State private var dispatcher = BridgeDispatcher()

    /// Whether modules have been registered.
    @State private var modulesRegistered = false

    var body: some Scene {
        WindowGroup {
            ContentView(dispatcher: dispatcher)
                .environmentObject(appState)
                .task {
                    await initializeApp()
                }
                .onReceive(appState.webViewSubject) { webView in
                    // Connect WebView to AppDelegate for notification event dispatch
                    appDelegate.webView = webView
                }
        }
    }

    // MARK: - Initialization

    /// Initializes the app by loading configuration and registering modules.
    ///
    /// This method is called once on app launch and performs:
    /// 1. Configuration loading from bundle or documents
    /// 2. Module registration based on feature flags
    @MainActor
    private func initializeApp() async {
        // Load configuration
        await appState.loadConfiguration()

        // Register modules based on feature flags
        guard !modulesRegistered else { return }

        if let config = appState.configuration {
            // Register modules with feature flags
            let count = await ModuleRegistration.registerDefaultModules(
                in: dispatcher,
                features: config.features
            )
            modulesRegistered = true

            #if DEBUG
                print("[PWAKitApp] Registered \(count) modules")
                let moduleNames = await dispatcher.registeredModuleNames
                print("[PWAKitApp] Modules: \(moduleNames.joined(separator: ", "))")
            #endif
        } else {
            // Register default modules without feature flags (fallback)
            let count = await ModuleRegistration.registerDefaultModules(in: dispatcher)
            modulesRegistered = true

            #if DEBUG
                print("[PWAKitApp] Registered \(count) default modules (no config)")
            #endif
        }
    }
}
