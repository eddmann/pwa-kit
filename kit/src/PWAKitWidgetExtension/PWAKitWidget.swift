import SwiftUI
import WidgetKit

// MARK: - PWAKit Widget

/// Main widget definition for PWAKit Lock Screen and Home Screen widgets.
///
/// This widget reads data from the shared App Group container that the
/// main app writes to via the `WidgetModule` bridge. The PWA controls
/// content by calling `ios.widget.update()` from JavaScript.
///
/// ## Setup
///
/// 1. Add a Widget Extension target to your Xcode project
/// 2. Add this file and `PWAKitWidgetViews.swift` to the extension target
/// 3. Configure the same App Group in both the main app and extension
/// 4. Set `features.widgets: true` in `pwa-config.json`
///
/// ## Customization
///
/// The default widget kinds are `status` (larger display) and `compact`
/// (minimal display). You can add more by duplicating the widget
/// configurations and adding new kinds.
@main
struct PWAKitWidgetBundle: WidgetBundle {
    var body: some Widget {
        PWAKitStatusWidget()
        PWAKitCompactWidget()
        if #available(iOS 16.1, *) {
            PWAKitLiveActivityWidget()
        }
    }
}

// MARK: - Status Widget

/// A status widget that displays a title, large value, subtitle, and icon.
///
/// Supports system small, medium, and Lock Screen widget families.
struct PWAKitStatusWidget: Widget {
    let kind: String = "status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PWAKitTimelineProvider(kind: kind)) { entry in
            PWAKitStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Status")
        .description("Shows a status value from your app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Compact Widget

/// A compact widget that shows minimal information — icon and title only.
struct PWAKitCompactWidget: Widget {
    let kind: String = "compact"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PWAKitTimelineProvider(kind: kind)) { entry in
            PWAKitCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("Compact")
        .description("Shows a compact status from your app.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Timeline Provider

/// Timeline provider that reads widget data from the shared App Group container.
struct PWAKitTimelineProvider: TimelineProvider {
    let kind: String

    /// The App Group identifier — must match the main app's configuration.
    /// Update this value to match your app's App Group ID.
    private static let appGroupId = "group.com.pwakit.app"

    func placeholder(in _: Context) -> PWAKitWidgetEntry {
        PWAKitWidgetEntry(
            date: Date(),
            title: "Loading...",
            value: "--",
            subtitle: nil,
            icon: "app.fill",
            tint: nil
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (PWAKitWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PWAKitWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Reload after 15 minutes (WidgetKit may throttle more aggressively)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> PWAKitWidgetEntry {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: "pwakit.widget.\(kind)"),
              let widgetData = try? JSONDecoder().decode(WidgetDataDTO.self, from: data) else
        {
            return PWAKitWidgetEntry(
                date: Date(),
                title: "No Data",
                value: nil,
                subtitle: "Open app to configure",
                icon: "app.fill",
                tint: nil
            )
        }

        return PWAKitWidgetEntry(
            date: widgetData.updatedAt,
            title: widgetData.title,
            value: widgetData.value,
            subtitle: widgetData.subtitle,
            icon: widgetData.icon,
            tint: widgetData.tint
        )
    }
}

// MARK: - Widget Entry

/// Timeline entry containing the data to display in the widget.
struct PWAKitWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let value: String?
    let subtitle: String?
    let icon: String?
    let tint: String?
}

// MARK: - Widget Data DTO

/// Lightweight Codable struct for reading shared widget data.
/// Mirrors `SharedWidgetData` without depending on PWAKitCore.
struct WidgetDataDTO: Codable {
    let kind: String
    let title: String
    let value: String?
    let subtitle: String?
    let icon: String?
    let tint: String?
    let url: String?
    let updatedAt: Date
}
