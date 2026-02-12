import UIKit
import UserNotifications
import WebKit

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the WebView finishes loading a page.
    /// Used to flush queued notification events after the JavaScript bridge is ready.
    static let webViewPageLoaded = Notification.Name("PWAKit.webViewPageLoaded")
}

// MARK: - AppDelegate

/// Application delegate for handling APNs registration, notification delivery, and other app-level events.
///
/// `AppDelegate` integrates with the iOS push notification system to:
/// - Receive and store device tokens from APNs
/// - Handle registration failures
/// - Make tokens available to the `NotificationsModule`
/// - Handle foreground notification presentation
/// - Handle user taps on notifications
/// - Dispatch notification events to JavaScript
///
/// ## Configuration
///
/// To use AppDelegate with SwiftUI, add an `@UIApplicationDelegateAdaptor`:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
///
/// ## Push Notification Flow
///
/// 1. JavaScript calls `notifications.subscribe()` via the bridge
/// 2. `NotificationsModule` requests permission and calls `registerForRemoteNotifications()`
/// 3. iOS contacts APNs and returns a device token
/// 4. `AppDelegate` receives the token in `didRegisterForRemoteNotificationsWithDeviceToken`
/// 5. Token is stored in `UserDefaults` and available via `NotificationsModule.getToken()`
///
/// ## Notification Delivery Flow
///
/// When a notification is received:
///
/// - **Foreground**: `willPresent` is called, event is dispatched to JavaScript with type "received"
/// - **Background/Closed**: User taps notification, `didReceive` is called, event is dispatched with type "tapped"
///
/// JavaScript can listen for these events:
///
/// ```javascript
/// window.addEventListener("pwa:push", (event) => {
///     console.log(event.detail.type);    // "received" or "tapped"
///     console.log(event.detail.title);   // Notification title
///     console.log(event.detail.body);    // Notification body
///     console.log(event.detail.userInfo); // Custom data
/// });
/// ```
///
/// ## Entitlements
///
/// Push notifications require the `aps-environment` entitlement:
/// - Development: `<string>development</string>`
/// - Production: `<string>production</string>`
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, WebViewProvider {
    // MARK: - Properties

    /// Token storage for persisting the device token.
    private let tokenStorage: TokenStorage = UserDefaultsTokenStorage()

    /// Event dispatcher for sending notification events to JavaScript.
    private lazy var eventDispatcher = NotificationEventDispatcher(webViewProvider: self)

    /// Cached orientation mask from pwa-config.json to avoid re-reading on every call.
    private var cachedOrientationMask: UIInterfaceOrientationMask?

    /// Weak reference to the WKWebView for event dispatching.
    ///
    /// This property is set by the app when the WebView is created.
    /// It conforms to `WebViewProvider` for use by `NotificationEventDispatcher`.
    weak var webView: WKWebView?

    // MARK: - Application Lifecycle

    /// Called when the application finishes launching.
    ///
    /// This method sets up the notification center delegate to receive
    /// notification delivery callbacks. Push notification registration is
    /// triggered by `NotificationsModule.subscribe()`, not here, to ensure
    /// user consent is obtained first.
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set ourselves as the notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Flush queued notification events when the page finishes loading
        NotificationCenter.default.addObserver(
            forName: .webViewPageLoaded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.eventDispatcher.handlePageLoaded()
            }
        }

        #if DEBUG
            print("[AppDelegate] Application did finish launching")
            print("[AppDelegate] Set up notification center delegate")
        #endif

        return true
    }

    /// Called when the app becomes active.
    ///
    /// This is a good place to refresh UI or sync state.
    func applicationDidBecomeActive(_: UIApplication) {
        #if DEBUG
            print("[AppDelegate] Application did become active")
        #endif

        // Clear badge count when app becomes active (optional behavior)
        // UIApplication.shared.applicationIconBadgeNumber = 0
    }

    /// Called when the app is about to become inactive.
    ///
    /// Save any data that needs to persist here.
    func applicationWillResignActive(_: UIApplication) {
        #if DEBUG
            print("[AppDelegate] Application will resign active")
        #endif
    }

    /// Called when the app enters the background.
    func applicationDidEnterBackground(_: UIApplication) {
        #if DEBUG
            print("[AppDelegate] Application did enter background")
        #endif
    }

    /// Called when the app is about to enter the foreground.
    func applicationWillEnterForeground(_: UIApplication) {
        #if DEBUG
            print("[AppDelegate] Application will enter foreground")
        #endif
    }

    // MARK: - Orientation

    /// Returns the supported interface orientations based on the bundled pwa-config.json.
    ///
    /// The orientation mask is decoded once from the configuration file and cached
    /// to avoid re-reading the file on every call (UIKit calls this frequently).
    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if let cached = cachedOrientationMask {
            return cached
        }

        guard
            let url = Bundle.main.url(forResource: "pwa-config", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(PWAConfiguration.self, from: data) else
        {
            cachedOrientationMask = .all
            return .all
        }

        let mask: UIInterfaceOrientationMask = switch config.appearance.orientationLock {
        case .portrait: .portrait
        case .landscape: .landscape
        case .any: .all
        }

        cachedOrientationMask = mask
        return mask
    }

    // MARK: - Notification Event Flushing

    /// Flushes any queued notification events to JavaScript.
    ///
    /// Call this when the WebView and page are ready to receive events,
    /// such as after the page finishes loading or the app returns to the foreground.
    func flushPendingNotificationEvents() async {
        await eventDispatcher.flushPendingEvents()
    }

    // MARK: - Remote Notifications

    /// Called when APNs successfully registers the device and returns a token.
    ///
    /// The device token is:
    /// 1. Converted to a hex string format
    /// 2. Stored in UserDefaults for retrieval by `NotificationsModule`
    /// 3. Logged for debugging purposes
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - deviceToken: A globally unique token that identifies this device to APNs.
    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.hexEncodedString()
        tokenStorage.setToken(tokenString)

        #if DEBUG
            print("[AppDelegate] Successfully registered for remote notifications")
            print("[AppDelegate] Device token: \(tokenString)")
        #endif
    }

    /// Called when APNs registration fails.
    ///
    /// Common failure reasons:
    /// - Running on Simulator (push not supported)
    /// - Missing push notification entitlement
    /// - Network connectivity issues
    /// - Invalid provisioning profile
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - error: An error object indicating why registration failed.
    func application(
        _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Clear any stale token on failure
        tokenStorage.clearToken()

        #if DEBUG
            print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}

// MARK: UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Called when a notification is delivered while the app is in the foreground.
    ///
    /// This method:
    /// 1. Tells the system to show the notification immediately
    /// 2. Dispatches a "received" event to JavaScript asynchronously
    ///
    /// Uses the completion handler API instead of async to avoid blocking the
    /// system's UI operations (scene activation, snapshots) with actor hops.
    ///
    /// - Parameters:
    ///   - center: The notification center.
    ///   - notification: The notification being delivered.
    ///   - completionHandler: Handler to call with presentation options.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        // Extract notification data (synchronous, safe from any thread)
        let content = notification.request.content
        let title = content.title
        let body = content.body
        let subtitle = content.subtitle
        let badge = content.badge
        let identifier = notification.request.identifier

        let userInfoData: Data?
        do {
            userInfoData = try JSONSerialization.data(withJSONObject: content.userInfo)
        } catch {
            userInfoData = nil
        }

        #if DEBUG
            print("[AppDelegate] Received foreground notification: \(title)")
        #endif

        // Tell the system to show the notification immediately — don't block
        completionHandler([.banner, .sound, .badge])

        // Dispatch event to JavaScript asynchronously on the main actor
        Task { @MainActor [weak self] in
            guard let dispatcher = self?.eventDispatcher else { return }

            var userInfo: [AnyHashable: Any] = [:]
            if let data = userInfoData,
               let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                userInfo = decoded
            }

            await dispatcher.dispatchForegroundNotificationData(
                title: title,
                body: body,
                subtitle: subtitle,
                userInfo: userInfo,
                badge: badge,
                identifier: identifier
            )
        }
    }

    /// Called when the user interacts with a notification (typically by tapping it).
    ///
    /// This method dispatches a "tapped" event to JavaScript with the notification content,
    /// allowing the web application to handle the user's response appropriately.
    ///
    /// Uses the completion handler API instead of async to avoid blocking the
    /// system's scene activation with actor hops, which causes main thread assertions.
    ///
    /// - Parameters:
    ///   - center: The notification center.
    ///   - response: The user's response to the notification.
    ///   - completionHandler: Handler to call when processing is complete.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        // Extract notification data (synchronous, safe from any thread)
        let content = response.notification.request.content
        let title = content.title
        let body = content.body
        let subtitle = content.subtitle
        let badge = content.badge
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier

        let userInfoData: Data?
        do {
            userInfoData = try JSONSerialization.data(withJSONObject: content.userInfo)
        } catch {
            userInfoData = nil
        }

        #if DEBUG
            print("[AppDelegate] User tapped notification: \(title)")
        #endif

        // Tell the system we're done immediately — don't block scene activation
        completionHandler()

        // Dispatch event to JavaScript asynchronously on the main actor
        Task { @MainActor [weak self] in
            guard let dispatcher = self?.eventDispatcher else { return }

            var userInfo: [AnyHashable: Any] = [:]
            if let data = userInfoData,
               let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                userInfo = decoded
            }

            await dispatcher.dispatchTappedNotificationData(
                title: title,
                body: body,
                subtitle: subtitle,
                userInfo: userInfo,
                badge: badge,
                identifier: identifier,
                actionIdentifier: actionIdentifier
            )
        }
    }
}
