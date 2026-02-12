import Foundation
import UIKit

// MARK: - UserAgentBuilder

/// Builds custom user agent strings for the WKWebView.
///
/// The user agent identifies the app to web servers, allowing web content
/// to detect that it's running within the PWAKit shell and adapt accordingly.
///
/// ## User Agent Format
///
/// The generated user agent follows this pattern:
/// ```
/// Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) PWAKit/1.0.0
/// Model/iPhone15,2
/// ```
///
/// Components:
/// - Base Safari user agent prefix for compatibility
/// - `PWAKit/{version}` - Identifies the PWAKit shell and app version
/// - `Model/{identifier}` - Device hardware model identifier
///
/// ## Example
///
/// ```swift
/// let userAgent = UserAgentBuilder.buildUserAgent()
/// webView.customUserAgent = userAgent
/// ```
public enum UserAgentBuilder {
    /// The identifier used to mark the user agent as a PWAKit shell.
    public static let shellIdentifier = "PWAKit"

    /// Builds a custom user agent string.
    ///
    /// - Parameters:
    ///   - appVersion: Optional app version override. If nil, uses Bundle version.
    ///   - additionalComponents: Additional components to append to the user agent.
    /// - Returns: A complete user agent string.
    public static func buildUserAgent(
        appVersion: String? = nil,
        additionalComponents: [String] = []
    ) -> String {
        var components: [String] = []

        // Base Safari user agent
        components.append(baseSafariUserAgent())

        // PWAKit identifier with version
        let version = appVersion ?? bundleVersion()
        components.append("\(shellIdentifier)/\(version)")

        // Device model
        components.append("Model/\(deviceModel())")

        // Additional components
        components.append(contentsOf: additionalComponents)

        return components.joined(separator: " ")
    }

    /// Builds the base Safari user agent string.
    ///
    /// This creates a Safari-compatible user agent base that ensures
    /// web content renders correctly.
    ///
    /// - Returns: The base Safari user agent string.
    public static func baseSafariUserAgent() -> String {
        let device = UIDevice.current
        let osVersion = device.systemVersion.replacingOccurrences(of: ".", with: "_")

        // Determine device type for user agent
        let deviceType: String
        let cpuType: String

        switch device.userInterfaceIdiom {
        case .pad:
            deviceType = "iPad"
            cpuType = "CPU OS"
        case .phone:
            deviceType = "iPhone"
            cpuType = "CPU iPhone OS"
        case .mac:
            deviceType = "Macintosh"
            cpuType = "Intel Mac OS X"
        default:
            deviceType = "iPhone"
            cpuType = "CPU iPhone OS"
        }

        // Standard Safari/WebKit user agent format
        // Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)
        let platform = "\(deviceType); \(cpuType) \(osVersion) like Mac OS X"
        return "Mozilla/5.0 (\(platform)) AppleWebKit/605.1.15 (KHTML, like Gecko)"
    }

    /// Returns the device hardware model identifier.
    ///
    /// For example: "iPhone15,2" for iPhone 14 Pro.
    ///
    /// - Returns: The device model identifier string.
    public static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }

    /// Returns the OS version string.
    ///
    /// - Returns: The system version (e.g., "17.0").
    public static func osVersion() -> String {
        UIDevice.current.systemVersion
    }

    /// Returns the OS name.
    ///
    /// - Returns: The system name (e.g., "iOS").
    public static func osName() -> String {
        UIDevice.current.systemName
    }

    /// Returns the app version from the main bundle.
    ///
    /// Falls back to "1.0.0" if not found.
    ///
    /// - Returns: The bundle short version string.
    public static func bundleVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// Returns the build number from the main bundle.
    ///
    /// Falls back to "1" if not found.
    ///
    /// - Returns: The bundle version (build number).
    public static func buildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - User Agent Parsing

extension UserAgentBuilder {
    /// Checks if a user agent string indicates a PWAKit shell.
    ///
    /// - Parameter userAgent: The user agent string to check.
    /// - Returns: `true` if the user agent contains the PWAKit identifier.
    public static func isPWAKit(_ userAgent: String) -> Bool {
        userAgent.contains(shellIdentifier)
    }

    /// Extracts the PWAKit version from a user agent string.
    ///
    /// - Parameter userAgent: The user agent string to parse.
    /// - Returns: The version string if found, otherwise `nil`.
    public static func extractShellVersion(from userAgent: String) -> String? {
        // Pattern: PWAKit/1.0.0
        let pattern = "\(shellIdentifier)/([\\d.]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: userAgent,
                  options: [],
                  range: NSRange(userAgent.startIndex..., in: userAgent)
              ),
              let versionRange = Range(match.range(at: 1), in: userAgent) else
        {
            return nil
        }
        return String(userAgent[versionRange])
    }

    /// Extracts the device model from a user agent string.
    ///
    /// - Parameter userAgent: The user agent string to parse.
    /// - Returns: The model identifier if found, otherwise `nil`.
    public static func extractDeviceModel(from userAgent: String) -> String? {
        // Pattern: Model/iPhone15,2
        let pattern = "Model/([\\w,]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: userAgent,
                  options: [],
                  range: NSRange(userAgent.startIndex..., in: userAgent)
              ),
              let modelRange = Range(match.range(at: 1), in: userAgent) else
        {
            return nil
        }
        return String(userAgent[modelRange])
    }
}
