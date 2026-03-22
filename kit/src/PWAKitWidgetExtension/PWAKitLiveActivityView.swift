import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget

/// Live Activity widget providing Dynamic Island and Lock Screen Live Activity views.
///
/// This widget renders the Dynamic Island UI in three contexts:
/// - **Compact leading/trailing**: Minimal views shown in the pill-shaped island
/// - **Expanded**: Full view shown when the Dynamic Island is long-pressed
/// - **Lock Screen banner**: Shown on the Lock Screen below the clock
///
/// ## Setup
///
/// 1. Add this file to your Widget Extension target
/// 2. Add `PWAKitActivityAttributes` to your `NSSupportsLiveActivities` Info.plist
/// 3. Set `features.liveActivity: true` in `pwa-config.json`
@available(iOS 16.1, *)
struct PWAKitLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PWAKitActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            lockScreenView(for: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(for: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(for: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(for: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(for: context)
                }
            } compactLeading: {
                compactLeading(for: context)
            } compactTrailing: {
                compactTrailing(for: context)
            } minimal: {
                minimal(for: context)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = data.icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tintColor(for: data))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let subtitle = data.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let progress = data.progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(tintColor(for: data))
            }

            if let fields = data.fields, !fields.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(fields.prefix(3)), id: \.key) { key, value in
                        VStack(spacing: 2) {
                            Text(value)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(key)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Compact Views (Dynamic Island pill)

    @ViewBuilder
    private func compactLeading(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        if let icon = data.icon {
            Image(systemName: icon)
                .foregroundStyle(tintColor(for: data))
        } else {
            Image(systemName: "app.fill")
                .foregroundStyle(tintColor(for: data))
        }
    }

    @ViewBuilder
    private func compactTrailing(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        if let progress = data.progress {
            ProgressView(value: min(max(progress, 0), 1))
                .progressViewStyle(.circular)
                .tint(tintColor(for: data))
        } else if let subtitle = data.subtitle {
            Text(subtitle)
                .font(.caption2)
                .lineLimit(1)
        }
    }

    // MARK: - Minimal View (when multiple activities compete)

    @ViewBuilder
    private func minimal(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        if let icon = data.icon {
            Image(systemName: icon)
                .foregroundStyle(tintColor(for: data))
        } else {
            ProgressView(value: data.progress ?? 0)
                .progressViewStyle(.circular)
                .tint(tintColor(for: data))
        }
    }

    // MARK: - Expanded Views (Dynamic Island long-press)

    @ViewBuilder
    private func expandedLeading(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        if let icon = data.icon {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tintColor(for: data))
        }
    }

    @ViewBuilder
    private func expandedTrailing(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        if let fields = data.fields, let firstValue = fields.values.first {
            Text(firstValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(tintColor(for: data))
        }
    }

    @ViewBuilder
    private func expandedCenter(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data
        VStack(spacing: 2) {
            Text(data.title)
                .font(.headline)
                .lineLimit(1)

            if let subtitle = data.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func expandedBottom(for context: ActivityViewContext<PWAKitActivityAttributes>) -> some View {
        let data = context.state.data

        VStack(spacing: 8) {
            if let progress = data.progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(tintColor(for: data))
            }

            if let fields = data.fields, !fields.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(fields.prefix(4)), id: \.key) { key, value in
                        VStack(spacing: 2) {
                            Text(value)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(key)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func tintColor(for data: SharedActivityData) -> Color {
        guard let hex = data.tint else { return .accentColor }
        return Color(hex: hex)
    }
}

// MARK: - ActivityAttributes Import

/// Re-import the attributes type from the main app.
/// In a real project, this would be in a shared framework or duplicated.
/// For now, it matches the definition in LiveActivityModule.swift.
@available(iOS 16.1, *)
struct PWAKitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        let data: SharedActivityData
    }

    let activityId: String
}

/// Lightweight copy of SharedActivityData for the widget extension.
/// In production, share this via a framework target or Swift package.
struct SharedActivityData: Codable, Hashable, Sendable {
    let title: String
    let subtitle: String?
    let progress: Double?
    let icon: String?
    let tint: String?
    let fields: [String: String]?
}
