import Foundation
import Testing
import UIKit

@testable import PWAKitApp

// MARK: - PrintModuleTests

@Suite("PrintModule Tests")
struct PrintModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(PrintModule.moduleName == "print")
    }

    @Test("Supports print and canPrint actions")
    func supportsExpectedActions() {
        #expect(PrintModule.supportedActions == ["print", "canPrint"])
        #expect(PrintModule.supports(action: "print"))
        #expect(PrintModule.supports(action: "canPrint"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!PrintModule.supports(action: "unknown"))
        #expect(!PrintModule.supports(action: "printPage"))
        #expect(!PrintModule.supports(action: ""))
    }

    // MARK: - canPrint Action

    @Test("canPrint returns expected value based on platform")
    @MainActor
    func canPrintReturnsExpectedValue() async throws {
        let module = PrintModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "canPrint",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["canPrint"]?.boolValue != nil)

        // On UIKit platforms, canPrint depends on UIPrintInteractionController.isPrintingAvailable
        // In tests (simulator), this may or may not be available

        // Just verify we get a boolean response
        #expect(dict?["canPrint"]?.boolValue != nil)
    }

    // MARK: - print Action Validation

    @Test("print action handles missing webview")
    @MainActor
    func printHandlesMissingWebview() async throws {
        let module = PrintModule()
        let context = ModuleContext() // No webview
        // On UIKit platforms, should throw an error due to missing webview
        do {
            _ = try await module.handle(
                action: "print",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("webview"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("print action accepts jobName payload")
    @MainActor
    func printAcceptsJobNamePayload() async throws {
        let module = PrintModule()
        let context = ModuleContext()

        // Should fail due to missing webview, but should accept the payload format

        do {
            _ = try await module.handle(
                action: "print",
                payload: AnyCodable(["jobName": AnyCodable("My Document")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("webview"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("print action handles nil payload")
    @MainActor
    func printHandlesNilPayload() async throws {
        let module = PrintModule()
        let context = ModuleContext()

        // Should fail due to missing webview, not due to nil payload

        do {
            _ = try await module.handle(
                action: "print",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("webview"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = PrintModule()
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
        let module = PrintModule()
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
        let module = PrintModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(PrintModule.moduleName == "print")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = PrintModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(PrintModule.moduleName == "print")
        #expect(!PrintModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = PrintModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = PrintModule()

        try module.validateAction("print")
        try module.validateAction("canPrint")
        // Should not throw
    }
}
