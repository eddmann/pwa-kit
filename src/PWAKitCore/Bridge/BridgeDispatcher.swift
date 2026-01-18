import Foundation

/// Actor responsible for routing bridge messages to registered modules.
///
/// `BridgeDispatcher` is the central coordinator for the JavaScript-to-Swift bridge.
/// It receives messages from JavaScript, parses them, routes them to the appropriate
/// module, and returns responses.
///
/// ## Usage
///
/// ```swift
/// let dispatcher = BridgeDispatcher()
///
/// // Register modules
/// await dispatcher.register(PlatformModule())
/// await dispatcher.register(HapticsModule())
///
/// // Dispatch a message
/// let jsonMessage = """
/// {
///   "id": "abc-123",
///   "module": "platform",
///   "action": "getInfo"
/// }
/// """
///
/// let response = await dispatcher.dispatch(jsonString: jsonMessage, context: context)
/// // response is a JSON string: {"id":"abc-123","success":true,"data":{...}}
/// ```
///
/// ## Error Handling
///
/// The dispatcher handles errors gracefully and always returns a valid JSON response:
/// - Unknown modules return an error response with `unknownModule` message
/// - Unknown actions return an error response with `unknownAction` message
/// - Invalid JSON returns an error response with parsing details
/// - Module errors are wrapped and returned as error responses
public actor BridgeDispatcher {
    /// The registry containing all registered modules.
    private let registry: ModuleRegistry

    /// JSON decoder for parsing incoming messages.
    private let decoder: JSONDecoder

    /// JSON encoder for creating responses.
    private let encoder: JSONEncoder

    /// Creates a new bridge dispatcher with an empty module registry.
    public init() {
        self.registry = ModuleRegistry()
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// Creates a new bridge dispatcher with a pre-configured registry.
    ///
    /// This initializer is useful for testing or when modules are registered
    /// elsewhere and passed in.
    ///
    /// - Parameter registry: The module registry to use.
    public init(registry: ModuleRegistry) {
        self.registry = registry
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Module Registration

    /// Registers a module with the dispatcher.
    ///
    /// - Parameters:
    ///   - module: The module to register.
    ///   - allowOverwrite: Whether to allow overwriting an existing registration.
    /// - Returns: `true` if the module was registered successfully.
    @discardableResult
    public func register(_ module: some PWAModule, allowOverwrite: Bool = true) async -> Bool {
        await registry.register(module, allowOverwrite: allowOverwrite)
    }

    /// Registers a module conditionally based on a flag.
    ///
    /// - Parameters:
    ///   - module: The module to register.
    ///   - condition: The condition that must be true for registration.
    ///   - allowOverwrite: Whether to allow overwriting an existing registration.
    /// - Returns: `true` if the module was registered successfully.
    @discardableResult
    public func register(
        _ module: some PWAModule,
        if condition: Bool,
        allowOverwrite: Bool = true
    ) async -> Bool {
        await registry.register(module, if: condition, allowOverwrite: allowOverwrite)
    }

    /// Returns the names of all registered modules.
    public var registeredModuleNames: [String] {
        get async {
            await registry.registeredModuleNames
        }
    }

    /// Returns the count of registered modules.
    public var moduleCount: Int {
        get async {
            await registry.moduleCount
        }
    }

    // MARK: - Message Dispatching

    /// Dispatches a JSON message string and returns a JSON response string.
    ///
    /// This is the primary entry point for the bridge. It parses the incoming
    /// JSON message, routes it to the appropriate module, and returns a JSON
    /// response string.
    ///
    /// - Parameters:
    ///   - jsonString: The JSON-encoded bridge message.
    ///   - context: The module context for the request.
    /// - Returns: A JSON-encoded bridge response string.
    public func dispatch(jsonString: String, context: ModuleContext) async -> String {
        let response = await dispatchToResponse(jsonString: jsonString, context: context)
        return encodeResponse(response)
    }

    /// Dispatches a JSON message string and returns a `BridgeResponse`.
    ///
    /// This method is useful when you need to work with the response object
    /// directly rather than its JSON representation.
    ///
    /// - Parameters:
    ///   - jsonString: The JSON-encoded bridge message.
    ///   - context: The module context for the request.
    /// - Returns: The bridge response.
    public func dispatchToResponse(jsonString: String, context: ModuleContext) async -> BridgeResponse {
        // Parse the incoming message
        let message: BridgeMessage
        do {
            message = try parseMessage(jsonString)
        } catch {
            // Return an error response with a generated ID for parse failures
            return BridgeResponse.failure(
                id: "parse-error",
                error: "Invalid message format: \(error.localizedDescription)"
            )
        }

        // Dispatch the parsed message
        return await dispatch(message: message, context: context)
    }

    /// Dispatches a `BridgeMessage` and returns a `BridgeResponse`.
    ///
    /// This method is useful for programmatic message dispatch without JSON parsing.
    ///
    /// - Parameters:
    ///   - message: The bridge message to dispatch.
    ///   - context: The module context for the request.
    /// - Returns: The bridge response.
    public func dispatch(message: BridgeMessage, context: ModuleContext) async -> BridgeResponse {
        // Look up the module
        guard let module = await registry.module(named: message.module) else {
            return BridgeResponse.failure(
                id: message.id,
                error: BridgeError.unknownModule(message.module).localizedDescription
            )
        }

        // Validate the action is supported
        guard type(of: module).supports(action: message.action) else {
            return BridgeResponse.failure(
                id: message.id,
                error: BridgeError.unknownAction(message.action).localizedDescription
            )
        }

        // Invoke the module handler
        do {
            let result = try await module.handle(
                action: message.action,
                payload: message.payload,
                context: context
            )
            return BridgeResponse.success(id: message.id, data: result)
        } catch let error as BridgeError {
            return BridgeResponse.failure(id: message.id, error: error.localizedDescription)
        } catch {
            let bridgeError = BridgeError.moduleError(underlying: error)
            return BridgeResponse.failure(id: message.id, error: bridgeError.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Parses a JSON string into a `BridgeMessage`.
    ///
    /// - Parameter jsonString: The JSON string to parse.
    /// - Returns: The parsed bridge message.
    /// - Throws: A decoding error if parsing fails.
    private func parseMessage(_ jsonString: String) throws -> BridgeMessage {
        guard let data = jsonString.data(using: .utf8) else {
            throw BridgeError.invalidPayload("Invalid UTF-8 encoding")
        }
        return try decoder.decode(BridgeMessage.self, from: data)
    }

    /// Encodes a `BridgeResponse` to a JSON string.
    ///
    /// - Parameter response: The response to encode.
    /// - Returns: The JSON-encoded response string.
    private func encodeResponse(_ response: BridgeResponse) -> String {
        do {
            let data = try encoder.encode(response)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            // Fallback to manually constructed JSON if encoding fails
            let escaped = response.error?.replacingOccurrences(of: "\"", with: "\\\"") ?? ""
            return """
            {"id":"\(response.id)","success":false,"error":"Encoding error: \(escaped)"}
            """
        }
    }
}
