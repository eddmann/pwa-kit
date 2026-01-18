import Foundation

// MARK: - ManifestLoader

/// Loads and parses web app manifests from remote URLs.
///
/// `ManifestLoader` fetches web manifest JSON files from web servers and parses them
/// into `WebManifest` structures for theme extraction. It supports automatic discovery
/// of manifests from the origin's `/manifest.json` or `/site.webmanifest` paths.
///
/// ## Example
///
/// ```swift
/// // Load manifest from a specific URL
/// let manifest = try await ManifestLoader.shared.load(
///     from: URL(string: "https://example.com/manifest.json")!
/// )
///
/// // Auto-discover manifest from origin
/// let manifest = await ManifestLoader.shared.loadFromOrigin(
///     URL(string: "https://example.com/app")!
/// )
/// ```
///
/// ## Discovery Paths
///
/// When using `loadFromOrigin`, the loader tries these paths in order:
/// 1. `/manifest.json`
/// 2. `/site.webmanifest`
/// 3. `/manifest.webmanifest`
public actor ManifestLoader {
    /// The shared manifest loader instance.
    public static let shared = ManifestLoader()

    /// Common manifest file paths to try during discovery.
    private static let manifestPaths = [
        "/manifest.json",
        "/site.webmanifest",
        "/manifest.webmanifest",
    ]

    /// Default timeout for network requests in seconds.
    private let defaultTimeout: TimeInterval = 10

    /// The URL session to use for network requests.
    private let urlSession: URLSession

    /// Cached manifests keyed by origin URL string.
    private var cache: [String: WebManifest] = [:]

    // MARK: - Initialization

    /// Creates a new manifest loader.
    ///
    /// - Parameter urlSession: The URL session to use. Defaults to `.shared`.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public Loading Methods

    /// Loads a web manifest from a specific URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the manifest file.
    ///   - timeout: Request timeout in seconds. Defaults to 10 seconds.
    /// - Returns: The parsed web manifest.
    /// - Throws: `ManifestLoaderError` if loading or parsing fails.
    public func load(from url: URL, timeout: TimeInterval? = nil) async throws -> WebManifest {
        let effectiveTimeout = timeout ?? defaultTimeout

        var request = URLRequest(url: url)
        request.timeoutInterval = effectiveTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManifestLoaderError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ManifestLoaderError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let manifest = try JSONDecoder().decode(WebManifest.self, from: data)
            return manifest
        } catch {
            throw ManifestLoaderError.invalidJSON(reason: error.localizedDescription)
        }
    }

    /// Attempts to discover and load a manifest from an origin URL.
    ///
    /// This method extracts the origin (scheme + host) from the provided URL
    /// and tries common manifest paths until one succeeds.
    ///
    /// - Parameters:
    ///   - startURL: Any URL on the target origin.
    ///   - timeout: Request timeout in seconds for each attempt. Defaults to 10 seconds.
    /// - Returns: The parsed manifest, or `nil` if no manifest could be found.
    public func loadFromOrigin(_ startURL: URL, timeout: TimeInterval? = nil) async -> WebManifest? {
        guard let origin = originURL(from: startURL) else {
            return nil
        }

        let originKey = origin.absoluteString

        // Check cache first
        if let cached = cache[originKey] {
            return cached
        }

        // Try each manifest path
        for path in Self.manifestPaths {
            guard let manifestURL = URL(string: path, relativeTo: origin) else {
                continue
            }

            do {
                let manifest = try await load(from: manifestURL, timeout: timeout)
                cache[originKey] = manifest
                return manifest
            } catch {
                // Continue to next path
                continue
            }
        }

        return nil
    }

    /// Clears the manifest cache.
    ///
    /// Call this when you need to refresh manifests from the network.
    public func clearCache() {
        cache.removeAll()
    }

    /// Clears the cached manifest for a specific origin.
    ///
    /// - Parameter origin: The origin URL to clear from cache.
    public func clearCache(for origin: URL) {
        if let originURL = originURL(from: origin) {
            cache.removeValue(forKey: originURL.absoluteString)
        }
    }

    // MARK: - Private Helpers

    /// Extracts the origin (scheme + host + port) from a URL.
    private func originURL(from url: URL) -> URL? {
        guard let scheme = url.scheme, let host = url.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port

        return components.url
    }
}

// MARK: - ManifestLoaderError

/// Errors that can occur when loading a web manifest.
public enum ManifestLoaderError: Error, LocalizedError {
    /// The network response was not a valid HTTP response.
    case invalidResponse

    /// The server returned an HTTP error status code.
    case httpError(statusCode: Int)

    /// The manifest data could not be parsed as valid JSON.
    case invalidJSON(reason: String)

    /// Network request failed.
    case networkError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(statusCode):
            "HTTP error: \(statusCode)"
        case let .invalidJSON(reason):
            "Invalid manifest JSON: \(reason)"
        case let .networkError(reason):
            "Network error: \(reason)"
        }
    }
}
