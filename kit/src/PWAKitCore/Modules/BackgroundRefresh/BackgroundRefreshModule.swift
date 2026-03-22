import Foundation

// MARK: - BackgroundRefreshModule

/// A module that allows PWAs to configure background refresh for widgets.
///
/// `BackgroundRefreshModule` provides JavaScript with the ability to set a URL
/// that the app fetches periodically in the background to keep widget data fresh.
///
/// ## Supported Actions
///
/// - `configureUrl(url)`: Set the URL to fetch during background refresh.
/// - `removeUrl()`: Remove the configured refresh URL.
/// - `getStatus()`: Get the last refresh timestamp.
/// - `scheduleRefresh()`: Schedule the next background refresh.
///
/// ## Example
///
/// ```json
/// {
///   "module": "backgroundRefresh",
///   "action": "configureUrl",
///   "payload": {
///     "url": "https://api.example.com/widget-data"
///   }
/// }
/// ```
public struct BackgroundRefreshModule: PWAModule {
    public static let moduleName = "backgroundRefresh"
    public static let supportedActions = ["configureUrl", "removeUrl", "getStatus", "scheduleRefresh"]

    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "configureUrl":
            return try handleConfigureUrl(payload: payload)

        case "removeUrl":
            return handleRemoveUrl()

        case "getStatus":
            return handleGetStatus()

        case "scheduleRefresh":
            return handleScheduleRefresh()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Configure URL

    private func handleConfigureUrl(payload: AnyCodable?) throws -> AnyCodable {
        guard let url = payload?["url"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'url' field")
        }

        guard URL(string: url) != nil else {
            throw BridgeError.invalidPayload("Invalid URL: \(url)")
        }

        AppGroupStorage.saveRefreshUrl(url)

        // Schedule a background refresh now that a URL is configured
        BackgroundTaskHandler.scheduleWidgetRefresh()

        return AnyCodable([
            "configured": AnyCodable(true),
            "url": AnyCodable(url),
        ])
    }

    // MARK: - Remove URL

    private func handleRemoveUrl() -> AnyCodable {
        AppGroupStorage.removeRefreshUrl()

        return AnyCodable([
            "removed": AnyCodable(true),
        ])
    }

    // MARK: - Get Status

    private func handleGetStatus() -> AnyCodable {
        let url = AppGroupStorage.loadRefreshUrl()
        let lastRefresh = AppGroupStorage.lastRefreshTimestamp()

        var result: [String: AnyCodable] = [
            "configured": AnyCodable(url != nil),
        ]

        if let url {
            result["url"] = AnyCodable(url)
        }

        if let lastRefresh {
            result["lastRefresh"] = AnyCodable(lastRefresh)
        }

        return AnyCodable(result)
    }

    // MARK: - Schedule Refresh

    private func handleScheduleRefresh() -> AnyCodable {
        BackgroundTaskHandler.scheduleWidgetRefresh()

        return AnyCodable([
            "scheduled": AnyCodable(true),
        ])
    }
}
