import Foundation

// MARK: - BridgeResponse

/// A response from the native bridge to JavaScript.
///
/// `BridgeResponse` represents the result of a native module action invoked
/// by JavaScript. Each response contains:
/// - The request ID matching the original `BridgeMessage`
/// - A success flag indicating whether the action succeeded
/// - Optional data on success
/// - Optional error message on failure
///
/// ## JSON Format
///
/// **Success response:**
/// ```json
/// {
///   "id": "550e8400-e29b-41d4-a716-446655440000",
///   "success": true,
///   "data": { "triggered": true }
/// }
/// ```
///
/// **Error response:**
/// ```json
/// {
///   "id": "550e8400-e29b-41d4-a716-446655440000",
///   "success": false,
///   "error": "Unknown action: invalid"
/// }
/// ```
///
/// ## Example
///
/// ```swift
/// // Create a success response
/// let response = BridgeResponse.success(
///     id: "abc-123",
///     data: ["platform": "iOS", "version": "15.0"]
/// )
///
/// // Create an error response
/// let errorResponse = BridgeResponse.failure(
///     id: "abc-123",
///     error: "Module not found"
/// )
///
/// // Encode to JSON
/// let data = try JSONEncoder().encode(response)
/// ```
public struct BridgeResponse: Codable, Sendable, Equatable {
    /// Request ID that correlates to the original `BridgeMessage`.
    ///
    /// This matches the `id` field from the request, allowing JavaScript
    /// to match responses to their corresponding requests.
    public let id: String

    /// Indicates whether the action completed successfully.
    ///
    /// When `true`, the `data` field may contain result data.
    /// When `false`, the `error` field contains the error message.
    public let success: Bool

    /// Optional result data on success.
    ///
    /// The data structure depends on the module and action.
    /// For example, a platform `getInfo` action might return:
    /// ```json
    /// { "platform": "iOS", "version": "15.0" }
    /// ```
    public let data: AnyCodable?

    /// Optional error message on failure.
    ///
    /// Contains a human-readable error description when `success` is `false`.
    public let error: String?

    /// Creates a new bridge response.
    ///
    /// - Parameters:
    ///   - id: Request ID matching the original `BridgeMessage`.
    ///   - success: Whether the action completed successfully.
    ///   - data: Optional result data on success.
    ///   - error: Optional error message on failure.
    public init(
        id: String,
        success: Bool,
        data: AnyCodable? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.success = success
        self.data = data
        self.error = error
    }

    // MARK: - Factory Methods

    /// Creates a success response with optional data.
    ///
    /// - Parameters:
    ///   - id: Request ID matching the original `BridgeMessage`.
    ///   - data: Optional result data.
    /// - Returns: A success response.
    public static func success(id: String, data: AnyCodable? = nil) -> BridgeResponse {
        BridgeResponse(id: id, success: true, data: data, error: nil)
    }

    /// Creates a failure response with an error message.
    ///
    /// - Parameters:
    ///   - id: Request ID matching the original `BridgeMessage`.
    ///   - error: Error message describing what went wrong.
    /// - Returns: A failure response.
    public static func failure(id: String, error: String) -> BridgeResponse {
        BridgeResponse(id: id, success: false, data: nil, error: error)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case success
        case data
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.success = try container.decode(Bool.self, forKey: .success)
        self.data = try container.decodeIfPresent(AnyCodable.self, forKey: .data)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

// MARK: CustomStringConvertible

extension BridgeResponse: CustomStringConvertible {
    public var description: String {
        var parts = ["BridgeResponse(id: \(id), success: \(success)"]
        if let data {
            parts.append(", data: \(data)")
        }
        if let error {
            parts.append(", error: \"\(error)\"")
        }
        parts.append(")")
        return parts.joined()
    }
}
