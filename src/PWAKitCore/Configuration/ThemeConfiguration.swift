import Foundation

// MARK: - ThemeConfiguration

/// Resolved theme colors with fallback support.
///
/// `ThemeConfiguration` provides a unified interface for theme colors,
/// resolving values from multiple sources in priority order:
/// 1. PWA configuration (`pwa-config.json`)
/// 2. Web manifest (`manifest.json`)
/// 3. System defaults (nil)
///
/// ## Example
///
/// ```swift
/// // Create theme from pwa-config and manifest
/// let theme = ThemeConfiguration(
///     pwaConfig: configuration.appearance,
///     manifest: webManifest
/// )
///
/// // Use resolved colors
/// if let bgColor = theme.backgroundColor {
///     view.backgroundColor = UIColor(hex: bgColor)
/// }
/// ```
public struct ThemeConfiguration: Sendable, Equatable {
    /// The resolved background color in hex format.
    ///
    /// Priority:
    /// 1. `appearance.backgroundColor` from pwa-config
    /// 2. `background_color` from web manifest
    /// 3. `nil` (use system default)
    public let backgroundColor: String?

    /// The resolved theme/accent color in hex format.
    ///
    /// Priority:
    /// 1. `appearance.themeColor` from pwa-config
    /// 2. `theme_color` from web manifest
    /// 3. `nil` (use system default)
    public let themeColor: String?

    /// The app name for display purposes.
    ///
    /// Priority:
    /// 1. `app.name` from pwa-config
    /// 2. `name` from web manifest
    /// 3. `nil`
    public let appName: String?

    /// The short app name for limited space contexts.
    ///
    /// Priority:
    /// 1. `short_name` from web manifest
    /// 2. Derived from `appName` (truncated)
    /// 3. `nil`
    public let shortName: String?

    // MARK: - Initialization

    /// Creates a new theme configuration with explicit values.
    ///
    /// - Parameters:
    ///   - backgroundColor: The background color in hex format.
    ///   - themeColor: The theme/accent color in hex format.
    ///   - appName: The app name.
    ///   - shortName: The short app name.
    public init(
        backgroundColor: String? = nil,
        themeColor: String? = nil,
        appName: String? = nil,
        shortName: String? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.themeColor = themeColor
        self.appName = appName
        self.shortName = shortName
    }

    /// Creates a theme configuration by merging pwa-config and manifest values.
    ///
    /// Values from `pwaConfig` take priority over `manifest` values.
    ///
    /// - Parameters:
    ///   - pwaConfig: The PWA configuration to use as primary source.
    ///   - manifest: The web manifest to use as fallback source.
    public init(pwaConfig: PWAConfiguration, manifest: WebManifest? = nil) {
        // Background color: pwa-config > manifest > nil
        self.backgroundColor = pwaConfig.appearance.backgroundColor
            ?? manifest?.backgroundColor

        // Theme color: pwa-config > manifest > nil
        self.themeColor = pwaConfig.appearance.themeColor
            ?? manifest?.themeColor

        // App name: pwa-config > manifest > nil
        self.appName = pwaConfig.app.name.isEmpty ? nil : pwaConfig.app.name
            ?? manifest?.name

        // Short name: manifest only (pwa-config doesn't have this)
        self.shortName = manifest?.shortName
    }

    /// Creates a theme configuration from appearance settings only.
    ///
    /// - Parameter appearance: The appearance configuration.
    public init(appearance: AppearanceConfiguration) {
        self.backgroundColor = appearance.backgroundColor
        self.themeColor = appearance.themeColor
        self.appName = nil
        self.shortName = nil
    }

    /// Creates a theme configuration from a web manifest only.
    ///
    /// - Parameter manifest: The web manifest.
    public init(manifest: WebManifest) {
        self.backgroundColor = manifest.backgroundColor
        self.themeColor = manifest.themeColor
        self.appName = manifest.name
        self.shortName = manifest.shortName
    }

    // MARK: - Defaults

    /// Default theme configuration with no colors specified.
    public static let `default` = ThemeConfiguration()

    // MARK: - Computed Properties

    /// Whether any colors are specified.
    public var hasColors: Bool {
        backgroundColor != nil || themeColor != nil
    }

    /// Whether all colors are specified.
    public var hasAllColors: Bool {
        backgroundColor != nil && themeColor != nil
    }
}

// MARK: - ThemeResolver

/// Resolves theme configuration from multiple sources.
///
/// `ThemeResolver` coordinates loading theme information from both
/// pwa-config and web manifest, handling the async manifest fetch
/// and providing the resolved theme.
public actor ThemeResolver {
    /// The shared resolver instance.
    public static let shared = ThemeResolver()

    /// Cached resolved themes keyed by start URL.
    private var cache: [String: ThemeConfiguration] = [:]

    // MARK: - Public Methods

    /// Resolves theme configuration for a PWA configuration.
    ///
    /// This method:
    /// 1. Extracts colors from pwa-config
    /// 2. If colors are missing, attempts to fetch the web manifest
    /// 3. Returns merged theme with pwa-config taking priority
    ///
    /// - Parameters:
    ///   - config: The PWA configuration.
    ///   - fetchManifest: Whether to fetch the manifest if colors are missing. Defaults to `true`.
    /// - Returns: The resolved theme configuration.
    public func resolve(
        for config: PWAConfiguration,
        fetchManifest: Bool = true
    ) async -> ThemeConfiguration {
        let cacheKey = config.app.startUrl

        // Check cache
        if let cached = cache[cacheKey] {
            return cached
        }

        // If pwa-config has all colors, no need to fetch manifest
        let appearance = config.appearance
        if appearance.backgroundColor != nil, appearance.themeColor != nil {
            let theme = ThemeConfiguration(pwaConfig: config)
            cache[cacheKey] = theme
            return theme
        }

        // Try to fetch manifest for missing colors
        var manifest: WebManifest?
        if fetchManifest, let startURL = URL(string: config.app.startUrl) {
            manifest = await ManifestLoader.shared.loadFromOrigin(startURL)
        }

        let theme = ThemeConfiguration(pwaConfig: config, manifest: manifest)
        cache[cacheKey] = theme
        return theme
    }

    /// Clears the theme cache.
    public func clearCache() {
        cache.removeAll()
    }

    /// Clears the cached theme for a specific start URL.
    ///
    /// - Parameter startURL: The start URL to clear from cache.
    public func clearCache(for startURL: String) {
        cache.removeValue(forKey: startURL)
    }
}
