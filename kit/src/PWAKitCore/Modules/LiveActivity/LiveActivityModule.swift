import ActivityKit
import Foundation

// MARK: - PWAKitActivityAttributes

/// ActivityKit attributes for PWAKit Live Activities.
///
/// This defines the static and dynamic content for Live Activities
/// displayed in the Dynamic Island and on the Lock Screen.
///
/// The `ContentState` uses `SharedActivityData` to allow PWAs to push
/// flexible, structured content without native code changes.
@available(iOS 16.1, *)
public struct PWAKitActivityAttributes: ActivityAttributes {
    /// The dynamic content state updated over the Live Activity's lifetime.
    public struct ContentState: Codable, Hashable, Sendable {
        /// The activity display data from the PWA.
        public let data: SharedActivityData

        /// Creates a new content state.
        public init(data: SharedActivityData) {
            self.data = data
        }
    }

    /// Static identifier for the activity type.
    public let activityId: String

    /// Creates new activity attributes.
    public init(activityId: String) {
        self.activityId = activityId
    }
}

// MARK: - SharedActivityData + Hashable

extension SharedActivityData: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(progress)
        hasher.combine(icon)
        hasher.combine(tint)
    }
}

// MARK: - LiveActivityPushTokenStore

/// Thread-safe storage for the ActivityKit push token.
///
/// ActivityKit push tokens are delivered asynchronously via `Activity.pushTokenUpdates`.
/// This actor stores the latest token so it can be retrieved by the `getPushToken` action.
@available(iOS 16.2, *)
public actor LiveActivityPushTokenStore {
    /// Shared singleton instance.
    public static let shared = LiveActivityPushTokenStore()

    /// The current push token as a hex-encoded string.
    private(set) var currentToken: String?

    /// Updates the stored push token.
    ///
    /// - Parameter token: The new push token data from ActivityKit.
    public func updateToken(_ token: Data) {
        currentToken = token.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
            print("[LiveActivityPushTokenStore] Updated push token: \(currentToken ?? "nil")")
        #endif
    }

    /// Clears the stored push token.
    public func clearToken() {
        currentToken = nil
    }
}

// MARK: - LiveActivityModule

/// A module that provides Dynamic Island and Live Activity support to JavaScript.
///
/// `LiveActivityModule` bridges ActivityKit to web applications, enabling PWAs
/// to start, update, and end Live Activities that appear in the Dynamic Island
/// (iPhone 14 Pro and later) and on the Lock Screen.
///
/// ## Background Updates via Push
///
/// On iOS 16.2+, Live Activities are started with `pushType: .token`, which enables
/// server-side updates via Apple Push Notification service (APNs). The PWA retrieves
/// the push token via `getPushToken` and sends it to its server. The server can then
/// update the Dynamic Island in the background without waking the app.
///
/// ## Supported Actions
///
/// - `start(title, subtitle?, progress?, icon?, tint?, fields?, activityId?)`:
///   Start a new Live Activity.
/// - `update(title, subtitle?, progress?, icon?, tint?, fields?)`:
///   Update the current Live Activity's content.
/// - `end(dismissalPolicy?)`: End the current Live Activity.
/// - `getState()`: Get the current Live Activity state.
/// - `areActivitiesEnabled()`: Check if Live Activities are enabled.
/// - `getPushToken()`: Get the ActivityKit push token for server-side updates (iOS 16.2+).
///
/// ## Example
///
/// Start a delivery tracking Live Activity and get the push token:
/// ```json
/// {
///   "module": "liveActivity",
///   "action": "start",
///   "payload": {
///     "activityId": "delivery-123",
///     "title": "Order #1234",
///     "subtitle": "Preparing your food",
///     "progress": 0.3,
///     "icon": "fork.knife",
///     "tint": "#FF6B35",
///     "fields": { "eta": "12:30 PM" }
///   }
/// }
/// ```
@available(iOS 16.1, *)
public struct LiveActivityModule: PWAModule {
    public static let moduleName = "liveActivity"
    public static let supportedActions = [
        "start", "update", "end", "getState", "areActivitiesEnabled", "getPushToken",
    ]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "start":
            return try await handleStart(payload: payload)

        case "update":
            return try await handleUpdate(payload: payload)

        case "end":
            return try await handleEnd(payload: payload)

        case "getState":
            return handleGetState()

        case "areActivitiesEnabled":
            return handleAreActivitiesEnabled()

        case "getPushToken":
            return await handleGetPushToken()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Start

    private func handleStart(payload: AnyCodable?) async throws -> AnyCodable {
        guard let data = SharedActivityData.from(payload: payload) else {
            throw BridgeError.invalidPayload("Missing required 'title' field for Live Activity")
        }

        let activityId = payload?["activityId"]?.stringValue ?? "pwakit-activity"

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return AnyCodable([
                "started": AnyCodable(false),
                "reason": AnyCodable("Live Activities are disabled in Settings"),
            ])
        }

        let attributes = PWAKitActivityAttributes(activityId: activityId)
        let state = PWAKitActivityAttributes.ContentState(data: data)

        do {
            let activity: Activity<PWAKitActivityAttributes>

            // On iOS 16.2+, request with pushType: .token to enable server-side updates
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: .token
                )

                // Observe push token updates in a detached task
                Task.detached {
                    for await tokenData in activity.pushTokenUpdates {
                        await LiveActivityPushTokenStore.shared.updateToken(tokenData)
                    }
                }
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
            }

            AppGroupStorage.saveActivityData(data)

            var result: [String: AnyCodable] = [
                "started": AnyCodable(true),
                "id": AnyCodable(activity.id),
            ]

            // Include push token if already available
            if #available(iOS 16.2, *) {
                if let token = await LiveActivityPushTokenStore.shared.currentToken {
                    result["pushToken"] = AnyCodable(token)
                }
            }

            return AnyCodable(result)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Update

    private func handleUpdate(payload: AnyCodable?) async throws -> AnyCodable {
        guard let data = SharedActivityData.from(payload: payload) else {
            throw BridgeError.invalidPayload("Missing required 'title' field for Live Activity update")
        }

        let state = PWAKitActivityAttributes.ContentState(data: data)

        for activity in Activity<PWAKitActivityAttributes>.activities {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }

        AppGroupStorage.saveActivityData(data)

        return AnyCodable([
            "updated": AnyCodable(true),
        ])
    }

    // MARK: - End

    private func handleEnd(payload: AnyCodable?) async throws -> AnyCodable {
        let dismissalPolicyString = payload?["dismissalPolicy"]?.stringValue ?? "default"
        let dismissalPolicy: ActivityUIDismissalPolicy = switch dismissalPolicyString {
        case "immediate":
            .immediate
        default:
            .default
        }

        for activity in Activity<PWAKitActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: dismissalPolicy)
        }

        AppGroupStorage.removeActivityData()

        // Clear push token when activity ends
        if #available(iOS 16.2, *) {
            await LiveActivityPushTokenStore.shared.clearToken()
        }

        return AnyCodable([
            "ended": AnyCodable(true),
        ])
    }

    // MARK: - Get State

    private func handleGetState() -> AnyCodable {
        let activities = Activity<PWAKitActivityAttributes>.activities
        let hasActive = !activities.isEmpty

        var result: [String: AnyCodable] = [
            "active": AnyCodable(hasActive),
            "count": AnyCodable(activities.count),
        ]

        if let first = activities.first {
            result["id"] = AnyCodable(first.id)
            let data = first.content.state.data
            result["title"] = AnyCodable(data.title)
            if let subtitle = data.subtitle {
                result["subtitle"] = AnyCodable(subtitle)
            }
            if let progress = data.progress {
                result["progress"] = AnyCodable(progress)
            }
        }

        return AnyCodable(result)
    }

    // MARK: - Are Activities Enabled

    private func handleAreActivitiesEnabled() -> AnyCodable {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        return AnyCodable([
            "enabled": AnyCodable(enabled),
        ])
    }

    // MARK: - Get Push Token

    private func handleGetPushToken() async -> AnyCodable {
        if #available(iOS 16.2, *) {
            let token = await LiveActivityPushTokenStore.shared.currentToken
            return AnyCodable([
                "token": token.map { AnyCodable($0) } ?? AnyCodable(NSNull()),
            ])
        } else {
            return AnyCodable([
                "token": AnyCodable(NSNull()),
                "reason": AnyCodable("Push tokens require iOS 16.2+"),
            ])
        }
    }
}
