import Foundation
import Testing

@testable import PWAKitApp

@Suite("PlatformModule Tests")
struct PlatformModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(PlatformModule.moduleName == "platform")
    }

    @Test("Supports getInfo action")
    func supportsGetInfoAction() {
        #expect(PlatformModule.supportedActions == ["getInfo"])
        #expect(PlatformModule.supports(action: "getInfo"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!PlatformModule.supports(action: "unknown"))
        #expect(!PlatformModule.supports(action: "setInfo"))
        #expect(!PlatformModule.supports(action: ""))
    }

    // MARK: - getInfo Action

    @Test("Returns platform info with getInfo action")
    @MainActor
    func returnsInfoWithGetInfoAction() async throws {
        let module = PlatformModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getInfo",
            payload: nil,
            context: context
        )

        // Verify the result is a dictionary
        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // Verify platform field exists and is a string
        let platform = dict?["platform"]?.stringValue
        #expect(platform != nil)
        #expect(!platform!.isEmpty)

        // Verify version field exists and is a string
        let version = dict?["version"]?.stringValue
        #expect(version != nil)
        #expect(!version!.isEmpty)

        // Verify isNative is true
        let isNative = dict?["isNative"]?.boolValue
        #expect(isNative == true)

        // Verify appVersion exists
        let appVersion = dict?["appVersion"]?.stringValue
        #expect(appVersion != nil)

        // Verify appBuild exists
        let appBuild = dict?["appBuild"]?.stringValue
        #expect(appBuild != nil)

        // Verify deviceModel exists
        let deviceModel = dict?["deviceModel"]?.stringValue
        #expect(deviceModel != nil)
        #expect(!deviceModel!.isEmpty)

        // Verify deviceName exists
        let deviceName = dict?["deviceName"]?.stringValue
        #expect(deviceName != nil)
    }

    @Test("Returns consistent structure on multiple calls")
    @MainActor
    func returnsConsistentStructure() async throws {
        let module = PlatformModule()
        let context = ModuleContext()

        let result1 = try await module.handle(
            action: "getInfo",
            payload: nil,
            context: context
        )

        let result2 = try await module.handle(
            action: "getInfo",
            payload: nil,
            context: context
        )

        // Results should be equal (same device info)
        #expect(result1 == result2)
    }

    @Test("Ignores payload for getInfo action")
    @MainActor
    func ignoresPayload() async throws {
        let module = PlatformModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "getInfo",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "getInfo",
            payload: nil,
            context: context
        )

        // Results should be the same regardless of payload
        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = PlatformModule()
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
        let module = PlatformModule()
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
        let module = PlatformModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(PlatformModule.moduleName == "platform")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = PlatformModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(PlatformModule.moduleName == "platform")
        #expect(!PlatformModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = PlatformModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported action")
    func validateActionSucceeds() throws {
        let module = PlatformModule()

        try module.validateAction("getInfo")
        // Should not throw
    }
}
