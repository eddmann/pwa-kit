import Foundation

// MARK: - WebManifest

/// Partial web app manifest structure for theme extraction.
///
/// This struct represents a subset of the W3C Web App Manifest specification,
/// focusing on properties relevant to native app theming.
///
/// ## Supported Properties
///
/// - `name`: The full name of the application
/// - `shortName`: A shorter name for limited space contexts
/// - `backgroundColor`: The expected background color of the web application
/// - `themeColor`: The default theme color for the application
/// - `icons`: Array of icon objects for various sizes/purposes
///
/// ## Example Manifest
///
/// ```json
/// {
///   "name": "My PWA App",
///   "short_name": "MyApp",
///   "background_color": "#ffffff",
///   "theme_color": "#007AFF",
///   "icons": [
///     { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" }
///   ]
/// }
/// ```
///
/// ## Reference
///
/// See [W3C Web App Manifest](https://www.w3.org/TR/appmanifest/) for the full specification.
public struct WebManifest: Codable, Sendable, Equatable {
    /// The full name of the web application.
    public let name: String?

    /// A short name for the application, used where space is limited.
    public let shortName: String?

    /// The expected background color of the web application.
    ///
    /// This should be a valid CSS color value (typically hex format like `#ffffff`).
    /// Used for splash screens and loading states before the app's CSS loads.
    public let backgroundColor: String?

    /// The default theme color for the application.
    ///
    /// This should be a valid CSS color value (typically hex format like `#007AFF`).
    /// Used for UI elements like the status bar, toolbar tinting, etc.
    public let themeColor: String?

    /// Array of icon objects specifying images for various contexts.
    public let icons: [ManifestIcon]?

    /// The start URL of the web application.
    public let startUrl: String?

    /// The display mode for the application.
    public let display: String?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case name
        case shortName = "short_name"
        case backgroundColor = "background_color"
        case themeColor = "theme_color"
        case icons
        case startUrl = "start_url"
        case display
    }

    // MARK: - Initialization

    /// Creates a new WebManifest instance.
    ///
    /// - Parameters:
    ///   - name: The full name of the application.
    ///   - shortName: A short name for limited space.
    ///   - backgroundColor: Background color in CSS format.
    ///   - themeColor: Theme color in CSS format.
    ///   - icons: Array of icon definitions.
    ///   - startUrl: The start URL.
    ///   - display: The display mode.
    public init(
        name: String? = nil,
        shortName: String? = nil,
        backgroundColor: String? = nil,
        themeColor: String? = nil,
        icons: [ManifestIcon]? = nil,
        startUrl: String? = nil,
        display: String? = nil
    ) {
        self.name = name
        self.shortName = shortName
        self.backgroundColor = backgroundColor
        self.themeColor = themeColor
        self.icons = icons
        self.startUrl = startUrl
        self.display = display
    }
}

// MARK: - ManifestIcon

/// An icon definition from a web app manifest.
///
/// Icons in the manifest specify images that can serve as application icons
/// in various contexts (home screen, app switcher, splash screen, etc.).
public struct ManifestIcon: Codable, Sendable, Equatable {
    /// The path to the icon file (relative or absolute URL).
    public let src: String

    /// Space-separated list of icon dimensions (e.g., "192x192" or "192x192 256x256").
    public let sizes: String?

    /// The MIME type of the icon (e.g., "image/png", "image/svg+xml").
    public let type: String?

    /// The purpose of the icon (e.g., "any", "maskable", "monochrome").
    public let purpose: String?

    // MARK: - Initialization

    /// Creates a new ManifestIcon instance.
    ///
    /// - Parameters:
    ///   - src: The path to the icon file.
    ///   - sizes: Space-separated icon dimensions.
    ///   - type: The MIME type.
    ///   - purpose: The icon purpose.
    public init(
        src: String,
        sizes: String? = nil,
        type: String? = nil,
        purpose: String? = nil
    ) {
        self.src = src
        self.sizes = sizes
        self.type = type
        self.purpose = purpose
    }
}
