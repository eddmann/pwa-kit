import SwiftUI
import UIKit

// MARK: - LoadingView

/// A full-screen loading overlay view with progress indicator and branding.
///
/// `LoadingView` displays a centered loading indicator with an optional app icon
/// and a progress bar. It uses smooth animations for appearing/disappearing and
/// progress updates.
///
/// ## Usage
///
/// ```swift
/// struct ContentView: View {
///     @State private var isLoading = true
///     @State private var progress = 0.0
///
///     var body: some View {
///         ZStack {
///             // Main content
///             WebViewContainer(...)
///
///             // Loading overlay
///             if isLoading {
///                 LoadingView(progress: progress)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Customization
///
/// The view supports customization through initializer parameters:
/// - `progress`: The current loading progress (0.0 to 1.0)
/// - `showProgress`: Whether to show the progress bar
/// - `showAppIcon`: Whether to show the app icon placeholder
/// - `backgroundColor`: Custom background color (optional, defaults to system)
/// - `accentColor`: Custom accent color for progress bar (optional, defaults to system)
public struct LoadingView: View {
    // MARK: - Properties

    /// The current loading progress (0.0 to 1.0).
    private let progress: Double

    /// Whether to show the progress bar.
    private let showProgress: Bool

    /// Whether to show the app icon.
    private let showAppIcon: Bool

    /// Custom background color (optional).
    private let backgroundColor: Color?

    /// Custom accent color for progress indicators (optional).
    private let accentColor: Color?

    // MARK: - Animation State

    /// Animation state for the pulsing effect.
    @State private var isPulsing = false

    // MARK: - Initialization

    /// Creates a new loading view.
    ///
    /// - Parameters:
    ///   - progress: The current loading progress (0.0 to 1.0). Default is 0.
    ///   - showProgress: Whether to show the progress bar. Default is true.
    ///   - showAppIcon: Whether to show the app icon. Default is true.
    ///   - backgroundColor: Custom background color. Default is nil (system background).
    ///   - accentColor: Custom accent color for progress bar. Default is nil (system accent).
    public init(
        progress: Double = 0,
        showProgress: Bool = true,
        showAppIcon: Bool = true,
        backgroundColor: Color? = nil,
        accentColor: Color? = nil
    ) {
        self.progress = progress
        self.showProgress = showProgress
        self.showAppIcon = showAppIcon
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background overlay (custom or system default)
            (backgroundColor ?? Color(UIColor.systemBackground))
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                // App icon or branding
                if showAppIcon {
                    appIconView
                }

                // Progress bar
                if showProgress {
                    progressBarView
                }
            }
            .padding(.horizontal, 40)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        .onAppear {
            startPulsingAnimation()
        }
    }

    // MARK: - Subviews

    /// The app icon view with pulsing animation.
    ///
    /// Uses LaunchIcon from asset catalog if available, otherwise falls back to SF Symbol.
    private var appIconView: some View {
        ZStack {
            // Centered container
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .frame(width: 200, height: 200)

            // LaunchIcon from asset catalog or SF Symbol fallback
            if let uiImage = UIImage(named: "LaunchIcon") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                // Fallback to SF Symbol if no LaunchIcon provided
                Image(systemName: "app.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
        .scaleEffect(isPulsing ? 1.02 : 1.0)
    }

    /// The progress bar view.
    private var progressBarView: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 6)

                    // Fill (custom accent or system default)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor ?? Color.accentColor)
                        .frame(
                            width: max(0, min(geometry.size.width, geometry.size.width * progress)),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.2), value: progress)
                }
            }
            .frame(height: 6)

            // Progress text (optional, shown when progress > 0)
            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(accentColor ?? Color(UIColor.secondaryLabel))
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
        .frame(maxWidth: 100)
    }

    // MARK: - Animations

    /// Starts the pulsing animation for the app icon.
    private func startPulsingAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct LoadingView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Default state
                LoadingView(progress: 0.0)
                    .previewDisplayName("No Progress")

                // With progress
                LoadingView(progress: 0.45)
                    .previewDisplayName("45% Progress")

                // Near complete
                LoadingView(progress: 0.95)
                    .previewDisplayName("95% Progress")

                // No progress bar
                LoadingView(progress: 0, showProgress: false)
                    .previewDisplayName("No Progress Bar")

                // No icon
                LoadingView(progress: 0.5, showAppIcon: false)
                    .previewDisplayName("No App Icon")

                // Dark mode
                LoadingView(progress: 0.6)
                    .preferredColorScheme(.dark)
                    .previewDisplayName("Dark Mode")
            }
        }
    }
#endif
