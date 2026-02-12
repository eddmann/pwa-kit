import Foundation

/// Loads PWAConfiguration from various sources with priority ordering.
///
/// `ConfigurationLoader` handles loading configuration with the following priority:
/// 1. Documents directory (`pwa-config.json`) - for runtime updates
/// 2. Bundle resource (`pwa-config.json`) - shipped with app
/// 3. Default configuration fallback
///
/// The loader validates configurations on load and caches the result for performance.
///
/// ## Example
///
/// ```swift
/// // Load configuration (uses default priority ordering)
/// let config = try await ConfigurationLoader.shared.load()
///
/// // Force reload, bypassing cache
/// let freshConfig = try await ConfigurationLoader.shared.load(ignoreCache: true)
///
/// // Load from a specific bundle (useful for testing)
/// let testConfig = try await ConfigurationLoader.shared.load(from: testBundle)
/// ```
public actor ConfigurationLoader {
    /// The shared configuration loader instance.
    public static let shared = ConfigurationLoader()

    /// The name of the configuration file.
    public static let configFileName = "pwa-config.json"

    /// Cached configuration to avoid repeated disk access.
    private var cachedConfiguration: PWAConfiguration?

    /// The bundle to load resources from. Defaults to the main bundle.
    private let bundle: Bundle

    /// The file manager to use for file operations.
    private let fileManager: FileManager

    /// Creates a new configuration loader.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to load resources from. Defaults to `.main`.
    ///   - fileManager: The file manager to use. Defaults to `.default`.
    public init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    // MARK: - Public Loading Methods

    /// Loads the configuration with the default priority ordering.
    ///
    /// Loading sources (priority order):
    /// 1. Documents directory (for runtime updates)
    /// 2. Bundle resource (shipped with app)
    /// 3. Default configuration fallback
    ///
    /// - Parameter ignoreCache: If `true`, bypasses the cache and reloads from disk.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if loading or validation fails.
    public func load(ignoreCache: Bool = false) async throws -> PWAConfiguration {
        // Return cached configuration if available
        if !ignoreCache, let cached = cachedConfiguration {
            return cached
        }

        // Try loading from documents directory first (runtime updates)
        if let documentsConfig = try? await loadFromDocuments() {
            cachedConfiguration = documentsConfig
            return documentsConfig
        }

        // Try loading from bundle
        if let bundleConfig = try? await loadFromBundle() {
            cachedConfiguration = bundleConfig
            return bundleConfig
        }

        // Fall back to default configuration
        let defaultConfig = Self.defaultConfiguration
        cachedConfiguration = defaultConfig
        return defaultConfig
    }

    /// Loads configuration from a specific bundle.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to load from.
    ///   - ignoreCache: If `true`, bypasses the cache.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if the file is not found or validation fails.
    public func load(from bundle: Bundle, ignoreCache: Bool = false) async throws -> PWAConfiguration {
        if !ignoreCache, let cached = cachedConfiguration {
            return cached
        }

        let config = try await loadFromBundle(bundle)
        cachedConfiguration = config
        return config
    }

    /// Clears the cached configuration.
    ///
    /// Call this method when you need to force a reload from disk.
    public func clearCache() {
        cachedConfiguration = nil
    }

    // MARK: - Loading from Specific Sources

    /// Loads configuration from the app's Documents directory.
    ///
    /// This is used for runtime configuration updates.
    ///
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if the file is not found or validation fails.
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
    /// - Throws: `ConfigurationError` if the file is not found or validation fails.
    public func loadFromBundle() async throws -> PWAConfiguration {
        try await loadFromBundle(bundle)
    }

    /// Loads configuration from a specific bundle.
    ///
    /// - Parameter bundle: The bundle to load from.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if the file is not found or validation fails.
    public func loadFromBundle(_ bundle: Bundle) async throws -> PWAConfiguration {
        guard let configURL = bundle.url(forResource: "pwa-config", withExtension: "json") else {
            throw ConfigurationError.fileNotFound(source: "Bundle resource 'pwa-config.json'")
        }

        return try await loadAndValidate(from: configURL)
    }

    /// Loads configuration from a specific URL.
    ///
    /// - Parameter url: The URL to load from.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if loading or validation fails.
    public func loadFromURL(_ url: URL) async throws -> PWAConfiguration {
        try await loadAndValidate(from: url)
    }

    /// Loads configuration from raw JSON data.
    ///
    /// - Parameter data: The JSON data to parse.
    /// - Returns: The loaded and validated configuration.
    /// - Throws: `ConfigurationError` if parsing or validation fails.
    public func loadFromData(_ data: Data) async throws -> PWAConfiguration {
        try parseAndValidate(data)
    }

    // MARK: - Default Configuration

    /// The default configuration used as a fallback.
    ///
    /// This provides reasonable defaults when no configuration file is found.
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
