import Foundation

/// Loads PWAConfiguration from bundle or remote sources and provides WebViewConfiguration.
///
/// This loader extends the base configuration loading with remote loading capability
/// and provides factory methods for creating WebViewConfiguration from the loaded config.
///
/// ## Loading Sources
///
/// The loader supports multiple sources in priority order:
/// 1. Remote URL (if configured)
/// 2. Bundle resource (`pwa-config.json`)
/// 3. Default configuration fallback
///
/// ## Example
///
/// ```swift
/// // Load from default sources
/// let loader = SettingsConfigurationLoader.shared
/// let config = try await loader.loadConfiguration()
///
/// // Create WebViewConfiguration
/// let webViewConfig = try await loader.webViewConfiguration()
///
/// // Load from a remote URL
/// let remoteConfig = try await loader.loadFromRemote(URL(string: "https://example.com/config.json")!)
/// ```
public actor SettingsConfigurationLoader {
    /// The shared configuration loader instance.
    public static let shared = SettingsConfigurationLoader()

    /// The name of the configuration file in the bundle.
    public static let configFileName = "pwa-config.json"

    /// Cached configuration to avoid repeated loading.
    private var cachedConfiguration: PWAConfiguration?

    /// The bundle to load resources from.
    private let bundle: Bundle

    /// The file manager for file operations.
    private let fileManager: FileManager

    /// URL session for remote loading.
    private let session: URLSession

    /// Creates a new settings configuration loader.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to load resources from. Defaults to `.main`.
    ///   - fileManager: The file manager to use. Defaults to `.default`.
    ///   - session: The URL session for remote requests. Defaults to `.shared`.
    public init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.session = session
    }

    // MARK: - Configuration Loading

    /// Loads the configuration with the default priority ordering.
    ///
    /// Loading sources (priority order):
    /// 1. Documents directory (for runtime updates)
    /// 2. Bundle resource (shipped with app)
    /// 3. Default configuration fallback
    ///
    /// - Parameter ignoreCache: If `true`, bypasses the cache and reloads.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if loading or validation fails.
    public func loadConfiguration(ignoreCache: Bool = false) async throws -> PWAConfiguration {
        if !ignoreCache, let cached = cachedConfiguration {
            return cached
        }

        // Try loading from documents first
        if let documentsConfig = try? await loadFromDocuments() {
            cachedConfiguration = documentsConfig
            return documentsConfig
        }

        // Try loading from bundle
        if let bundleConfig = try? await loadFromBundle() {
            cachedConfiguration = bundleConfig
            return bundleConfig
        }

        // Fall back to default
        let defaultConfig = Self.defaultConfiguration
        cachedConfiguration = defaultConfig
        return defaultConfig
    }

    /// Loads configuration from a remote URL.
    ///
    /// This method fetches configuration from a remote server and validates it.
    /// The remote configuration takes precedence over bundle configuration.
    ///
    /// - Parameters:
    ///   - url: The URL to fetch configuration from.
    ///   - timeout: Request timeout in seconds. Defaults to 30.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if loading, parsing, or validation fails.
    public func loadFromRemote(_ url: URL, timeout: TimeInterval = 30) async throws -> PWAConfiguration {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ConfigurationError.unableToRead(
                source: url.absoluteString,
                reason: error.localizedDescription
            )
        }

        // Validate HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw ConfigurationError.unableToRead(
                    source: url.absoluteString,
                    reason: "HTTP error: \(httpResponse.statusCode)"
                )
            }
        }

        return try parseAndValidate(data)
    }

    /// Loads configuration from the app's Documents directory.
    ///
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if file not found or validation fails.
    public func loadFromDocuments() async throws -> PWAConfiguration {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ConfigurationError.fileNotFound(source: "Documents directory")
        }

        let configURL = documentsPath.appendingPathComponent(Self.configFileName)

        guard fileManager.fileExists(atPath: configURL.path) else {
            throw ConfigurationError.fileNotFound(source: configURL.path)
        }

        return try await loadAndValidate(from: configURL)
    }

    /// Loads configuration from the app bundle.
    ///
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if file not found or validation fails.
    public func loadFromBundle() async throws -> PWAConfiguration {
        guard let configURL = bundle.url(forResource: "pwa-config", withExtension: "json") else {
            throw ConfigurationError.fileNotFound(source: "Bundle resource 'pwa-config.json'")
        }

        return try await loadAndValidate(from: configURL)
    }

    /// Loads configuration from raw JSON data.
    ///
    /// - Parameter data: The JSON data to parse.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if parsing or validation fails.
    public func loadFromData(_ data: Data) async throws -> PWAConfiguration {
        try parseAndValidate(data)
    }

    /// Clears the cached configuration.
    public func clearCache() {
        cachedConfiguration = nil
    }

    // MARK: - WebViewConfiguration Factory

    /// Creates a WebViewConfiguration from the loaded configuration.
    ///
    /// This is the primary method for obtaining a fully configured WebViewConfiguration
    /// that can be used to initialize the WebView.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: A WebViewConfiguration derived from the loaded configuration.
    /// - Throws: `ConfigurationError` if loading fails, or `WebViewConfigurationError` if URL is invalid.
    public func webViewConfiguration(ignoreCache: Bool = false) async throws -> WebViewConfiguration {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return try WebViewConfiguration.from(pwaConfig: config)
    }

    /// Creates a WebViewConfiguration from a specific configuration.
    ///
    /// - Parameter configuration: The PWA configuration to convert.
    /// - Returns: A WebViewConfiguration derived from the configuration.
    /// - Throws: `WebViewConfigurationError` if the start URL is invalid.
    public nonisolated func webViewConfiguration(from configuration: PWAConfiguration) throws -> WebViewConfiguration {
        try WebViewConfiguration.from(pwaConfig: configuration)
    }

    // MARK: - Origin Parsing

    /// Parses allowed origins from the configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: Array of allowed origin patterns.
    public func allowedOrigins(ignoreCache: Bool = false) async throws -> [String] {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.origins.allowed
    }

    /// Parses auth origins from the configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: Array of auth origin patterns.
    public func authOrigins(ignoreCache: Bool = false) async throws -> [String] {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.origins.auth
    }

    /// Parses external origins from the configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: Array of external origin patterns.
    public func externalOrigins(ignoreCache: Bool = false) async throws -> [String] {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.origins.external
    }

    // MARK: - Feature Access

    /// Returns the features configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: The features configuration.
    public func features(ignoreCache: Bool = false) async throws -> FeaturesConfiguration {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.features
    }

    /// Returns the appearance configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: The appearance configuration.
    public func appearance(ignoreCache: Bool = false) async throws -> AppearanceConfiguration {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.appearance
    }

    /// Returns the display mode from the configuration.
    ///
    /// - Parameter ignoreCache: If `true`, reloads configuration from disk.
    /// - Returns: The display mode.
    public func displayMode(ignoreCache: Bool = false) async throws -> DisplayMode {
        let config = try await loadConfiguration(ignoreCache: ignoreCache)
        return config.appearance.displayMode
    }

    // MARK: - Default Configuration

    /// The default configuration used as a fallback.
    public static let defaultConfiguration = PWAConfiguration(
        version: 1,
        app: AppConfiguration(
            name: "PWA App",
            bundleId: "com.example.pwa",
            startUrl: "https://example.com/"
        ),
        origins: OriginsConfiguration(
            allowed: ["example.com"],
            auth: [],
            external: []
        ),
        features: .default,
        appearance: .default,
        notifications: .default
    )

    // MARK: - Private Helpers

    /// Loads and validates configuration from a URL.
    private func loadAndValidate(from url: URL) async throws -> PWAConfiguration {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigurationError.unableToRead(
                source: url.path,
                reason: error.localizedDescription
            )
        }

        return try parseAndValidate(data)
    }

    /// Parses JSON data and validates the configuration.
    private func parseAndValidate(_ data: Data) throws -> PWAConfiguration {
        let decoder = JSONDecoder()
        let configuration: PWAConfiguration

        do {
            configuration = try decoder.decode(PWAConfiguration.self, from: data)
        } catch let decodingError as DecodingError {
            throw ConfigurationError.invalidJSON(reason: decodingError.localizedDescription)
        } catch {
            throw ConfigurationError.invalidJSON(reason: error.localizedDescription)
        }

        do {
            try ConfigurationValidator.validate(configuration)
        } catch let validationError as ConfigurationValidationError {
            throw ConfigurationError.validation(validationError)
        } catch {
            throw ConfigurationError.unexpected(reason: error.localizedDescription)
        }

        return configuration
    }
}
