import Foundation
import WidgetKit

// MARK: - WidgetModule

/// A module that provides Lock Screen and Home Screen widget support to JavaScript.
///
/// `WidgetModule` allows PWAs to push data to iOS widgets by writing to a shared
/// App Group container and triggering WidgetKit timeline reloads.
///
/// ## Architecture
///
/// 1. PWA calls `update` with widget data via the bridge
/// 2. Module writes data to shared App Group UserDefaults
/// 3. Module triggers WidgetKit timeline reload
/// 4. Widget Extension reads data from shared container and renders
///
/// ## Supported Actions
///
/// - `update(kind, title, value?, subtitle?, icon?, tint?, url?)`:
///   Update widget content and trigger a timeline reload.
/// - `remove(kind)`: Remove widget data for a specific kind.
/// - `reloadAll()`: Force reload all widget timelines.
/// - `getKinds()`: List available widget kinds.
///
/// ## Example
///
/// Update a status widget:
/// ```json
/// {
///   "module": "widget",
///   "action": "update",
///   "payload": {
///     "kind": "status",
///     "title": "Steps Today",
///     "value": "8,421",
///     "subtitle": "Goal: 10,000",
///     "icon": "figure.walk",
///     "tint": "#34C759",
///     "url": "https://app.example.com/steps"
///   }
/// }
/// ```
public struct WidgetModule: PWAModule {
    public static let moduleName = "widget"
    public static let supportedActions = ["update", "remove", "reloadAll", "getKinds"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "update":
            return try handleUpdate(payload: payload)

        case "remove":
            return try handleRemove(payload: payload)

        case "reloadAll":
            return handleReloadAll()

        case "getKinds":
            return handleGetKinds()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Update

    private func handleUpdate(payload: AnyCodable?) throws -> AnyCodable {
        guard let data = SharedWidgetData.from(payload: payload) else {
            throw BridgeError.invalidPayload(
                "Missing required fields 'kind' and 'title' for widget update"
            )
        }

        AppGroupStorage.saveWidgetData(data)

        WidgetCenter.shared.reloadTimelines(ofKind: data.kind)

        return AnyCodable([
            "updated": AnyCodable(true),
            "kind": AnyCodable(data.kind),
        ])
    }

    // MARK: - Remove

    private func handleRemove(payload: AnyCodable?) throws -> AnyCodable {
        guard let kind = payload?["kind"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'kind' field")
        }

        AppGroupStorage.removeWidgetData(kind: kind)

        WidgetCenter.shared.reloadTimelines(ofKind: kind)

        return AnyCodable([
            "removed": AnyCodable(true),
            "kind": AnyCodable(kind),
        ])
    }

    // MARK: - Reload All

    private func handleReloadAll() -> AnyCodable {
        WidgetCenter.shared.reloadAllTimelines()

        return AnyCodable([
            "reloaded": AnyCodable(true),
        ])
    }

    // MARK: - Get Kinds

    private func handleGetKinds() -> AnyCodable {
        // Return the registered widget kinds that the extension supports
        AnyCodable([
            "kinds": AnyCodable([
                AnyCodable("status"),
                AnyCodable("compact"),
            ]),
        ])
    }
}
