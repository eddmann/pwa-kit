import Foundation

/// Configuration for core application metadata.
///
/// Contains the essential app information needed for PWAKit to function:
/// - Display name
/// - Bundle identifier
/// - Start URL for the WebView
public struct AppConfiguration: Codable, Sendable, Equatable {
    /// Display name of the application.
    public let name: String

    /// iOS bundle identifier (e.g., `com.example.app`).
    public let bundleId: String

    /// The initial URL to load in the WebView. Must be HTTPS.
    public let startUrl: String

    /// Creates a new app configuration.
    ///
    /// - Parameters:
    ///   - name: Display name of the application.
    ///   - bundleId: iOS bundle identifier.
    ///   - startUrl: Initial URL to load (must be HTTPS).
    public init(name: String, bundleId: String, startUrl: String) {
        self.name = name
        self.bundleId = bundleId
        self.startUrl = startUrl
    }
}
