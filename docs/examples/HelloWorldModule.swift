import Foundation

// MARK: - HelloWorldModule

/// A simple example module demonstrating the PWAModule protocol.
///
/// This module shows the basic structure and patterns for creating
/// custom bridge modules in PWAKit.
///
/// ## Supported Actions
///
/// - `greet`: Returns a greeting message
///   - Payload: `{ "name": "string" }` (optional)
///   - Response: `{ "message": "string", "timestamp": number }`
///
/// - `echo`: Echoes back the provided text
///   - Payload: `{ "text": "string" }` (required)
///   - Response: `{ "echoed": "string", "length": number }`
///
/// - `add`: Adds two numbers together
///   - Payload: `{ "a": number, "b": number }` (required)
///   - Response: `{ "result": number }`
///
/// ## JavaScript Usage
///
/// ```javascript
/// const greeting = await bridge.call('helloWorld', 'greet', { name: 'Dev' });
/// console.log(greeting.message); // "Hello, Dev!"
///
/// const echo = await bridge.call('helloWorld', 'echo', { text: 'Test' });
/// console.log(echo.echoed); // "Test"
///
/// const sum = await bridge.call('helloWorld', 'add', { a: 5, b: 3 });
/// console.log(sum.result); // 8
/// ```
public struct HelloWorldModule: PWAModule {
    // MARK: - PWAModule Protocol

    /// The unique name for this module, used for routing from JavaScript.
    public static let moduleName = "helloWorld"

    /// The list of actions this module supports.
    public static let supportedActions = ["greet", "echo", "add"]

    // MARK: - Initialization

    /// Creates a new HelloWorldModule instance.
    public init() {}

    // MARK: - Handle

    /// Handles incoming action requests from JavaScript.
    ///
    /// - Parameters:
    ///   - action: The action name (e.g., "greet", "echo", "add")
    ///   - payload: Optional payload with action-specific data
    ///   - context: Module context with app resources
    ///
    /// - Returns: The action result as AnyCodable
    /// - Throws: BridgeError for invalid actions or payloads
    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        // Always validate the action first using the built-in helper
        try validateAction(action)

        // Route to the appropriate handler
        switch action {
        case "greet":
            return handleGreet(payload: payload)

        case "echo":
            return try handleEcho(payload: payload)

        case "add":
            return try handleAdd(payload: payload)

        default:
            // This shouldn't happen if validateAction passed,
            // but we handle it for completeness
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Action Handlers

    /// Handles the "greet" action.
    ///
    /// - Parameter payload: Optional payload with "name" field
    /// - Returns: Greeting message with timestamp
    private func handleGreet(payload: AnyCodable?) -> AnyCodable {
        // Extract name from payload, defaulting to "World"
        let name = payload?["name"]?.stringValue ?? "World"

        return AnyCodable([
            "message": AnyCodable("Hello, \(name)!"),
            "timestamp": AnyCodable(Date().timeIntervalSince1970),
        ])
    }

    /// Handles the "echo" action.
    ///
    /// - Parameter payload: Required payload with "text" field
    /// - Returns: The echoed text with its length
    /// - Throws: BridgeError.invalidPayload if "text" is missing
    private func handleEcho(payload: AnyCodable?) throws -> AnyCodable {
        // Validate required field
        guard let text = payload?["text"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'text' field")
        }

        return AnyCodable([
            "echoed": AnyCodable(text),
            "length": AnyCodable(text.count),
        ])
    }

    /// Handles the "add" action.
    ///
    /// - Parameter payload: Required payload with "a" and "b" numeric fields
    /// - Returns: The sum of the two numbers
    /// - Throws: BridgeError.invalidPayload if "a" or "b" is missing
    private func handleAdd(payload: AnyCodable?) throws -> AnyCodable {
        // Validate required fields
        guard let a = payload?["a"]?.doubleValue,
              let b = payload?["b"]?.doubleValue
        else {
            throw BridgeError.invalidPayload("Missing required 'a' and 'b' numeric fields")
        }

        return AnyCodable([
            "result": AnyCodable(a + b),
        ])
    }
}
