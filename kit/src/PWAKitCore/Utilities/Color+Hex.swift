import Foundation
import UIKit

// MARK: - UIColor Hex Extension

extension UIColor {
    /// Creates a UIColor from a hex string.
    ///
    /// Supports formats:
    /// - `#RGB` (12-bit, e.g. "#F0A")
    /// - `#RRGGBB` (24-bit, e.g. "#FF00AA")
    /// - `#RRGGBBAA` (32-bit with alpha, e.g. "#FF00AA80")
    /// - Without `#` prefix (e.g. "FF00AA")
    ///
    /// ## Example
    ///
    /// ```swift
    /// let blue = UIColor(hex: "#007AFF")
    /// let red = UIColor(hex: "FF0000")
    /// let semiTransparent = UIColor(hex: "#00000080")
    /// ```
    ///
    /// - Parameter hex: The hex color string.
    /// - Returns: A UIColor instance, or `nil` if the string is invalid.
    public convenience init?(hex: String) {
        // Remove # prefix if present
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        // Validate characters
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hexString.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        let red, green, blue, alpha: CGFloat

        switch hexString.count {
        case 3: // RGB (12-bit)
            red = CGFloat((rgb >> 8) & 0xF) / 15.0
            green = CGFloat((rgb >> 4) & 0xF) / 15.0
            blue = CGFloat(rgb & 0xF) / 15.0
            alpha = 1.0

        case 6: // RRGGBB (24-bit)
            red = CGFloat((rgb >> 16) & 0xFF) / 255.0
            green = CGFloat((rgb >> 8) & 0xFF) / 255.0
            blue = CGFloat(rgb & 0xFF) / 255.0
            alpha = 1.0

        case 8: // RRGGBBAA (32-bit)
            red = CGFloat((rgb >> 24) & 0xFF) / 255.0
            green = CGFloat((rgb >> 16) & 0xFF) / 255.0
            blue = CGFloat((rgb >> 8) & 0xFF) / 255.0
            alpha = CGFloat(rgb & 0xFF) / 255.0

        default:
            return nil
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Returns the hex string representation of this color.
    ///
    /// - Parameter includeAlpha: Whether to include alpha component. Defaults to `false`.
    /// - Returns: A hex string like "#RRGGBB" or "#RRGGBBAA".
    public func hexString(includeAlpha: Bool = false) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        if includeAlpha {
            let a = Int(alpha * 255)
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }
}

// MARK: - SwiftUI Color Extension

#if canImport(SwiftUI)
    import SwiftUI

    extension Color {
        /// Creates a SwiftUI Color from a hex string.
        ///
        /// Supports the same formats as `UIColor(hex:)`:
        /// - `#RGB` (12-bit)
        /// - `#RRGGBB` (24-bit)
        /// - `#RRGGBBAA` (32-bit with alpha)
        ///
        /// ## Example
        ///
        /// ```swift
        /// let blue = Color(hex: "#007AFF")
        /// let red = Color(hex: "FF0000")
        /// ```
        ///
        /// - Parameter hex: The hex color string.
        public init?(hex: String) {
            guard let uiColor = UIColor(hex: hex) else {
                return nil
            }
            self.init(uiColor)
        }
    }
#endif
