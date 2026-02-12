import Foundation
import UIKit
import WebKit

// MARK: - AdaptiveStyleObserver

/// Observes the WKWebView's background color and adapts the window's user interface style.
///
/// `AdaptiveStyleObserver` provides automatic light/dark mode switching based on the
/// web page's background color. This allows the native app to seamlessly match the
/// theme of the web content being displayed.
///
/// ## How It Works
///
/// The observer uses KVO to monitor the `underPageBackgroundColor` property of WKWebView
/// (available on iOS 15+). When the color changes, it analyzes the perceived brightness
/// and sets the window's `overrideUserInterfaceStyle` accordingly:
/// - Dark background colors → `.dark` style
/// - Light background colors → `.light` style
///
/// ## Usage
///
/// ```swift
/// let observer = AdaptiveStyleObserver()
/// observer.observe(webView: myWebView, window: myWindow)
///
/// // Later, when done:
/// observer.stopObserving()
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with UIKit components.
@MainActor
public final class AdaptiveStyleObserver {
    /// The KVO observation token for tracking background color changes.
    private var observation: NSKeyValueObservation?

    /// Weak reference to the observed window.
    private weak var observedWindow: UIWindow?

    /// The brightness threshold for determining light vs dark mode.
    ///
    /// Colors with perceived brightness below this threshold are considered dark.
    /// Default value of 0.5 provides a reasonable midpoint.
    public var brightnessThreshold: CGFloat = 0.5

    /// Creates a new adaptive style observer.
    public init() {}

    deinit {
        // Note: NSKeyValueObservation automatically invalidates on dealloc,
        // but we explicitly nil it for clarity
        MainActor.assumeIsolated {
            observation?.invalidate()
            observation = nil
        }
    }

    // MARK: - Public API

    /// Begins observing the WebView's background color and adapting the window style.
    ///
    /// When the web page's background color changes, the observer will automatically
    /// update the window's `overrideUserInterfaceStyle` to match (light or dark).
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to observe.
    ///   - window: The UIWindow whose style should be adapted.
    public func observe(webView: WKWebView, window: UIWindow) {
        // Stop any existing observation
        stopObserving()

        observedWindow = window

        // Observe underPageBackgroundColor (iOS 15+)
        observation = webView.observe(
            \.underPageBackgroundColor,
            options: [.new, .initial]
        ) { [weak self] webView, _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleColorChange(webView.underPageBackgroundColor)
            }
        }
    }

    /// Stops observing and resets the window style to automatic.
    ///
    /// Call this method when you no longer want the observer to control
    /// the window's user interface style.
    public func stopObserving() {
        observation?.invalidate()
        observation = nil

        // Reset to automatic (system-controlled) style
        observedWindow?.overrideUserInterfaceStyle = .unspecified
        observedWindow = nil
    }

    /// Determines the appropriate user interface style for a given color.
    ///
    /// This method analyzes the perceived brightness of the color and returns
    /// the style that would provide good contrast.
    ///
    /// - Parameter color: The color to analyze.
    /// - Returns: `.dark` if the color is light, `.light` if the color is dark.
    public func userInterfaceStyle(for color: UIColor?) -> UIUserInterfaceStyle {
        guard let color else {
            return .unspecified
        }

        let brightness = perceivedBrightness(of: color)

        // If the background is dark, use dark mode
        // If the background is light, use light mode
        return brightness < brightnessThreshold ? .dark : .light
    }

    // MARK: - Private Helpers

    /// Handles a background color change by updating the window style.
    ///
    /// - Parameter color: The new background color.
    private func handleColorChange(_ color: UIColor?) {
        guard let window = observedWindow else { return }

        let style = userInterfaceStyle(for: color)
        window.overrideUserInterfaceStyle = style
    }

    /// Calculates the perceived brightness of a color.
    ///
    /// Uses the relative luminance formula based on human perception,
    /// which weights green more heavily than red, and red more than blue.
    ///
    /// Formula: Y = 0.299R + 0.587G + 0.114B
    ///
    /// - Parameter color: The color to analyze.
    /// - Returns: A value from 0.0 (black) to 1.0 (white).
    private func perceivedBrightness(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // Attempt to get RGB components
        // Note: This may fail for colors in non-RGB color spaces
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            // Fallback: try to get brightness from HSB
            var brightness: CGFloat = 0
            if color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil) {
                return brightness
            }
            // Default to mid-brightness if all else fails
            return 0.5
        }

        // Calculate relative luminance using the standard formula
        // This formula accounts for human perception of color brightness
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }
}

// MARK: - Color Analysis Utilities

extension AdaptiveStyleObserver {
    /// Determines if a color is considered "dark".
    ///
    /// - Parameter color: The color to analyze.
    /// - Returns: `true` if the color's perceived brightness is below the threshold.
    public func isDark(_ color: UIColor?) -> Bool {
        guard let color else { return false }
        return perceivedBrightness(of: color) < brightnessThreshold
    }

    /// Determines if a color is considered "light".
    ///
    /// - Parameter color: The color to analyze.
    /// - Returns: `true` if the color's perceived brightness is at or above the threshold.
    public func isLight(_ color: UIColor?) -> Bool {
        guard let color else { return false }
        return perceivedBrightness(of: color) >= brightnessThreshold
    }
}
