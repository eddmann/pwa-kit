import Foundation
@testable import PWAKitApp
import Testing

/// Integration tests that verify the complete message flow through the bridge system.
///
/// These tests use `TestModule` to exercise the full path from JSON message
/// parsing through module dispatch and back to JSON response encoding.
@Suite("Bridge Integration Tests")
struct BridgeIntegrationTests {
    // MARK: - Full Message Flow Tests

    @Test("Complete echo flow from JSON to JSON")
    func completeEchoFlowFromJSONToJSON() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "integration-echo-1",
            "module": "test",
            "action": "echo",
            "payload": {"message": "Hello, Bridge!"}
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        // Parse response to verify structure
        guard let responseData = jsonResponse.data(using: .utf8),
              let response = try? JSONDecoder().decode(BridgeResponse.self, from: responseData) else
        {
            Issue.record("Failed to parse response JSON")
            return
        }

        #expect(response.id == "integration-echo-1")
        #expect(response.success == true)
        #expect(response.data?["message"]?.stringValue == "Hello, Bridge!")
    }

    @Test("Complete error flow from JSON to JSON")
    func completeErrorFlowFromJSONToJSON() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "integration-error-1",
            "module": "test",
            "action": "error",
            "payload": {"type": "bridge", "message": "Test failure"}
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        guard let responseData = jsonResponse.data(using: .utf8),
              let response = try? JSONDecoder().decode(BridgeResponse.self, from: responseData) else
        {
            Issue.record("Failed to parse response JSON")
            return
        }

        #expect(response.id == "integration-error-1")
        #expect(response.success == false)
        #expect(response.error?.contains("Test failure") == true)
    }

    @Test("Complete async flow with delay")
    func completeAsyncFlowWithDelay() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "integration-delay-1",
            "module": "test",
            "action": "delay",
            "payload": {"milliseconds": 5}
        }
        """

        let startTime = Date()
        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)
        let elapsed = Date().timeIntervalSince(startTime)

        guard let responseData = jsonResponse.data(using: .utf8),
              let response = try? JSONDecoder().decode(BridgeResponse.self, from: responseData) else
        {
            Issue.record("Failed to parse response JSON")
            return
        }

        #expect(response.success == true)
        #expect(response.data?["completed"]?.boolValue == true)
        #expect(response.data?["delayMs"]?.intValue == 5)
        #expect(elapsed >= 0.005) // At least 5ms
    }

    // MARK: - Message Object Flow Tests

    @Test("Echo action returns payload unchanged")
    func echoActionReturnsPayloadUnchanged() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let payload = AnyCodable([
            "string": AnyCodable("test"),
            "number": AnyCodable(42),
            "boolean": AnyCodable(true),
            "nested": AnyCodable(["key": AnyCodable("value")]),
        ])

        let message = BridgeMessage(
            id: "echo-test",
            module: "test",
            action: "echo",
            payload: payload
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["string"]?.stringValue == "test")
        #expect(response.data?["number"]?.intValue == 42)
        #expect(response.data?["boolean"]?.boolValue == true)
        #expect(response.data?["nested"]?["key"]?.stringValue == "value")
    }

    @Test("Echo action with nil payload returns nil data")
    func echoActionWithNilPayloadReturnsNilData() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "echo-nil",
            module: "test",
            action: "echo"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data == nil)
    }

    @Test("Error action throws bridge error")
    func errorActionThrowsBridgeError() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "error-bridge",
            module: "test",
            action: "error",
            payload: AnyCodable(["type": AnyCodable("bridge"), "message": AnyCodable("Invalid data")])
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Invalid payload") == true)
        #expect(response.error?.contains("Invalid data") == true)
    }

    @Test("Error action throws custom error")
    func errorActionThrowsCustomError() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "error-custom",
            module: "test",
            action: "error",
            payload: AnyCodable(["type": AnyCodable("custom"), "message": AnyCodable("Custom failure")])
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Module error") == true)
        #expect(response.error?.contains("Custom failure") == true)
    }

    @Test("Error action with default error")
    func errorActionWithDefaultError() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "error-default",
            module: "test",
            action: "error"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == false)
        #expect(response.error?.contains("Test error") == true)
    }

    @Test("Delay action completes with configured delay")
    func delayActionCompletesWithConfiguredDelay() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "delay-test",
            module: "test",
            action: "delay",
            payload: AnyCodable(["milliseconds": AnyCodable(10)])
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["completed"]?.boolValue == true)
        #expect(response.data?["delayMs"]?.intValue == 10)
    }

    @Test("Delay action with default delay")
    func delayActionWithDefaultDelay() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "delay-default",
            module: "test",
            action: "delay"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["delayMs"]?.intValue == 10) // Default 10ms
    }

    @Test("GetInfo action returns module information")
    func getInfoActionReturnsModuleInfo() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "info-test",
            module: "test",
            action: "getInfo"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["name"]?.stringValue == "test")
        #expect(response.data?["version"]?.stringValue == "1.0.0")

        let actions = response.data?["actions"]?.arrayValue
        #expect(actions?.count == 4)
    }

    // MARK: - Multi-Module Integration Tests

    @Test("Multiple modules coexist and route correctly")
    func multipleModulesCoexistAndRouteCorrectly() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        // Verify test module is accessible
        let testMessage = BridgeMessage(
            id: "multi-test",
            module: "test",
            action: "getInfo"
        )
        let testResponse = await dispatcher.dispatch(message: testMessage, context: context)
        #expect(testResponse.success == true)
        #expect(testResponse.data?["name"]?.stringValue == "test")

        // Verify unknown module returns error
        let unknownMessage = BridgeMessage(
            id: "multi-unknown",
            module: "unknown",
            action: "anything"
        )
        let unknownResponse = await dispatcher.dispatch(message: unknownMessage, context: context)
        #expect(unknownResponse.success == false)
        #expect(unknownResponse.error?.contains("Unknown module") == true)
    }

    // MARK: - Concurrent Request Tests

    @Test("Handles concurrent requests correctly")
    func handlesConcurrentRequestsCorrectly() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        await withTaskGroup(of: BridgeResponse.self) { group in
            // Send 20 concurrent requests with different actions
            for i in 0 ..< 20 {
                group.addTask {
                    let action: String
                    let payload: AnyCodable?

                    switch i % 4 {
                    case 0:
                        action = "echo"
                        payload = AnyCodable(["index": AnyCodable(i)])
                    case 1:
                        action = "delay"
                        payload = AnyCodable(["milliseconds": AnyCodable(1)])
                    case 2:
                        action = "getInfo"
                        payload = nil
                    default:
                        action = "echo"
                        payload = AnyCodable("request-\(i)")
                    }

                    let message = BridgeMessage(
                        id: "concurrent-\(i)",
                        module: "test",
                        action: action,
                        payload: payload
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

            #expect(successCount == 20)
        }
    }

    @Test("Handles concurrent errors correctly")
    func handlesConcurrentErrorsCorrectly() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        await withTaskGroup(of: BridgeResponse.self) { group in
            // Send 10 error requests concurrently
            for i in 0 ..< 10 {
                group.addTask {
                    let message = BridgeMessage(
                        id: "concurrent-error-\(i)",
                        module: "test",
                        action: "error",
                        payload: AnyCodable(["message": AnyCodable("Error \(i)")])
                    )
                    return await dispatcher.dispatch(message: message, context: context)
                }
            }

            var errorCount = 0
            for await response in group {
                if !response.success {
                    errorCount += 1
                }
            }

            #expect(errorCount == 10)
        }
    }

    // MARK: - Edge Case Tests

    @Test("Handles empty JSON object payload")
    func handlesEmptyJSONObjectPayload() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "empty-payload",
            "module": "test",
            "action": "echo",
            "payload": {}
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        #expect(jsonResponse.contains("\"success\":true"))
    }

    @Test("Handles array payload")
    func handlesArrayPayload() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let payload = AnyCodable([
            AnyCodable(1),
            AnyCodable(2),
            AnyCodable(3),
        ])

        let message = BridgeMessage(
            id: "array-payload",
            module: "test",
            action: "echo",
            payload: payload
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?[0]?.intValue == 1)
        #expect(response.data?[1]?.intValue == 2)
        #expect(response.data?[2]?.intValue == 3)
    }

    @Test("Handles deeply nested payload")
    func handlesDeeplyNestedPayload() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let payload = AnyCodable([
            "level1": AnyCodable([
                "level2": AnyCodable([
                    "level3": AnyCodable([
                        "value": AnyCodable("deep"),
                    ]),
                ]),
            ]),
        ])

        let message = BridgeMessage(
            id: "nested-payload",
            module: "test",
            action: "echo",
            payload: payload
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["level1"]?["level2"]?["level3"]?["value"]?.stringValue == "deep")
    }

    @Test("Handles special characters in payload strings")
    func handlesSpecialCharactersInPayloadStrings() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "special-chars",
            "module": "test",
            "action": "echo",
            "payload": {"text": "Hello\\nWorld\\twith\\\"quotes\\\""}
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        #expect(jsonResponse.contains("\"success\":true"))
        #expect(jsonResponse.contains("Hello\\nWorld"))
    }

    @Test("Handles unicode in payload")
    func handlesUnicodeInPayload() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let payload = AnyCodable([
            "emoji": AnyCodable("Hello 👋 World 🌍"),
            "chinese": AnyCodable("你好世界"),
            "arabic": AnyCodable("مرحبا بالعالم"),
        ])

        let message = BridgeMessage(
            id: "unicode-payload",
            module: "test",
            action: "echo",
            payload: payload
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)
        #expect(response.data?["emoji"]?.stringValue == "Hello 👋 World 🌍")
        #expect(response.data?["chinese"]?.stringValue == "你好世界")
        #expect(response.data?["arabic"]?.stringValue == "مرحبا بالعالم")
    }

    // MARK: - Response ID Correlation Tests

    @Test("Response ID always matches request ID")
    func responseIDAlwaysMatchesRequestID() async {
        let dispatcher = BridgeDispatcher()
        await dispatcher.register(TestModule())
        let context = await ModuleContext()

        let testIDs = [
            "simple-id",
            "UUID-\(UUID().uuidString)",
            "with-special-chars_123",
            "very-long-id-that-might-cause-issues-if-not-handled-properly",
        ]

        for id in testIDs {
            let message = BridgeMessage(
                id: id,
                module: "test",
                action: "echo"
            )

            let response = await dispatcher.dispatch(message: message, context: context)
            #expect(response.id == id, "Response ID '\(response.id)' should match request ID '\(id)'")
        }
    }

    // MARK: - Module Registration Integration Tests

    @Test("ModuleRegistration registers default modules (PlatformModule and AppModule)")
    func moduleRegistrationRegistersDefaultModules() async {
        let dispatcher = BridgeDispatcher()
        let count = await ModuleRegistration.registerDefaultModules(in: dispatcher)

        #expect(count == 2)

        let moduleNames = await dispatcher.registeredModuleNames
        #expect(moduleNames.contains("platform"))
        #expect(moduleNames.contains("app"))
    }

    @Test("PlatformModule responds to bridge messages after registration")
    func platformModuleRespondsToBridgeMessagesAfterRegistration() async {
        let dispatcher = BridgeDispatcher()
        await ModuleRegistration.registerDefaultModules(in: dispatcher)
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "platform-getinfo-1",
            "module": "platform",
            "action": "getInfo"
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        guard let responseData = jsonResponse.data(using: .utf8),
              let response = try? JSONDecoder().decode(BridgeResponse.self, from: responseData) else
        {
            Issue.record("Failed to parse response JSON")
            return
        }

        #expect(response.id == "platform-getinfo-1")
        #expect(response.success == true)
        #expect(response.data?["isNative"]?.boolValue == true)
        #expect(response.data?["platform"]?.stringValue != nil)
        #expect(response.data?["version"]?.stringValue != nil)
    }

    @Test("PlatformModule returns complete platform info via bridge")
    func platformModuleReturnsCompletePlatformInfoViaBridge() async {
        let dispatcher = BridgeDispatcher()
        await ModuleRegistration.registerDefaultModules(in: dispatcher)
        let context = await ModuleContext()

        let message = BridgeMessage(
            id: "platform-complete",
            module: "platform",
            action: "getInfo"
        )

        let response = await dispatcher.dispatch(message: message, context: context)

        #expect(response.success == true)

        // Verify all expected fields are present
        let data = response.data
        #expect(data?["platform"]?.stringValue != nil)
        #expect(data?["version"]?.stringValue != nil)
        #expect(data?["isNative"]?.boolValue == true)
        #expect(data?["appVersion"]?.stringValue != nil)
        #expect(data?["appBuild"]?.stringValue != nil)
        #expect(data?["deviceModel"]?.stringValue != nil)
        #expect(data?["deviceName"]?.stringValue != nil)
    }

    @Test("ModuleRegistration with feature flags still registers PlatformModule")
    func moduleRegistrationWithFeatureFlagsStillRegistersPlatformModule() async {
        let dispatcher = BridgeDispatcher()

        // Even with all feature flags disabled, PlatformModule should be registered
        let features = FeaturesConfiguration(
            notifications: false,
            haptics: false,
            biometrics: false,
            secureStorage: false,
            healthkit: false,
            iap: false,
            share: false,
            print: false,
            clipboard: false
        )

        let count = await ModuleRegistration.registerDefaultModules(
            in: dispatcher,
            features: features
        )

        #expect(count >= 1)

        let moduleNames = await dispatcher.registeredModuleNames
        #expect(moduleNames.contains("platform"))
    }

    @Test("ModuleRegistration.defaultModuleNames includes platform")
    func moduleRegistrationDefaultModuleNamesIncludesPlatform() {
        let names = ModuleRegistration.defaultModuleNames
        #expect(names.contains("platform"))
    }

    @Test("ModuleRegistration.moduleNames(for:) includes platform regardless of features")
    func moduleRegistrationModuleNamesIncludesPlatformRegardlessOfFeatures() {
        let disabledFeatures = FeaturesConfiguration(
            notifications: false,
            haptics: false,
            biometrics: false,
            secureStorage: false,
            healthkit: false,
            iap: false,
            share: false,
            print: false,
            clipboard: false
        )

        let names = ModuleRegistration.moduleNames(for: disabledFeatures)
        #expect(names.contains("platform"))
    }

    @Test("HapticsModule responds to bridge messages after registration")
    func hapticsModuleRespondsToBridgeMessagesAfterRegistration() async {
        let dispatcher = BridgeDispatcher()
        let features = FeaturesConfiguration(haptics: true)
        await ModuleRegistration.registerDefaultModules(in: dispatcher, features: features)
        let context = await ModuleContext()

        let jsonMessage = """
        {
            "id": "haptics-impact-1",
            "module": "haptics",
            "action": "impact",
            "payload": { "style": "medium" }
        }
        """

        let jsonResponse = await dispatcher.dispatch(jsonString: jsonMessage, context: context)

        guard let responseData = jsonResponse.data(using: .utf8),
              let response = try? JSONDecoder().decode(BridgeResponse.self, from: responseData) else
        {
            Issue.record("Failed to parse response JSON")
            return
        }

        #expect(response.id == "haptics-impact-1")
        #expect(response.success == true)
        #expect(response.data?["triggered"]?.boolValue == true)
    }

    @Test("HapticsModule not registered when haptics feature disabled")
    func hapticsModuleNotRegisteredWhenHapticsFeatureDisabled() async {
        let dispatcher = BridgeDispatcher()
        let features = FeaturesConfiguration(haptics: false)
        await ModuleRegistration.registerDefaultModules(in: dispatcher, features: features)

        let moduleNames = await dispatcher.registeredModuleNames
        #expect(!moduleNames.contains("haptics"))
    }

    @Test("HapticsModule registered when haptics feature enabled")
    func hapticsModuleRegisteredWhenHapticsFeatureEnabled() async {
        let dispatcher = BridgeDispatcher()
        let features = FeaturesConfiguration(haptics: true)
        await ModuleRegistration.registerDefaultModules(in: dispatcher, features: features)

        let moduleNames = await dispatcher.registeredModuleNames
        #expect(moduleNames.contains("haptics"))
    }

    @Test("ModuleRegistration.moduleNames(for:) includes haptics when enabled")
    func moduleRegistrationModuleNamesIncludesHapticsWhenEnabled() {
        let enabledFeatures = FeaturesConfiguration(haptics: true)
        let names = ModuleRegistration.moduleNames(for: enabledFeatures)
        #expect(names.contains("haptics"))
    }

    @Test("ModuleRegistration.moduleNames(for:) excludes haptics when disabled")
    func moduleRegistrationModuleNamesExcludesHapticsWhenDisabled() {
        let disabledFeatures = FeaturesConfiguration(haptics: false)
        let names = ModuleRegistration.moduleNames(for: disabledFeatures)
        #expect(!names.contains("haptics"))
    }
}
