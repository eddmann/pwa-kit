import Foundation
@testable import PWAKitApp
import Testing

@Suite("HapticsModule Tests")
struct HapticsModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(HapticsModule.moduleName == "haptics")
    }

    @Test("Supports impact, notification, and selection actions")
    func supportsExpectedActions() {
        #expect(HapticsModule.supportedActions == ["impact", "notification", "selection"])
        #expect(HapticsModule.supports(action: "impact"))
        #expect(HapticsModule.supports(action: "notification"))
        #expect(HapticsModule.supports(action: "selection"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!HapticsModule.supports(action: "unknown"))
        #expect(!HapticsModule.supports(action: "vibrate"))
        #expect(!HapticsModule.supports(action: ""))
    }

    // MARK: - Impact Style Parsing

    @Test("Parses all valid impact styles")
    func parsesValidImpactStyles() {
        let validStyles = ["light", "medium", "heavy", "soft", "rigid"]
        for style in validStyles {
            let parsed = HapticsModule.ImpactStyle(rawValue: style)
            #expect(parsed != nil, "Expected '\(style)' to be a valid impact style")
        }
    }

    @Test("Rejects invalid impact styles")
    func rejectsInvalidImpactStyles() {
        let invalidStyles = ["LIGHT", "Medium", "extra", "super", "none", ""]
        for style in invalidStyles {
            let parsed = HapticsModule.ImpactStyle(rawValue: style)
            #expect(parsed == nil, "Expected '\(style)' to be an invalid impact style")
        }
    }

    @Test("ImpactStyle has all expected cases")
    func impactStyleHasAllCases() {
        let allCases = HapticsModule.ImpactStyle.allCases
        #expect(allCases.count == 5)
        #expect(allCases.map(\.rawValue).sorted() == ["heavy", "light", "medium", "rigid", "soft"])
    }

    // MARK: - Notification Type Parsing

    @Test("Parses all valid notification types")
    func parsesValidNotificationTypes() {
        let validTypes = ["success", "warning", "error"]
        for type in validTypes {
            let parsed = HapticsModule.NotificationType(rawValue: type)
            #expect(parsed != nil, "Expected '\(type)' to be a valid notification type")
        }
    }

    @Test("Rejects invalid notification types")
    func rejectsInvalidNotificationTypes() {
        let invalidTypes = ["SUCCESS", "Warning", "info", "failure", "none", ""]
        for type in invalidTypes {
            let parsed = HapticsModule.NotificationType(rawValue: type)
            #expect(parsed == nil, "Expected '\(type)' to be an invalid notification type")
        }
    }

    @Test("NotificationType has all expected cases")
    func notificationTypeHasAllCases() {
        let allCases = HapticsModule.NotificationType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.map(\.rawValue).sorted() == ["error", "success", "warning"])
    }

    // MARK: - Impact Action

    @Test("Impact action returns triggered response")
    @MainActor
    func impactReturnsTriggeredResponse() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "impact",
            payload: AnyCodable(["style": AnyCodable("medium")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["triggered"]?.boolValue == true)
    }

    @Test("Impact action uses default style when not specified")
    @MainActor
    func impactUsesDefaultStyle() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        // Should not throw, defaults to "medium"
        let result = try await module.handle(
            action: "impact",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict?["triggered"]?.boolValue == true)
    }

    @Test("Impact action accepts all valid styles")
    @MainActor
    func impactAcceptsAllStyles() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let styles = ["light", "medium", "heavy", "soft", "rigid"]
        for style in styles {
            let result = try await module.handle(
                action: "impact",
                payload: AnyCodable(["style": AnyCodable(style)]),
                context: context
            )

            let dict = result?.dictionaryValue
            #expect(dict?["triggered"]?.boolValue == true, "Impact with style '\(style)' should succeed")
        }
    }

    @Test("Impact action throws for invalid style")
    @MainActor
    func impactThrowsForInvalidStyle() async {
        let module = HapticsModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "impact",
                payload: AnyCodable(["style": AnyCodable("invalid")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("Invalid impact style"))
                #expect(reason.contains("invalid"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Notification Action

    @Test("Notification action returns triggered response")
    @MainActor
    func notificationReturnsTriggeredResponse() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "notification",
            payload: AnyCodable(["type": AnyCodable("success")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["triggered"]?.boolValue == true)
    }

    @Test("Notification action uses default type when not specified")
    @MainActor
    func notificationUsesDefaultType() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        // Should not throw, defaults to "success"
        let result = try await module.handle(
            action: "notification",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict?["triggered"]?.boolValue == true)
    }

    @Test("Notification action accepts all valid types")
    @MainActor
    func notificationAcceptsAllTypes() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let types = ["success", "warning", "error"]
        for type in types {
            let result = try await module.handle(
                action: "notification",
                payload: AnyCodable(["type": AnyCodable(type)]),
                context: context
            )

            let dict = result?.dictionaryValue
            #expect(dict?["triggered"]?.boolValue == true, "Notification with type '\(type)' should succeed")
        }
    }

    @Test("Notification action throws for invalid type")
    @MainActor
    func notificationThrowsForInvalidType() async {
        let module = HapticsModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "notification",
                payload: AnyCodable(["type": AnyCodable("badtype")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("Invalid notification type"))
                #expect(reason.contains("badtype"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Selection Action

    @Test("Selection action returns triggered response")
    @MainActor
    func selectionReturnsTriggeredResponse() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "selection",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["triggered"]?.boolValue == true)
    }

    @Test("Selection action ignores payload")
    @MainActor
    func selectionIgnoresPayload() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "selection",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "selection",
            payload: nil,
            context: context
        )

        // Both should return the same result
        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = HapticsModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "unknownAction",
                payload: nil,
                context: context
            )
        }
    }

    @Test("Throws specific error for unknown action")
    @MainActor
    func throwsSpecificErrorForUnknownAction() async {
        let module = HapticsModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "badAction",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            #expect(error == BridgeError.unknownAction("badAction"))
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = HapticsModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(HapticsModule.moduleName == "haptics")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = HapticsModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(HapticsModule.moduleName == "haptics")
        #expect(!HapticsModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = HapticsModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = HapticsModule()

        try module.validateAction("impact")
        try module.validateAction("notification")
        try module.validateAction("selection")
        // Should not throw
    }
}
