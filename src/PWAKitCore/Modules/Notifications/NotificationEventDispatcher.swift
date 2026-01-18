import Foundation
import UserNotifications
import WebKit

// MARK: - WebViewProvider

/// Protocol for providing the WKWebView instance for JavaScript evaluation.
///
/// This protocol allows the dispatcher to access the current WebView
/// without creating retain cycles.
public protocol WebViewProvider: AnyObject, Sendable {
    /// Returns the current WKWebView instance, if available.
    @MainActor
    var webView: WKWebView? { get }
}

// MARK: - NotificationEventDispatcher

/// Dispatches notification events to the JavaScript layer.
///
/// `NotificationEventDispatcher` handles incoming push notifications and dispatches
/// them to the web application as custom events. It supports two types of events:
///
/// - **Foreground notifications**: When a notification arrives while the app is active
/// - **Tapped notifications**: When the user taps on a notification
///
/// ## Event Format
///
/// Events are dispatched to JavaScript using the `window.pwakit._handleEvent()` method:
///
/// ```javascript
/// // JavaScript receives:
/// window.addEventListener("pwa:push", (event) => {
///     console.log(event.detail.type);    // "received" or "tapped"
///     console.log(event.detail.title);   // "New Message"
///     console.log(event.detail.body);    // "You have a new message"
///     console.log(event.detail.userInfo); // { messageId: "123" }
/// });
/// ```
///
/// ## Usage
///
/// The dispatcher is typically used from the AppDelegate's notification delegate methods:
///
/// ```swift
/// func userNotificationCenter(
///     _ center: UNUserNotificationCenter,
///     willPresent notification: UNNotification
/// ) async -> UNNotificationPresentationOptions {
///     await dispatcher.dispatchForegroundNotification(notification)
///     return [.banner, .sound, .badge]
/// }
///
/// func userNotificationCenter(
///     _ center: UNUserNotificationCenter,
///     didReceive response: UNNotificationResponse
/// ) async {
///     await dispatcher.dispatchTappedNotification(response)
/// }
/// ```
@MainActor
public final class NotificationEventDispatcher {
    // MARK: - Properties

    /// Provider for the WKWebView instance.
    private weak var webViewProvider: WebViewProvider?

    // MARK: - Initialization

    /// Creates a new notification event dispatcher.
    ///
    /// - Parameter webViewProvider: Provider for the WKWebView instance.
    ///   The provider is held weakly to prevent retain cycles.
    public init(webViewProvider: WebViewProvider?) {
        self.webViewProvider = webViewProvider
    }

    // MARK: - Public Methods

    /// Dispatches a foreground notification event to JavaScript.
    ///
    /// Call this method when a notification is received while the app is in the
    /// foreground. The event will be dispatched with type "received".
    ///
    /// - Parameter notification: The notification that was received.
    public func dispatchForegroundNotification(_ notification: UNNotification) async {
        let payload = createPayload(from: notification.request.content, eventType: .received)
        await dispatchEvent(payload: payload)
    }

    /// Dispatches a tapped notification event to JavaScript.
    ///
    /// Call this method when the user taps on a notification to open the app.
    /// The event will be dispatched with type "tapped".
    ///
    /// - Parameter response: The notification response from the user's action.
    public func dispatchTappedNotification(_ response: UNNotificationResponse) async {
        let payload = createPayload(from: response.notification.request.content, eventType: .tapped)
        await dispatchEvent(payload: payload)
    }

    /// Dispatches a notification payload directly.
    ///
    /// Use this method when you have a pre-constructed payload, for example
    /// when handling silent push notifications or custom notification data.
    ///
    /// - Parameter payload: The notification payload to dispatch.
    public func dispatch(_ payload: NotificationPayload) async {
        await dispatchEvent(payload: payload)
    }

    /// Dispatches a foreground notification event using extracted data.
    ///
    /// This method accepts pre-extracted notification data instead of UNNotification,
    /// which allows it to be called safely across actor boundaries (UNNotification
    /// is not Sendable).
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body.
    ///   - subtitle: The notification subtitle.
    ///   - userInfo: The notification user info dictionary.
    ///   - badge: The badge number, if any.
    ///   - identifier: The notification request identifier.
    public func dispatchForegroundNotificationData(
        title: String,
        body: String,
        subtitle: String,
        userInfo: [AnyHashable: Any],
        badge: NSNumber?,
        identifier _: String
    ) async {
        let payload = createPayloadFromData(
            title: title,
            body: body,
            subtitle: subtitle,
            userInfo: userInfo,
            badge: badge,
            eventType: .received
        )
        await dispatchEvent(payload: payload)
    }

    /// Dispatches a tapped notification event using extracted data.
    ///
    /// This method accepts pre-extracted notification data instead of UNNotificationResponse,
    /// which allows it to be called safely across actor boundaries (UNNotificationResponse
    /// is not Sendable).
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body.
    ///   - subtitle: The notification subtitle.
    ///   - userInfo: The notification user info dictionary.
    ///   - badge: The badge number, if any.
    ///   - identifier: The notification request identifier.
    ///   - actionIdentifier: The action identifier from the user's response.
    public func dispatchTappedNotificationData(
        title: String,
        body: String,
        subtitle: String,
        userInfo: [AnyHashable: Any],
        badge: NSNumber?,
        identifier _: String,
        actionIdentifier _: String
    ) async {
        let payload = createPayloadFromData(
            title: title,
            body: body,
            subtitle: subtitle,
            userInfo: userInfo,
            badge: badge,
            eventType: .tapped
        )
        // Note: actionIdentifier could be added to the payload if needed
        await dispatchEvent(payload: payload)
    }

    // MARK: - Private Methods

    /// Creates a NotificationPayload from extracted notification data.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body.
    ///   - subtitle: The notification subtitle.
    ///   - userInfo: The notification user info dictionary.
    ///   - badge: The badge number, if any.
    ///   - eventType: The type of notification event.
    /// - Returns: A NotificationPayload ready for dispatch.
    private func createPayloadFromData(
        title: String,
        body: String,
        subtitle: String,
        userInfo: [AnyHashable: Any],
        badge: NSNumber?,
        eventType: NotificationPayload.EventType
    ) -> NotificationPayload {
        // Convert userInfo dictionary to [String: AnyCodable]
        let convertedUserInfo = convertUserInfo(userInfo)

        return NotificationPayload(
            type: eventType,
            title: title.isEmpty ? nil : title,
            body: body.isEmpty ? nil : body,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            userInfo: convertedUserInfo.isEmpty ? nil : convertedUserInfo,
            badge: badge?.intValue,
            sound: nil,
            timestamp: Date().timeIntervalSince1970
        )
    }

    /// Creates a NotificationPayload from UNNotificationContent.
    ///
    /// - Parameters:
    ///   - content: The notification content.
    ///   - eventType: The type of notification event.
    /// - Returns: A NotificationPayload ready for dispatch.
    private func createPayload(
        from content: UNNotificationContent,
        eventType: NotificationPayload.EventType
    ) -> NotificationPayload {
        // Convert userInfo dictionary to [String: AnyCodable]
        let userInfo = convertUserInfo(content.userInfo)

        // Get badge number if set
        let badge = content.badge?.intValue

        // Get sound name if available
        let sound: String? = nil // UNNotificationSound doesn't expose the sound name

        return NotificationPayload(
            type: eventType,
            title: content.title.isEmpty ? nil : content.title,
            body: content.body.isEmpty ? nil : content.body,
            subtitle: content.subtitle.isEmpty ? nil : content.subtitle,
            userInfo: userInfo.isEmpty ? nil : userInfo,
            badge: badge,
            sound: sound,
            timestamp: Date().timeIntervalSince1970
        )
    }

    /// Converts a userInfo dictionary to [String: AnyCodable].
    ///
    /// - Parameter userInfo: The raw userInfo dictionary from the notification.
    /// - Returns: A dictionary with AnyCodable values.
    private func convertUserInfo(_ userInfo: [AnyHashable: Any]) -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [:]

        for (key, value) in userInfo {
            guard let stringKey = key as? String else { continue }

            // Skip the aps dictionary as we've already extracted the relevant parts
            if stringKey == "aps" { continue }

            result[stringKey] = convertToAnyCodable(value)
        }

        return result
    }

    /// Converts an arbitrary value to AnyCodable.
    ///
    /// - Parameter value: The value to convert.
    /// - Returns: An AnyCodable representation of the value.
    private func convertToAnyCodable(_ value: Any) -> AnyCodable {
        switch value {
        case let boolValue as Bool:
            return AnyCodable(boolValue)
        case let intValue as Int:
            return AnyCodable(intValue)
        case let doubleValue as Double:
            return AnyCodable(doubleValue)
        case let stringValue as String:
            return AnyCodable(stringValue)
        case let arrayValue as [Any]:
            return AnyCodable(arrayValue.map { convertToAnyCodable($0) })
        case let dictValue as [String: Any]:
            var converted: [String: AnyCodable] = [:]
            for (k, v) in dictValue {
                converted[k] = convertToAnyCodable(v)
            }
            return AnyCodable(converted)
        default:
            // Try to convert to string as a fallback
            return AnyCodable(String(describing: value))
        }
    }

    /// Dispatches a notification payload to JavaScript.
    ///
    /// - Parameter payload: The notification payload to dispatch.
    private func dispatchEvent(payload: NotificationPayload) async {
        guard let webView = webViewProvider?.webView else {
            #if DEBUG
                print("[NotificationEventDispatcher] No WebView available for event dispatch")
            #endif
            return
        }

        // Encode the payload as AnyCodable
        let eventData = encodePayload(payload)

        // Create the JavaScript event
        let jsCode = JavaScriptBridge.formatEvent(type: "push", data: eventData)

        // Execute the JavaScript
        do {
            try await webView.evaluateJavaScript(jsCode)
            #if DEBUG
                print("[NotificationEventDispatcher] Dispatched \(payload.type.rawValue) notification event")
            #endif
        } catch {
            #if DEBUG
                print("[NotificationEventDispatcher] Failed to dispatch event: \(error.localizedDescription)")
            #endif
        }
    }

    /// Encodes a NotificationPayload to AnyCodable for JavaScript dispatch.
    ///
    /// - Parameter payload: The payload to encode.
    /// - Returns: An AnyCodable representation of the payload.
    private func encodePayload(_ payload: NotificationPayload) -> AnyCodable {
        var dict: [String: AnyCodable] = [
            "type": AnyCodable(payload.type.rawValue),
            "timestamp": AnyCodable(payload.timestamp),
        ]

        if let title = payload.title {
            dict["title"] = AnyCodable(title)
        }

        if let body = payload.body {
            dict["body"] = AnyCodable(body)
        }

        if let subtitle = payload.subtitle {
            dict["subtitle"] = AnyCodable(subtitle)
        }

        if let userInfo = payload.userInfo {
            dict["userInfo"] = AnyCodable(userInfo)
        }

        if let badge = payload.badge {
            dict["badge"] = AnyCodable(badge)
        }

        if let sound = payload.sound {
            dict["sound"] = AnyCodable(sound)
        }

        return AnyCodable(dict)
    }
}
