import Foundation
import Testing
import UIKit

@testable import PWAKitApp

@Suite("AdaptiveStyleObserver Tests")
@MainActor
struct AdaptiveStyleObserverTests {
    // MARK: - Initialization

    @Test("Initializes with default brightness threshold")
    func initializesWithDefaultThreshold() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.brightnessThreshold == 0.5)
    }

    @Test("Allows custom brightness threshold")
    func allowsCustomBrightnessThreshold() {
        let observer = AdaptiveStyleObserver()
        observer.brightnessThreshold = 0.3

        #expect(observer.brightnessThreshold == 0.3)
    }

    // MARK: - User Interface Style Determination

    @Test("Returns dark style for dark colors")
    func returnsDarkStyleForDarkColors() {
        let observer = AdaptiveStyleObserver()

        // Pure black
        let blackStyle = observer.userInterfaceStyle(for: .black)
        #expect(blackStyle == .dark)

        // Dark gray
        let darkGrayStyle = observer.userInterfaceStyle(for: UIColor(white: 0.2, alpha: 1.0))
        #expect(darkGrayStyle == .dark)

        // Dark blue
        let darkBlueStyle = observer.userInterfaceStyle(for: UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0))
        #expect(darkBlueStyle == .dark)
    }

    @Test("Returns light style for light colors")
    func returnsLightStyleForLightColors() {
        let observer = AdaptiveStyleObserver()

        // Pure white
        let whiteStyle = observer.userInterfaceStyle(for: .white)
        #expect(whiteStyle == .light)

        // Light gray
        let lightGrayStyle = observer.userInterfaceStyle(for: UIColor(white: 0.8, alpha: 1.0))
        #expect(lightGrayStyle == .light)

        // Light yellow
        let lightYellowStyle = observer.userInterfaceStyle(for: UIColor(
            red: 1.0,
            green: 1.0,
            blue: 0.8,
            alpha: 1.0
        ))
        #expect(lightYellowStyle == .light)
    }

    @Test("Returns unspecified for nil color")
    func returnsUnspecifiedForNilColor() {
        let observer = AdaptiveStyleObserver()

        let style = observer.userInterfaceStyle(for: nil)

        #expect(style == .unspecified)
    }

    @Test("Respects custom brightness threshold")
    func respectsCustomBrightnessThreshold() {
        let observer = AdaptiveStyleObserver()

        // Gray at 0.4 brightness
        let grayColor = UIColor(white: 0.4, alpha: 1.0)

        // With default threshold (0.5), this should be dark
        observer.brightnessThreshold = 0.5
        let defaultStyle = observer.userInterfaceStyle(for: grayColor)
        #expect(defaultStyle == .dark)

        // With lower threshold (0.3), this should be light
        observer.brightnessThreshold = 0.3
        let loweredStyle = observer.userInterfaceStyle(for: grayColor)
        #expect(loweredStyle == .light)
    }

    // MARK: - Color Analysis (isDark/isLight)

    @Test("isDark returns true for dark colors")
    func isDarkReturnsTrueForDarkColors() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isDark(.black) == true)
        #expect(observer.isDark(UIColor(white: 0.2, alpha: 1.0)) == true)
        #expect(observer.isDark(UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1.0)) == true)
    }

    @Test("isDark returns false for light colors")
    func isDarkReturnsFalseForLightColors() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isDark(.white) == false)
        #expect(observer.isDark(UIColor(white: 0.8, alpha: 1.0)) == false)
        #expect(observer.isDark(.yellow) == false)
    }

    @Test("isDark returns false for nil")
    func isDarkReturnsFalseForNil() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isDark(nil) == false)
    }

    @Test("isLight returns true for light colors")
    func isLightReturnsTrueForLightColors() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isLight(.white) == true)
        #expect(observer.isLight(UIColor(white: 0.8, alpha: 1.0)) == true)
        #expect(observer.isLight(.cyan) == true)
    }

    @Test("isLight returns false for dark colors")
    func isLightReturnsFalseForDarkColors() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isLight(.black) == false)
        #expect(observer.isLight(UIColor(white: 0.2, alpha: 1.0)) == false)
    }

    @Test("isLight returns false for nil")
    func isLightReturnsFalseForNil() {
        let observer = AdaptiveStyleObserver()

        #expect(observer.isLight(nil) == false)
    }

    // MARK: - Perceived Brightness Edge Cases

    @Test("Handles RGB colors correctly")
    func handlesRGBColorsCorrectly() {
        let observer = AdaptiveStyleObserver()

        // Red has moderate perceived brightness (0.299)
        // Should be below 0.5 threshold -> dark
        let redStyle = observer.userInterfaceStyle(for: .red)
        #expect(redStyle == .dark)

        // Green has high perceived brightness (0.587)
        // Should be above 0.5 threshold -> light
        let greenStyle = observer.userInterfaceStyle(for: .green)
        #expect(greenStyle == .light)

        // Blue has low perceived brightness (0.114)
        // Should be below 0.5 threshold -> dark
        let blueStyle = observer.userInterfaceStyle(for: .blue)
        #expect(blueStyle == .dark)
    }

    @Test("Handles exact threshold boundary")
    func handlesExactThresholdBoundary() {
        let observer = AdaptiveStyleObserver()
        observer.brightnessThreshold = 0.5

        // Color slightly above 0.5 brightness should be light (>= threshold)
        // Note: Using 0.51 to avoid floating-point precision issues at exact boundary
        let midGray = UIColor(white: 0.51, alpha: 1.0)
        let style = observer.userInterfaceStyle(for: midGray)

        #expect(style == .light)
    }

    @Test("Handles colors with alpha")
    func handlesColorsWithAlpha() {
        let observer = AdaptiveStyleObserver()

        // Semi-transparent black - still dark
        let semiBlack = UIColor(white: 0.1, alpha: 0.5)
        #expect(observer.isDark(semiBlack) == true)

        // Semi-transparent white - still light
        let semiWhite = UIColor(white: 0.9, alpha: 0.5)
        #expect(observer.isLight(semiWhite) == true)
    }

    // MARK: - System Colors

    @Test("Handles system colors")
    func handlesSystemColors() {
        let observer = AdaptiveStyleObserver()

        // System background colors (these adapt to light/dark mode)
        // We test that they can be analyzed without crashing
        _ = observer.userInterfaceStyle(for: .systemBackground)
        _ = observer.userInterfaceStyle(for: .systemGray)
        _ = observer.userInterfaceStyle(for: .label)

        // No crash means success - actual values may vary by system appearance
    }
}
