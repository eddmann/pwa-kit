import SwiftUI
import UIKit

// MARK: - ConnectionErrorView

/// A connection error view with animated error icon and retry indicator.
///
/// `ConnectionErrorView` displays a centered error icon with a pulsing animation,
/// a "Connecting..." message, and an automatic retry progress indicator. This view
/// is shown when the webview fails to load due to network connectivity issues.
///
/// ## Usage
///
/// ```swift
/// struct ContentView: View {
///     @State private var hasConnectionError = false
///     @State private var retryProgress = 0.0
///
///     var body: some View {
///         ZStack {
///             // Main content
///             WebViewContainer(...)
///
///             // Error overlay
///             if hasConnectionError {
///                 ConnectionErrorView(retryProgress: retryProgress)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Animations
///
/// The view includes two animations:
/// - A pulse animation on the error icon that runs continuously
/// - A countdown progress ring that fills as retry approaches
public struct ConnectionErrorView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a new connection error view.
    ///
    /// - Parameters:
    ///   - retryProgress: Progress towards automatic retry (0.0 to 1.0). Default is 0.
    ///   - message: Custom message to display. Default is "Connecting...".
    public init(
        retryProgress: Double = 0,
        message: String = "Connecting..."
    ) {
        self.retryProgress = retryProgress
        self.message = message
    }

    // MARK: Public

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background overlay
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                // Error icon with pulse animation
                errorIconView

                // Message text
                Text(message)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.secondaryLabel))

                // Automatic retry indicator
                retryIndicatorView
            }
            .padding(.horizontal, 40)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: Private

    // MARK: - Animation State

    /// Animation state for the pulsing effect.
    @State private var isPulsing = false

    /// Animation state for the icon scale effect.
    @State private var iconScale = 1.0

    /// The progress towards automatic retry (0.0 to 1.0).
    private let retryProgress: Double

    /// Optional custom message to display.
    private let message: String

    // MARK: - Subviews

    /// The error icon view with pulsing animation.
    private var errorIconView: some View {
        ZStack {
            // Pulse ring (outer)
            Circle()
                .stroke(
                    Color(UIColor.systemOrange).opacity(isPulsing ? 0.2 : 0.4),
                    lineWidth: 3
                )
                .frame(width: 110, height: 110)
                .scaleEffect(isPulsing ? 1.15 : 1.0)

            // Icon background
            Circle()
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: 100, height: 100)
                .shadow(
                    color: Color(UIColor.systemGray4).opacity(0.5),
                    radius: isPulsing ? 15 : 10,
                    x: 0,
                    y: 5
                )

            // Error icon
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(Color(UIColor.systemOrange))
                .scaleEffect(iconScale)
        }
        .scaleEffect(isPulsing ? 1.02 : 1.0)
    }

    /// The automatic retry indicator view.
    private var retryIndicatorView: some View {
        VStack(spacing: 12) {
            // Retry progress ring
            ZStack {
                // Track ring
                Circle()
                    .stroke(
                        Color(UIColor.systemGray5),
                        lineWidth: 4
                    )
                    .frame(width: 44, height: 44)

                // Progress ring
                Circle()
                    .trim(from: 0, to: retryProgress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: retryProgress)

                // Retry icon
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            // Retry text
            Text("Retrying automatically...")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
    }

    // MARK: - Animations

    /// Starts the pulsing animation for the error icon.
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }

        // Add a subtle bounce to the icon
        withAnimation(
            .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
                .delay(0.2)
        ) {
            iconScale = 1.05
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct ConnectionErrorView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Default state
                ConnectionErrorView(retryProgress: 0.0)
                    .previewDisplayName("No Progress")

                // Retry in progress
                ConnectionErrorView(retryProgress: 0.45)
                    .previewDisplayName("45% Retry Progress")

                // Almost ready to retry
                ConnectionErrorView(retryProgress: 0.9)
                    .previewDisplayName("90% Retry Progress")

                // Custom message
                ConnectionErrorView(
                    retryProgress: 0.3,
                    message: "No internet connection"
                )
                .previewDisplayName("Custom Message")

                // Dark mode
                ConnectionErrorView(retryProgress: 0.5)
                    .preferredColorScheme(.dark)
                    .previewDisplayName("Dark Mode")
            }
        }
    }
#endif
