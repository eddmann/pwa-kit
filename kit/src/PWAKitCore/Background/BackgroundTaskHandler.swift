import BackgroundTasks
import Foundation
import WidgetKit

// MARK: - BackgroundTaskHandler

/// Handles background app refresh for keeping widget data up to date.
///
/// `BackgroundTaskHandler` registers a `BGAppRefreshTask` that iOS invokes
/// periodically to fetch fresh data from a configured URL and update widgets.
///
/// ## Setup
///
/// 1. Call `registerTasks()` in `application(_:didFinishLaunchingWithOptions:)`
/// 2. Configure a refresh URL from JavaScript via the bridge or `AppGroupStorage`
/// 3. Add `com.pwakit.widget-refresh` to `BGTaskSchedulerPermittedIdentifiers` in Info.plist
/// 4. Add `fetch` to `UIBackgroundModes` in Info.plist
///
/// ## Data Flow
///
/// 1. iOS wakes the app via `BGAppRefreshTask`
/// 2. Handler reads the refresh URL from `AppGroupStorage`
/// 3. Fetches JSON data from the URL
/// 4. Parses widget/activity data from the response
/// 5. Writes to `AppGroupStorage` and triggers `WidgetCenter.reloadAllTimelines()`
/// 6. Reschedules the next refresh
///
/// ## Expected JSON Response
///
/// The refresh URL should return JSON in this format:
/// ```json
/// {
///   "widgets": [
///     { "kind": "status", "title": "Steps", "value": "9,200" }
///   ],
///   "liveActivity": {
///     "title": "Order #1234",
///     "subtitle": "On the way!",
///     "progress": 0.75
///   }
/// }
/// ```
public enum BackgroundTaskHandler {
    /// The task identifier for widget background refresh.
    public static let widgetRefreshTaskId = "com.pwakit.widget-refresh"

    // MARK: - Registration

    /// Registers background tasks with the system.
    ///
    /// Call this once during `application(_:didFinishLaunchingWithOptions:)`,
    /// before the app finishes launching.
    public static func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: widgetRefreshTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                await handleWidgetRefresh(task: refreshTask)
            }
        }

        #if DEBUG
            print("[BackgroundTaskHandler] Registered background task: \(widgetRefreshTaskId)")
        #endif
    }

    // MARK: - Scheduling

    /// Schedules the next widget background refresh.
    ///
    /// iOS determines the actual refresh time based on system conditions and
    /// app usage patterns. The earliest begin date is set to 15 minutes from now.
    public static func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: widgetRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
                print("[BackgroundTaskHandler] Scheduled widget refresh")
            #endif
        } catch {
            #if DEBUG
                print("[BackgroundTaskHandler] Failed to schedule refresh: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Handler

    /// Handles a widget background refresh task.
    ///
    /// Fetches data from the configured refresh URL, updates App Group storage,
    /// and triggers widget timeline reloads.
    ///
    /// - Parameter task: The background refresh task from the system.
    @MainActor
    static func handleWidgetRefresh(task: BGAppRefreshTask) async {
        // Schedule next refresh before doing work
        scheduleWidgetRefresh()

        guard let urlString = AppGroupStorage.loadRefreshUrl(),
              let url = URL(string: urlString) else
        {
            #if DEBUG
                print("[BackgroundTaskHandler] No refresh URL configured")
            #endif
            task.setTaskCompleted(success: true)
            return
        }

        // Set up expiration handler
        let fetchTask = Task {
            await fetchAndUpdateData(from: url)
        }

        task.expirationHandler = {
            fetchTask.cancel()
        }

        let success = await fetchTask.value
        task.setTaskCompleted(success: success)
    }

    // MARK: - Data Fetching

    /// Fetches data from the given URL and updates App Group storage.
    ///
    /// - Parameter url: The URL to fetch widget/activity data from.
    /// - Returns: Whether the fetch and update succeeded.
    static func fetchAndUpdateData(from url: URL) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode) else
            {
                #if DEBUG
                    print("[BackgroundTaskHandler] HTTP error from refresh URL")
                #endif
                return false
            }

            try parseAndStoreRefreshData(data)

            AppGroupStorage.recordRefresh()

            WidgetCenter.shared.reloadAllTimelines()

            #if DEBUG
                print("[BackgroundTaskHandler] Successfully refreshed widget data")
            #endif

            return true
        } catch {
            #if DEBUG
                print("[BackgroundTaskHandler] Fetch failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Parsing

    /// Parses refresh response data and stores it in App Group storage.
    ///
    /// - Parameter data: The JSON data from the refresh URL.
    /// - Throws: If the JSON cannot be parsed.
    static func parseAndStoreRefreshData(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Parse and store widget data
        if let widgets = json["widgets"] as? [[String: Any]] {
            for widgetDict in widgets {
                guard let kind = widgetDict["kind"] as? String,
                      let title = widgetDict["title"] as? String else
                {
                    continue
                }

                let widgetData = SharedWidgetData(
                    kind: kind,
                    title: title,
                    value: widgetDict["value"] as? String,
                    subtitle: widgetDict["subtitle"] as? String,
                    icon: widgetDict["icon"] as? String,
                    tint: widgetDict["tint"] as? String,
                    url: widgetDict["url"] as? String
                )

                AppGroupStorage.saveWidgetData(widgetData)
            }
        }

        // Parse and store live activity data
        if let activityDict = json["liveActivity"] as? [String: Any],
           let title = activityDict["title"] as? String
        {
            var fields: [String: String]?
            if let fieldsDict = activityDict["fields"] as? [String: String] {
                fields = fieldsDict
            }

            let activityData = SharedActivityData(
                title: title,
                subtitle: activityDict["subtitle"] as? String,
                progress: activityDict["progress"] as? Double,
                icon: activityDict["icon"] as? String,
                tint: activityDict["tint"] as? String,
                fields: fields
            )

            AppGroupStorage.saveActivityData(activityData)
        }
    }
}
