import SwiftUI
import WidgetKit

// MARK: - Status Widget View

/// SwiftUI view for the status widget.
///
/// Adapts to different widget families:
/// - `systemSmall` / `systemMedium`: Full card with icon, title, value, subtitle
/// - `accessoryCircular`: Circular gauge with icon
/// - `accessoryRectangular`: Rectangular Lock Screen widget
/// - `accessoryInline`: Single-line inline text
struct PWAKitStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PWAKitWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            systemSmallView
        case .systemMedium:
            systemMediumView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            systemSmallView
        }
    }

    // MARK: - System Small

    private var systemSmallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let icon = entry.icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(tintColor)
                }
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let value = entry.value {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(tintColor)
            }

            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - System Medium

    private var systemMediumView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let icon = entry.icon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(tintColor)
                    }
                    Text(entry.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let value = entry.value {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(tintColor)
                }

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let icon = entry.icon {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(tintColor.opacity(0.3))
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - Accessory Circular (Lock Screen)

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                if let icon = entry.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                if let value = entry.value {
                    Text(value)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }

    // MARK: - Accessory Rectangular (Lock Screen)

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let icon = entry.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(entry.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }

            if let value = entry.value {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Accessory Inline (Lock Screen)

    private var accessoryInlineView: some View {
        HStack(spacing: 4) {
            if let icon = entry.icon {
                Image(systemName: icon)
            }
            if let value = entry.value {
                Text("\(entry.title): \(value)")
            } else {
                Text(entry.title)
            }
        }
    }

    // MARK: - Helpers

    private var tintColor: Color {
        guard let hex = entry.tint else { return .accentColor }
        return Color(hex: hex)
    }
}

// MARK: - Compact Widget View

/// SwiftUI view for the compact widget, optimized for Lock Screen accessories.
struct PWAKitCompactWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PWAKitWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let icon = entry.icon {
                Image(systemName: icon)
                    .font(.title3)
            } else {
                Text(String(entry.title.prefix(2)))
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 6) {
            if let icon = entry.icon {
                Image(systemName: icon)
                    .font(.title3)
            }
            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            if let icon = entry.icon {
                Image(systemName: icon)
            }
            Text(entry.title)
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Creates a Color from a hex string (e.g., "#FF6B35" or "FF6B35").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
