import Foundation

// MARK: - ConfigurationValidationError

/// Errors that can occur during configuration validation.
public enum ConfigurationValidationError: Error, Equatable, Sendable {
    /// The start URL is not a valid URL.
    case invalidStartUrl(String)

    /// The start URL is not using HTTPS.
    case startUrlNotHttps(String)

    /// An origin pattern is invalid.
    case invalidOriginPattern(String)

    /// The allowed origins list is empty.
    case emptyAllowedOrigins

    /// A conflicting configuration was detected.
    case conflictingConfiguration(String)
}

// MARK: LocalizedError

extension ConfigurationValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidStartUrl(url):
            "Invalid start URL: '\(url)' is not a valid URL."
        case let .startUrlNotHttps(url):
            "Start URL must use HTTPS: '\(url)'"
        case let .invalidOriginPattern(pattern):
            "Invalid origin pattern: '\(pattern)'"
        case .emptyAllowedOrigins:
            "At least one allowed origin is required."
        case let .conflictingConfiguration(message):
            "Conflicting configuration: \(message)"
        }
    }
}

// MARK: - ConfigurationValidator

/// Validates PWAConfiguration for correctness.
///
/// Use `ConfigurationValidator` to check that a configuration is valid
/// before using it to configure the app. Validation includes:
/// - Start URL is a valid HTTPS URL
/// - Origin patterns are valid domain patterns
/// - At least one allowed origin is specified
/// - No conflicting settings exist
///
/// ## Example
///
/// ```swift
/// let config = try JSONDecoder().decode(PWAConfiguration.self, from: data)
/// try ConfigurationValidator.validate(config)
/// ```
public enum ConfigurationValidator {
    /// Validates a PWAConfiguration.
    ///
    /// - Parameter configuration: The configuration to validate.
    /// - Throws: `ConfigurationValidationError` if validation fails.
    public static func validate(_ configuration: PWAConfiguration) throws {
        try validateStartUrl(configuration.app.startUrl)
        try validateOrigins(configuration.origins)
        try validateNoConflicts(configuration)
    }

    /// Validates that the start URL is a valid HTTPS URL.
    ///
    /// - Parameter urlString: The URL string to validate.
    /// - Throws: `ConfigurationValidationError.invalidStartUrl` or
    ///           `ConfigurationValidationError.startUrlNotHttps`
    public static func validateStartUrl(_ urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw ConfigurationValidationError.invalidStartUrl(urlString)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw ConfigurationValidationError.startUrlNotHttps(urlString)
        }

        // Ensure the URL has a host
        guard let host = url.host, !host.isEmpty else {
            throw ConfigurationValidationError.invalidStartUrl(urlString)
        }
    }

    /// Validates origin configurations.
    ///
    /// - Parameter origins: The origins configuration to validate.
    /// - Throws: `ConfigurationValidationError.emptyAllowedOrigins` or
    ///           `ConfigurationValidationError.invalidOriginPattern`
    public static func validateOrigins(_ origins: OriginsConfiguration) throws {
        // At least one allowed origin is required
        guard !origins.allowed.isEmpty else {
            throw ConfigurationValidationError.emptyAllowedOrigins
        }

        // Validate all origin patterns
        for pattern in origins.allowed {
            try validateOriginPattern(pattern)
        }

        for pattern in origins.auth {
            try validateOriginPattern(pattern)
        }

        for pattern in origins.external {
            try validateOriginPattern(pattern)
        }
    }

    /// Validates a single origin pattern.
    ///
    /// Valid patterns include:
    /// - `example.com` - Exact domain
    /// - `*.example.com` - Wildcard subdomain
    /// - `example.com/path/*` - Path prefix
    ///
    /// - Parameter pattern: The origin pattern to validate.
    /// - Throws: `ConfigurationValidationError.invalidOriginPattern`
    public static func validateOriginPattern(_ pattern: String) throws {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)

        // Empty or whitespace-only patterns are invalid
        guard !trimmed.isEmpty else {
            throw ConfigurationValidationError.invalidOriginPattern(pattern)
        }

        // Pattern should not contain schemes
        let lowerPattern = trimmed.lowercased()
        if lowerPattern.hasPrefix("http://") || lowerPattern.hasPrefix("https://") {
            throw ConfigurationValidationError.invalidOriginPattern(pattern)
        }

        // Extract domain part (before any path)
        let components = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let domainPart = String(components[0])

        // Validate domain part
        try validateDomainPattern(domainPart, originalPattern: pattern)

        // Validate path part if present
        if components.count > 1 {
            let pathPart = String(components[1])
            try validatePathPattern(pathPart, originalPattern: pattern)
        }
    }

    /// Validates the domain portion of an origin pattern.
    private static func validateDomainPattern(_ domain: String, originalPattern: String) throws {
        // Handle wildcard domains
        var domainToCheck = domain
        if domain.hasPrefix("*.") {
            domainToCheck = String(domain.dropFirst(2))
            // The part after *. must be a valid domain
            guard !domainToCheck.isEmpty else {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }
        }

        // Check for invalid wildcard placement (e.g., "exam*ple.com")
        if domainToCheck.contains("*") {
            throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
        }

        // Check for consecutive dots (empty parts)
        if domainToCheck.contains("..") {
            throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
        }

        // Check for leading or trailing dots
        if domainToCheck.hasPrefix(".") || domainToCheck.hasSuffix(".") {
            throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
        }

        // Basic domain validation
        // Domain parts should contain only valid characters
        let domainParts = domainToCheck.split(separator: ".", omittingEmptySubsequences: false)
        guard !domainParts.isEmpty else {
            throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
        }

        for part in domainParts {
            // Each part should be non-empty
            guard !part.isEmpty else {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }

            // Each part should contain only ASCII alphanumeric characters and hyphens
            // This enforces that international domain names should use punycode
            let validCharacterSet =
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
            guard part.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) else {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }

            // Parts should not start or end with a hyphen
            if part.hasPrefix("-") || part.hasSuffix("-") {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }
        }
    }

    /// Validates the path portion of an origin pattern.
    private static func validatePathPattern(_ path: String, originalPattern: String) throws {
        // Path can be empty (just a trailing slash)
        if path.isEmpty {
            return
        }

        // Wildcard can only appear at the end
        if path.contains("*") {
            // Wildcards in paths must be at the end
            if !path.hasSuffix("*") {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }
            // Only one wildcard allowed
            let wildcardCount = path.count(where: { $0 == "*" })
            if wildcardCount > 1 {
                throw ConfigurationValidationError.invalidOriginPattern(originalPattern)
            }
        }
    }

    /// Checks for conflicting configuration settings.
    ///
    /// - Parameter configuration: The configuration to check.
    /// - Throws: `ConfigurationValidationError.conflictingConfiguration`
    private static func validateNoConflicts(_ configuration: PWAConfiguration) throws {
        // Check if the start URL's host matches at least one allowed origin
        if let startUrl = URL(string: configuration.app.startUrl),
           let host = startUrl.host
        {
            let hostMatchesAllowed = configuration.origins.allowed.contains { pattern in
                originPatternMatches(pattern, host: host)
            }

            if !hostMatchesAllowed {
                throw ConfigurationValidationError.conflictingConfiguration(
                    "Start URL host '\(host)' does not match any allowed origin"
                )
            }
        }

        // Check for origins that appear in both allowed and external
        let allowedSet = Set(configuration.origins.allowed)
        let externalSet = Set(configuration.origins.external)
        let overlap = allowedSet.intersection(externalSet)

        if !overlap.isEmpty {
            throw ConfigurationValidationError.conflictingConfiguration(
                "Origins cannot be both allowed and external: \(overlap.joined(separator: ", "))"
            )
        }
    }

    /// Checks if an origin pattern matches a given host.
    private static func originPatternMatches(_ pattern: String, host: String) -> Bool {
        // Extract just the domain part of the pattern
        let patternDomain = pattern.split(separator: "/", maxSplits: 1)[0]
        let patternString = String(patternDomain)

        if patternString.hasPrefix("*.") {
            // Wildcard pattern: *.example.com matches sub.example.com and example.com
            let baseDomain = String(patternString.dropFirst(2))
            return host == baseDomain || host.hasSuffix(".\(baseDomain)")
        } else {
            // Exact match
            return host == patternString
        }
    }
}
