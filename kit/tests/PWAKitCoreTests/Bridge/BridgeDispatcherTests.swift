import Foundation
import Testing

@testable import PWAKitApp

// MARK: - EchoModule

/// A mock module that echoes back the payload.
struct EchoModule: PWAModule {
    static let moduleName = "echo"
    static let supportedActions = ["echo", "getInfo"]

    func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        switch action {
        case "echo":
            return payload
        case "getInfo":
            return AnyCodable([
                "name": AnyCodable("EchoModule"),
                "version": AnyCodable("1.0"),
            ])
        default:
            throw BridgeError.unknownAction(action)
        }
    }
}

// MARK: - ErrorModule

/// A mock module that always throws an error.
struct ErrorModule: PWAModule {
    static let moduleName = "error"
    static let supportedActions = ["fail", "customError"]

    struct CustomError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        switch action {
        case "fail":
            throw BridgeError.invalidPayload("Intentional failure")
        case "customError":
            throw CustomError(message: "Something went wrong")
        default:
            throw BridgeError.unknownAction(action)
        }
    }
}

// MARK: - AsyncModule

/// A mock module that simulates async work.
struct AsyncModule: PWAModule {
    static let moduleName = "async"
    static let supportedActions = ["delay"]

    func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        switch action {
        case "delay":
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return AnyCodable(["completed": AnyCodable(true)])
        default:
            throw BridgeError.unknownAction(action)
        }
    }
}

// MARK: - BridgeDispatcherTests

@Suite("BridgeDispatcher Tests")
struct BridgeDispatcherTests {
    // MARK: - Message Routing Tests

    @Test("Routes message to correct module")
    func routesToCorrectModule() async throws {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "test-1",
            module: "echo",
            action: "getInfo"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == "test-1")
        #expect(response.success == true)
        #expect(response.data?["name"]?.stringValue == "EchoModule")
    }

    @Test("Routes message with payload to module")
    func routesMessageWithPayload() async throws {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let payload = AnyCodable(["key": AnyCodable("value")])
        let message = BridgeMessage(
            id: "test-2",
            module: "echo",
            action: "echo",
            payload: payload
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["key"]?.stringValue == "value")
    }

    @Test("Routes to multiple registered modules")
    func routesToMultipleModules() async throws {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        await dispatcher.register(AsyncModule())
        let context = await ModuleContext()

        // Route to echo
        let echoMessage = BridgeMessage(id: "echo-1", module: "echo", action: "getInfo")
        let echoResponse = await dispatcher.dispatch(message: echoMessage, context: context)
        #expect(echoResponse.success == true)
        #expect(echoResponse.data?["name"]?.stringValue == "EchoModule")

        // Route to async
        let asyncMessage = BridgeMessage(id: "async-1", module: "async", action: "delay")
        let asyncResponse = await dispatcher.dispatch(message: asyncMessage, context: context)
        #expect(asyncResponse.success == true)
        #expect(asyncResponse.data?["completed"]?.boolValue == true)
    }

    // MARK: - Unknown Module Error Tests

    @Test("Returns error for unknown module")
    func returnsErrorForUnknownModule() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "test-unknown",
            module: "nonexistent",
            action: "anything"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == "test-unknown")
        #expect(response.success == false)
        #expect(response.error?.contains("Unknown module") == true)
        #expect(response.error?.contains("nonexistent") == true)
    }

    @Test("Returns error for empty registry")
    func returnsErrorForEmptyRegistry() async {
        let dispatcher = BridgeDispatcher()
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "test-empty",
            module: "anything",
            action: "anything"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Unknown module") == true)
    }

    // MARK: - Unknown Action Error Tests

    @Test("Returns error for unknown action")
    func returnsErrorForUnknownAction() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "test-action",
            module: "echo",
            action: "unknownAction"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == "test-action")
        #expect(response.success == false)
        #expect(response.error?.contains("Unknown action") == true)
        #expect(response.error?.contains("unknownAction") == true)
    }

    @Test("Validates action before invoking module")
    func validatesActionBeforeInvoke() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule()) // supports "echo" and "getInfo"
        let context = await ModuleContext()

        // Try an action not in supportedActions
        let message = BridgeMessage(
            id: "test-unsupported",
            module: "echo",
            action: "delete" // Not supported
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Unknown action") == true)
    }

    // MARK: - Response Formatting Tests

    @Test("Formats success response as JSON string")
    func formatsSuccessResponseAsJSON() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {"id":"json-test","module":"echo","action":"getInfo"}
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        #expect(jsonResponse.contains("\"id\":\"json-test\""))
        #expect(jsonResponse.contains("\"success\":true"))
        #expect(jsonResponse.contains("\"name\""))
    }

    @Test("Formats error response as JSON string")
    func formatsErrorResponseAsJSON() async {
        let dispatcher = BridgeDispatcher()
        let context = await ModuleContext()

        let jsonMessage = """
        {"id":"error-test","module":"unknown","action":"test"}
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        #expect(jsonResponse.contains("\"id\":\"error-test\""))
        #expect(jsonResponse.contains("\"success\":false"))
        #expect(jsonResponse.contains("\"error\""))
    }

    @Test("Handles invalid JSON gracefully")
    func handlesInvalidJSONGracefully() async {
        let dispatcher = BridgeDispatcher()
        let context = await ModuleContext()

        let invalidJSON = "not valid json"

        let jsonResponse = await dispatcher.dispatch(jsonString: invalidJSON, context: context)

        #expect(jsonResponse.contains("\"success\":false"))
        #expect(jsonResponse.contains("Invalid message format"))
    }

    @Test("Handles malformed JSON message")
    func handlesMalformedJSONMessage() async {
        let dispatcher = BridgeDispatcher()
        let context = await ModuleContext()

        // Missing required field 'action'
        let malformedJSON = """
        {"id":"test","module":"echo"}
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: malformedJSON, context: context)

        #expect(jsonResponse.contains("\"success\":false"))
    }

    @Test("Response includes original request ID")
    func responseIncludesRequestID() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let uniqueID = UUID().uuidString
        let message = BridgeMessage(
            id: uniqueID,
            module: "echo",
            action: "echo"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == uniqueID)
    }

    @Test("Handles module errors gracefully")
    func handlesModuleErrorsGracefully() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(ErrorModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "error-1",
            module: "error",
            action: "fail"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == "error-1")
        #expect(response.success == false)
        #expect(response.error?.contains("Invalid payload") == true)
    }

    @Test("Wraps custom errors as module errors")
    func wrapsCustomErrorsAsModuleErrors() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(ErrorModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "custom-error",
            module: "error",
            action: "customError"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Module error") == true)
        #expect(response.error?.contains("Something went wrong") == true)
    }

    // MARK: - Module Registration via Dispatcher Tests

    @Test("Registers module via dispatcher")
    func registersModuleViaDispatcher() async {
        let dispatcher = BridgeDispatcher()

        let registered = await dispatcher.register(EchoModule())

        #expect(registered == true)
        #expect(await dispatcher.moduleCount == 1)
        #expect(await dispatcher.registeredModuleNames == ["echo"])
    }

    @Test("Registers module conditionally via dispatcher")
    func registersModuleConditionallyViaDispatcher() async {
        let dispatcher = BridgeDispatcher()

        _ = await dispatcher.register(EchoModule(), if: true)
        _ = await dispatcher.register(ErrorModule(), if: false)

        #expect(await dispatcher.moduleCount == 1)
        #expect(await dispatcher.registeredModuleNames == ["echo"])
    }

    @Test("Uses provided registry")
    func usesProvidedRegistry() async {
        let registry = ModuleRegistry()
        await registry.register(EchoModule())
        await registry.register(AsyncModule())

        let dispatcher = BridgeDispatcher(registry: registry)

        #expect(await dispatcher.moduleCount == 2)
    }

    // MARK: - JSON String Dispatch Tests

    @Test("Dispatches JSON string to response object")
    func dispatchesJSONStringToResponse() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {"id":"response-obj","module":"echo","action":"echo","payload":"hello"}
        """

        let response = await dispatcher.dispatchToResponse(jsonString: jsonMessage, context: context)

        #expect(response.id == "response-obj")
        #expect(response.success == true)
        #expect(response.data?.stringValue == "hello")
    }

    @Test("Dispatches complex payload")
    func dispatchesComplexPayload() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "complex",
            "module": "echo",
            "action": "echo",
            "payload": {
                "nested": {
                    "value": 42
                },
                "array": [1, 2, 3]
            }
        }
        """

        let response = await dispatcher.dispatchToResponse(jsonString: jsonMessage, context: context)

        #expect(response.success == true)
        #expect(response.data?["nested"]?["value"]?.intValue == 42)
        #expect(response.data?["array"]?[0]?.intValue == 1)
    }

    // MARK: - Concurrent Dispatch Tests

    @Test("Handles concurrent dispatches")
    func handlesConcurrentDispatches() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(EchoModule())
        await dispatcher.register(AsyncModule())
        let context = await ModuleContext()

        // Dispatch multiple messages concurrently
        await withTaskGroup(of: BridgeResponse.self) { group in
            for i in 0 ..< 50 {
                group.addTask {
                    let message = BridgeMessage(
                        id: "concurrent-\(i)",
                        module: i % 2 == 0 ? "echo" : "async",
                        action: i % 2 == 0 ? "echo" : "delay"
                    )
                    return await dispatcher.dispatch(message: message, context: context)
                }
            }

            var successCount = 0
            for await response in group {
                if response.success {
                    successCount += 1
                }
            }

            #expect(successCount == 50)
        }
    }
}
