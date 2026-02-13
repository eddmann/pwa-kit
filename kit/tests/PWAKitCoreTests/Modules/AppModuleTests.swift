import Foundation
@testable import PWAKitApp
import Testing
import UIKit

// MARK: - AppModuleTests

@Suite("AppModule Tests")
struct AppModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(AppModule.moduleName == "app")
    }

    @Test("Supports getVersion, requestReview, and openSettings actions")
    func supportsExpectedActions() {
        #expect(AppModule.supportedActions == ["getVersion", "requestReview", "openSettings"])
        #expect(AppModule.supports(action: "getVersion"))
        #expect(AppModule.supports(action: "requestReview"))
        #expect(AppModule.supports(action: "openSettings"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!AppModule.supports(action: "unknown"))
        #expect(!AppModule.supports(action: "getInfo"))
        #expect(!AppModule.supports(action: ""))
    }

    // MARK: - getVersion Action

    @Test("getVersion returns version and build")
    @MainActor
    func getVersionReturnsVersionAndBuild() async throws {
        let module = AppModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getVersion",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // Verify version field exists and is a string
        let version = dict?["version"]?.stringValue
        #expect(version != nil)
        #expect(try !(#require(version?.isEmpty)))

        // Verify build field exists and is a string
        let build = dict?["build"]?.stringValue
        #expect(build != nil)
        #expect(try !(#require(build?.isEmpty)))

        // Verify pwaKitVersion exists and matches framework version
        let pwaKitVersion = dict?["pwaKitVersion"]?.stringValue
        #expect(pwaKitVersion == PWAKitCore.version)
    }

    @Test("getVersion returns consistent values on multiple calls")
    @MainActor
    func getVersionReturnsConsistentValues() async throws {
        let module = AppModule()
        let context = ModuleContext()

        let result1 = try await module.handle(
            action: "getVersion",
            payload: nil,
            context: context
        )

        let result2 = try await module.handle(
            action: "getVersion",
            payload: nil,
            context: context
        )

        #expect(result1 == result2)
    }

    @Test("getVersion ignores payload")
    @MainActor
    func getVersionIgnoresPayload() async throws {
        let module = AppModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "getVersion",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "getVersion",
            payload: nil,
            context: context
        )

        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - requestReview Action

    @Test("requestReview returns expected response")
    @MainActor
    func requestReviewReturnsExpectedResponse() async throws {
        let module = AppModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "requestReview",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // The requested field should exist
        #expect(dict?["requested"]?.boolValue != nil)
        // On iOS, should indicate review was requested
        #expect(dict?["requested"]?.boolValue == true)
    }

    // MARK: - openSettings Action

    @Test("openSettings returns expected response structure")
    @MainActor
    func openSettingsReturnsExpectedResponse() async throws {
        let module = AppModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "openSettings",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // The opened field should exist
        #expect(dict?["opened"]?.boolValue != nil)
        // On iOS, the settings URL is always valid
        // In tests, canOpenURL may return true
        let opened = dict?["opened"]?.boolValue
        #expect(opened != nil)
    }

    @Test("Settings URL string is valid")
    func settingsURLStringIsValid() {
        let settingsURL = URL(string: UIApplication.openSettingsURLString)
        #expect(settingsURL != nil)
        #expect(settingsURL?.scheme == "app-settings")
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = AppModule()
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
        let module = AppModule()
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
        let module = AppModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(AppModule.moduleName == "app")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = AppModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(AppModule.moduleName == "app")
        #expect(!AppModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = AppModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = AppModule()

        try module.validateAction("getVersion")
        try module.validateAction("requestReview")
        try module.validateAction("openSettings")
        // Should not throw
    }
}
