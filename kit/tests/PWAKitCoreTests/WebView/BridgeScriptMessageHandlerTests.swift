import Foundation
@testable import PWAKitApp
import Testing
import WebKit

// MARK: - BridgeMessageFlowTests

/// Tests for message parsing and response formatting that work on all platforms.
/// These tests focus on the BridgeDispatcher and JavaScriptBridge functionality
/// that the BridgeScriptMessageHandler relies on.
@Suite("Bridge Message Flow Tests")
@MainActor
struct BridgeMessageFlowTests {
    // MARK: - Message Parsing Tests

    @Test("Parses JSON string message body")
    func parsesJSONStringMessageBody() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        // Create a JSON message
        let jsonMessage = """
        {"id":"test-123","module":"test","action":"echo","payload":{"key":"value"}}
        """

        // Test via the dispatcher to verify the message format is correct
        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatchToResponse(jsonString: jsonMessage, context: context)

        #expect(response.id == "test-123")
        #expect(response.success == true)
    }

    @Test("Parses dictionary message body")
    func parsesDictionaryMessageBody() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        // Test that dispatcher correctly handles a properly formed message
        let message = BridgeMessage(
            id: "dict-test",
            module: "test",
            action: "echo",
            payload: AnyCodable(["nested": AnyCodable("value")])
        )

        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.id == "dict-test")
        #expect(response.success == true)
        #expect(response.data?["nested"]?.stringValue == "value")
    }

    @Test("Handles invalid JSON gracefully")
    func handlesInvalidJSONGracefully() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        // Send malformed JSON
        let invalidJSON = "{ this is not valid json }"
        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatchToResponse(jsonString: invalidJSON, context: context)

        #expect(response.success == false)
        #expect(response.error != nil)
        #expect(response.id == "parse-error")
    }

    @Test("Handles empty message gracefully")
    func handlesEmptyMessageGracefully() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatchToResponse(jsonString: "", context: context)

        #expect(response.success == false)
        #expect(response.error != nil)
    }

    // MARK: - Response Sending Tests

    @Test("Formats response as JavaScript callback")
    func formatsResponseAsJavaScriptCallback() {
        let response = BridgeResponse.success(id: "test-id", data: AnyCodable(["result": AnyCodable(true)]))
        let javascript = JavaScriptBridge.formatCallback(response)

        #expect(javascript.contains("window.pwakit._handleResponse"))
        #expect(javascript.contains("test-id"))
        #expect(javascript.contains("true"))
    }

    @Test("Formats error response as JavaScript callback")
    func formatsErrorResponseAsJavaScriptCallback() {
        let response = BridgeResponse.failure(id: "error-id", error: "Something went wrong")
        let javascript = JavaScriptBridge.formatCallback(response)

        #expect(javascript.contains("window.pwakit._handleResponse"))
        #expect(javascript.contains("error-id"))
        #expect(javascript.contains("Something went wrong"))
        #expect(javascript.contains("\"success\":false"))
    }

    @Test("Formats response from JSON string")
    func formatsResponseFromJSONString() {
        let jsonString = """
        {"id":"json-test","success":true,"data":{"key":"value"}}
        """
        let javascript = JavaScriptBridge.formatCallback(jsonString: jsonString)

        #expect(javascript.contains("window.pwakit._handleResponse"))
        #expect(javascript.contains("json-test"))
    }

    // MARK: - Event Sending Tests

    @Test("Formats bridge event as JavaScript")
    func formatsBridgeEventAsJavaScript() {
        let event = BridgeEvent(type: "push", data: AnyCodable(["title": AnyCodable("New Message")]))
        let javascript = JavaScriptBridge.formatEvent(event)

        #expect(javascript.contains("window.pwakit._handleEvent"))
        #expect(javascript.contains("push"))
        #expect(javascript.contains("New Message"))
    }

    @Test("Formats event with type and data")
    func formatsEventWithTypeAndData() {
        let javascript = JavaScriptBridge.formatEvent(
            type: "lifecycle",
            data: AnyCodable(["state": AnyCodable("foreground")])
        )

        #expect(javascript.contains("window.pwakit._handleEvent"))
        #expect(javascript.contains("lifecycle"))
        #expect(javascript.contains("foreground"))
    }

    // MARK: - Integration Tests

    @Test("Complete message flow through dispatcher")
    func completeMessageFlowThroughDispatcher() async throws {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        let message = """
        {
            "id": "integration-test",
            "module": "test",
            "action": "echo",
            "payload": {"greeting": "hello"}
        }
        """

        let context = ModuleContext(configuration: .default)
        let responseJSON = await dispatcher.dispatch(jsonString: message, context: context)

        // Verify response is valid JSON
        let responseData = Data(responseJSON.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: responseData)

        #expect(response.id == "integration-test")
        #expect(response.success == true)
        #expect(response.data?["greeting"]?.stringValue == "hello")
    }

    @Test("Handler routes to correct module action")
    func handlerRoutesToCorrectModuleAction() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        let message = BridgeMessage(
            id: "route-test",
            module: "test",
            action: "getInfo"
        )

        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["name"]?.stringValue == "test")
        #expect(response.data?["version"]?.stringValue == "1.0.0")
    }

    @Test("Handler returns error for unknown module")
    func handlerReturnsErrorForUnknownModule() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        let message = BridgeMessage(
            id: "unknown-module-test",
            module: "nonexistent",
            action: "doSomething"
        )

        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("nonexistent") == true)
    }

    @Test("Handler returns error for unknown action")
    func handlerReturnsErrorForUnknownAction() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())

        let message = BridgeMessage(
            id: "unknown-action-test",
            module: "test",
            action: "nonexistentAction"
        )

        let context = ModuleContext(configuration: .default)
        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("nonexistentAction") == true)
    }
}

// MARK: - JSONExtractionTests

@Suite("JSON Extraction Tests")
@MainActor
struct JSONExtractionTests {
    @Test("Valid JSON object serializes correctly")
    func validJSONObjectSerializesCorrectly() throws {
        let dict: [String: Any] = [
            "id": "test",
            "module": "platform",
            "action": "getInfo",
        ]

        #expect(JSONSerialization.isValidJSONObject(dict) == true)

        let data = try JSONSerialization.data(withJSONObject: dict)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString?.contains("test") == true)
    }

    @Test("String passes through directly")
    func stringPassesThroughDirectly() throws {
        let jsonString = """
        {"id":"direct","module":"test","action":"echo"}
        """

        // Verify string is valid JSON
        let data = Data(jsonString.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data)

        #expect(parsed is [String: Any])
    }

    @Test("Array of values serializes correctly")
    func arrayOfValuesSerializesCorrectly() throws {
        let array: [[String: Any]] = [
            ["id": "1", "value": "first"],
            ["id": "2", "value": "second"],
        ]

        #expect(JSONSerialization.isValidJSONObject(array) == true)

        let data = try JSONSerialization.data(withJSONObject: array)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString != nil)
    }
}

@testable import PWAKitApp

// MARK: - iOS-Specific Handler Tests
import Testing
import UIKit
import WebKit

// MARK: - MockWebView

/// Mock web view for testing JavaScript evaluation.
@MainActor
final class MockWebView: NSObject {
    /// The JavaScript code that was evaluated.
    var evaluatedJavaScript: [String] = []

    /// Completion handlers for evaluated JavaScript.
    var completionHandlers: [(Any?, Error?) -> Void] = []

    /// Whether to simulate an error on evaluateJavaScript.
    var shouldSimulateError = false

    /// The error to return when simulating errors.
    var simulatedError: Error?

    /// Simulates the evaluateJavaScript method of WKWebView.
    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?) {
        evaluatedJavaScript.append(javaScriptString)
        if let handler = completionHandler {
            completionHandlers.append(handler)
            if shouldSimulateError {
                handler(nil, simulatedError ?? NSError(domain: "Test", code: -1))
            } else {
                handler(nil, nil)
            }
        }
    }
}

// MARK: - BridgeScriptMessageHandlerIOSTests

@Suite("BridgeScriptMessageHandler iOS Tests")
@MainActor
struct BridgeScriptMessageHandlerIOSTests {
    // MARK: - ModuleContextFactory Tests

    @Test("ModuleContextFactory creates context")
    func moduleContextFactoryCreatesContext() {
        let factory = ModuleContextFactory()
        let context = factory.makeContext(
            webView: nil,
            viewController: nil,
            configuration: .default
        )

        #expect(context.configuration.app.name == "PWAKit")
    }

    @Test("ModuleContextFactory preserves configuration")
    func moduleContextFactoryPreservesConfiguration() {
        let customConfig = PWAConfiguration(
            version: 2,
            app: AppConfiguration(
                name: "Custom App",
                bundleId: "com.custom.app",
                startUrl: "https://custom.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["custom.example.com"],
                auth: [],
                external: []
            ),
            features: .default,
            appearance: .default,
            notifications: .default
        )

        let factory = ModuleContextFactory()
        let context = factory.makeContext(
            webView: nil,
            viewController: nil,
            configuration: customConfig
        )

        #expect(context.configuration.app.name == "Custom App")
        #expect(context.configuration.version == 2)
    }

    // MARK: - Handler Initialization Tests

    @Test("Handler initializes with dispatcher")
    func handlerInitializesWithDispatcher() {
        let dispatcher = BridgeDispatcher()
        let handler = BridgeScriptMessageHandler(dispatcher: dispatcher)

        #expect(handler.webView == nil)
        #expect(handler.viewController == nil)
    }

    @Test("Handler initializes with custom configuration")
    func handlerInitializesWithCustomConfiguration() {
        let customConfig = PWAConfiguration(
            version: 1,
            app: AppConfiguration(
                name: "Test App",
                bundleId: "com.test.app",
                startUrl: "https://test.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["test.example.com"],
                auth: [],
                external: []
            ),
            features: .default,
            appearance: .default,
            notifications: .default
        )

        let dispatcher = BridgeDispatcher()
        let handler = BridgeScriptMessageHandler(
            dispatcher: dispatcher,
            configuration: customConfig
        )

        #expect(handler.configuration.app.name == "Test App")
    }

    @Test("Handler configuration can be updated")
    func handlerConfigurationCanBeUpdated() {
        let dispatcher = BridgeDispatcher()
        let handler = BridgeScriptMessageHandler(dispatcher: dispatcher)

        let newConfig = PWAConfiguration(
            version: 3,
            app: AppConfiguration(
                name: "Updated App",
                bundleId: "com.updated.app",
                startUrl: "https://updated.example.com/"
            ),
            origins: OriginsConfiguration(
                allowed: ["updated.example.com"],
                auth: [],
                external: []
            ),
            features: .default,
            appearance: .default,
            notifications: .default
        )

        handler.configuration = newConfig

        #expect(handler.configuration.app.name == "Updated App")
        #expect(handler.configuration.version == 3)
    }
}
