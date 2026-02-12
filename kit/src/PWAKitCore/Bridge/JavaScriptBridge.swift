import Foundation

// MARK: - JavaScriptBridge

/// Helper for generating JavaScript code to send responses and events to the web layer.
///
/// `JavaScriptBridge` provides utilities for formatting native responses as JavaScript
/// code that can be evaluated in a WKWebView. It handles proper escaping of special
/// characters and supports both callback-style responses and event dispatching.
///
/// ## Callback Style
///
/// For request/response communication, use `formatCallback(_:)` to generate JavaScript
/// that invokes the bridge's response handler:
///
/// ```swift
/// let response = BridgeResponse.success(id: "abc-123", data: ["status": "ok"])
/// let js = JavaScriptBridge.formatCallback(response)
/// // Result: window.pwakit._handleResponse({"id":"abc-123","success":true,"data":{"status":"ok"}});
/// ```
///
/// ## Event Dispatch Style
///
/// For unsolicited events (like push notifications), use `formatEvent(_:)` to generate
/// JavaScript that dispatches a custom event:
///
/// ```swift
/// let event = BridgeEvent(type: "push", data: ["title": "New Message"])
/// let js = JavaScriptBridge.formatEvent(event)
/// // Result: window.pwakit._handleEvent({"type":"push","data":{"title":"New Message"}});
/// ```
///
/// ## Character Escaping
///
/// All string values are properly escaped to prevent JavaScript injection and ensure
/// valid JavaScript syntax. This includes:
/// - Backslashes (`\` → `\\`)
/// - Quotes (`"` → `\"`)
/// - Newlines (`\n`, `\r`)
/// - Line separators (U+2028, U+2029)
/// - Tab characters
public enum JavaScriptBridge {
    // MARK: - Callback Style

    /// Formats a bridge response as a JavaScript callback invocation.
    ///
    /// Generates JavaScript code that calls `window.pwakit._handleResponse()`
    /// with the response encoded as JSON. This is the primary method for sending
    /// responses back to JavaScript for request/response style communication.
    ///
    /// - Parameter response: The bridge response to format.
    /// - Returns: JavaScript code string ready for evaluation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let response = BridgeResponse.success(id: "abc-123", data: ["platform": "iOS"])
    /// let js = JavaScriptBridge.formatCallback(response)
    /// await webView.evaluateJavaScript(js)
    /// ```
    public static func formatCallback(_ response: BridgeResponse) -> String {
        let json = encodeToJSON(response)
        return "window.pwakit._handleResponse(\(json));"
    }

    /// Formats a JSON string as a JavaScript callback invocation.
    ///
    /// Use this method when you already have a JSON-encoded response string.
    ///
    /// - Parameter jsonString: The JSON-encoded response.
    /// - Returns: JavaScript code string ready for evaluation.
    public static func formatCallback(jsonString: String) -> String {
        "window.pwakit._handleResponse(\(jsonString));"
    }

    // MARK: - Event Dispatch Style

    /// Formats a bridge event as a JavaScript event dispatch.
    ///
    /// Generates JavaScript code that calls `window.pwakit._handleEvent()`
    /// with the event encoded as JSON. The web layer's event handler will
    /// dispatch a CustomEvent on the window object.
    ///
    /// - Parameter event: The bridge event to format.
    /// - Returns: JavaScript code string ready for evaluation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let event = BridgeEvent(type: "push", data: ["title": "Hello"])
    /// let js = JavaScriptBridge.formatEvent(event)
    /// await webView.evaluateJavaScript(js)
    /// // JavaScript receives CustomEvent "pwa:push" with detail: { title: "Hello" }
    /// ```
    public static func formatEvent(_ event: BridgeEvent) -> String {
        let json = encodeToJSON(event)
        return "window.pwakit._handleEvent(\(json));"
    }

    /// Formats an event with type and data as a JavaScript event dispatch.
    ///
    /// Convenience method for dispatching events without creating a `BridgeEvent` object.
    ///
    /// - Parameters:
    ///   - type: The event type (e.g., "push", "lifecycle").
    ///   - data: The event data payload.
    /// - Returns: JavaScript code string ready for evaluation.
    public static func formatEvent(type: String, data: AnyCodable?) -> String {
        let event = BridgeEvent(type: type, data: data)
        return formatEvent(event)
    }

    // MARK: - String Escaping

    /// Escapes a string for safe inclusion in JavaScript code.
    ///
    /// This method handles all special characters that could break JavaScript
    /// string parsing or potentially allow injection attacks:
    /// - Backslashes are doubled
    /// - Double quotes are escaped
    /// - Newlines, carriage returns, and tabs are escaped
    /// - Line separators (U+2028) and paragraph separators (U+2029) are escaped
    ///
    /// - Parameter string: The string to escape.
    /// - Returns: A JavaScript-safe escaped string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let input = "Hello \"World\"\nLine 2"
    /// let escaped = JavaScriptBridge.escapeForJavaScript(input)
    /// // Result: Hello \"World\"\nLine 2
    /// ```
    public static func escapeForJavaScript(_ string: String) -> String {
        // Order matters: escape backslashes first to avoid double-escaping
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            // Unicode line separators that can break JavaScript string literals
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    // MARK: - JSON Encoding

    /// Encodes an encodable value to a JSON string for JavaScript evaluation.
    ///
    /// The encoder is configured to produce compact output suitable for
    /// inclusion in JavaScript code.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: A JSON string, or "{}" if encoding fails.
    public static func encodeToJSON(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact output

        do {
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

// MARK: - BridgeEvent

/// An event from native code to JavaScript.
///
/// `BridgeEvent` represents an unsolicited notification from the native layer
/// to the web layer. Unlike `BridgeResponse`, events are not correlated with
/// a request ID and are typically used for:
/// - Push notification delivery
/// - App lifecycle changes
/// - System state updates
///
/// ## JSON Format
///
/// ```json
/// {
///   "type": "push",
///   "data": {
///     "title": "New Message",
///     "body": "You have a new message"
///   }
/// }
/// ```
///
/// ## Web Layer Handling
///
/// When JavaScript receives an event, it dispatches a CustomEvent on the window:
///
/// ```javascript
/// window.addEventListener("pwa:push", (event) => {
///   console.log(event.detail.title); // "New Message"
/// });
/// ```
public struct BridgeEvent: Codable, Sendable, Equatable {
    /// The event type identifier.
    ///
    /// Common types include:
    /// - `"push"`: Push notification received
    /// - `"lifecycle"`: App lifecycle change
    /// - `"deeplink"`: Deep link activated
    public let type: String

    /// The event payload data.
    ///
    /// The structure depends on the event type. For push notifications:
    /// ```json
    /// {
    ///   "title": "...",
    ///   "body": "...",
    ///   "userInfo": { ... }
    /// }
    /// ```
    public let data: AnyCodable?

    /// Creates a new bridge event.
    ///
    /// - Parameters:
    ///   - type: The event type identifier.
    ///   - data: Optional event payload data.
    public init(type: String, data: AnyCodable? = nil) {
        self.type = type
        self.data = data
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.data = try container.decodeIfPresent(AnyCodable.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

// MARK: CustomStringConvertible

extension BridgeEvent: CustomStringConvertible {
    public var description: String {
        var parts = ["BridgeEvent(type: \(type)"]
        if let data {
            parts.append(", data: \(data)")
        }
        parts.append(")")
        return parts.joined()
    }
}
